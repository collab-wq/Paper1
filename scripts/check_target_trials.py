#!/usr/bin/env python3
"""Check the small real-data trial; never infer target from a filename."""
import csv
import json
import sys
from pathlib import Path

dataset = sys.argv[1]
root = Path('results/adaptive-band-selection') / dataset
files = sorted(root.rglob('result.json'))
expected = 3 if dataset == 'paderborn' else 1
assert len(files) == expected, (dataset, files)
for path in files:
    data = json.loads(path.read_text())
    target = data['target_hypothesis']
    rows = data['candidates']
    assert target in {'BPFO', 'BPFI'}
    assert [row['R'] for row in rows] == [2, 3, 4]
    assert all(row['hypothesis'] == target for row in rows)
    with (path.parent / 'candidates.csv').open(newline='') as stream:
        saved = list(csv.DictReader(stream))
    assert len(saved) == 3
    assert all(row['target_hypothesis'] == target for row in saved)
    assert all(row['target_fault_type'] == target for row in saved)
    selected = [row for row in saved if row['selected'] == '1']
    assert len(selected) == (data['status'] == 'SELECTED')
    if selected:
        assert int(selected[0]['R']) == data['selected_R']
        assert (path.parent / 'paper_figure.png').is_file()
        assert (path.parent / 'paper_figure.pdf').is_file()
    print(path, data['status'], target, data['selected_R'])
if dataset == 'paderborn':
    kb = [p for p in files if 'KB24' in str(p)]
    assert len(kb) == 2 and kb[0].parent != kb[1].parent
    assert {json.loads(p.read_text())['target_hypothesis'] for p in kb} == {'BPFO', 'BPFI'}
print('TARGET_TRIAL_CHECK_PASS', dataset, len(files))
