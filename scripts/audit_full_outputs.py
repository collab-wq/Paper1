#!/usr/bin/env python3
"""Independently check full-run coverage, candidate validity, and input traceability."""
import csv
import json
import argparse
from collections import Counter
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--root', type=Path, default=Path('.'))
args = parser.parse_args()
root = args.root

def read(name):
    with (root / name).open(newline='') as stream:
        return list(csv.DictReader(stream))

rows = read('REAL_DATA_FULL_RESULTS.csv')
segments = read('SEGMENT_MANIFEST.csv')
sources = read('DATASET_MANIFEST.csv')
failures = read('FAILED_SEGMENTS.csv')

cwru_ids = (105, 106, 107, 130, 131, 132, 144, 145, 146, 156, 158, 159)
paderborn_ids = ('KA04', 'KA16', 'KB24', 'KI21', 'KI17', 'KI04')
ottawa_ids = ('I-A-2', 'I-B-2', 'I-C-2', 'O-A-2', 'O-B-2', 'O-C-2')
xjtu_counts = {'Bearing1_2': 161, 'Bearing1_3': 158,
               'Bearing2_1': 491, 'Bearing2_2': 161,
               'Bearing3_1': 2538, 'Bearing3_4': 1515}

expected = set()
for ident in cwru_ids:
    expected.update(('cwru', f'{ident}.mat', start) for start in (1, 4097, 8193))
for bearing in paderborn_ids:
    for measure in (1, 2, 3):
        name = f'N15_M07_F10_{bearing}_{measure}.mat'
        expected.update(('paderborn', name, start) for start in (64001, 128001))
ottawa_starts = list(range(1, 2_000_000 - 65_536 + 2, 32_768))
ottawa_starts.append(2_000_000 - 65_536 + 1)
for name in ottawa_ids:
    expected.update(('ottawa', f'{name}.mat', start) for start in ottawa_starts)
for bearing, count in xjtu_counts.items():
    for number in range(1, count + 1):
        expected.update(('xjtu', f'{bearing}/{number}.csv', start)
                        for start in (4097, 16385))

def key(row):
    path = Path(row.get('file') or row.get('source_file'))
    name = path.name if row['dataset'] != 'xjtu' else f'{path.parent.name}/{path.name}'
    start = float(row['start_sample'])
    assert start.is_integer(), row
    return row['dataset'], name, int(start)

keys = [key(row) for row in rows]
observed = set(keys)
failure_keys = [key(row) for row in failures]
assert len(expected) == 10_486, len(expected)
assert len(keys) == len(observed), 'Duplicate result rows'
assert len(failure_keys) == len(set(failure_keys)), 'Duplicate failure rows'
assert not observed.intersection(failure_keys), 'Result and failure overlap'
assert observed.union(failure_keys) == expected, (len(expected - observed - set(failure_keys)),
                                                len(observed.union(failure_keys) - expected))
segment_keys = [key(row) for row in segments]
assert len(segment_keys) == len(set(segment_keys)), 'Duplicate saved input segments'
assert observed.issubset(set(segment_keys)), 'Every result must have one saved WVD input'
assert set(segment_keys).issubset(observed.union(failure_keys)), \
    'Saved inputs must belong to a result or recorded failure'

for row in rows:
    candidates = json.loads(row['candidates_json'])
    assert len(candidates) == 9
    assert Counter(int(c['R']) for c in candidates) == {2: 3, 3: 3, 4: 3}
    assert all(c['hypothesis'] in ('BPFO', 'BPFI', 'BSF') for c in candidates)
    valid = [c for c in candidates if c['valid']]
    if row['status'] == 'NO_VALID_R':
        assert not valid
        assert row['selected_R'] in ('', '[]', 'None')
    else:
        assert row['status'] == 'SELECTED' and valid
        winner = [c for c in valid if str(c['R']) == row['selected_R']
                  and c['hypothesis'] == row['selected_hypothesis']]
        assert len(winner) == 1
        assert abs(float(winner[0]['J']) - float(row['J'])) < 1e-10
        ranked = sorted(valid, key=lambda c: (-float(c['J']), int(c['R']),
                                              c['hypothesis']))
        assert winner[0] == ranked[0], 'Adaptive winner or tie rule differs'
        assert float(row['contrast_linear']) > 1
        if row['dataset'] == 'ottawa':
            assert float(row['error_order']) <= float(row['physical_resolution_order']) + 1e-10
        else:
            assert float(row['error_hz']) <= float(row['physical_resolution_hz']) + 1e-10

source_count = Counter(row['dataset'] for row in sources)
assert source_count == {'cwru': 12, 'paderborn': 18, 'ottawa': 6, 'xjtu': 5024}, source_count
for row in sources:
    assert len(row['sha256']) == 64
for row in segments:
    assert len(row['sha256']) == 64
    if row['dataset'] == 'ottawa':
        assert len(row['original_sha256']) == 64
        assert int(row['original_samples']) == 65_536
        assert int(row['original_sampling_hz']) == 200_000
        assert int(row['sampling_hz']) == 16_000

print(json.dumps({'planned_windows': len(expected), 'result_windows': len(rows),
                  'failed_windows': len(failures), 'saved_inputs': len(segments),
                  'source_records': source_count}, default=dict))
