#!/usr/bin/env python3
"""Aggregate actual adaptive MATLAB JSON files; preserve failures and candidates."""
import argparse
import csv
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('root', type=Path, nargs='?', default=Path('results'))
parser.add_argument('--out', type=Path, default=Path('results/summary'))
args = parser.parse_args()
args.out.mkdir(parents=True, exist_ok=True)


def write(name, rows, fields):
    with (args.out / name).open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, extrasaction='ignore')
        writer.writeheader(); writer.writerows(rows)


def label(dataset, file):
    stem = Path(file).stem
    if dataset == 'cwru':
        ident = int(stem)
        return 'BPFI' if ident in {105, 106, 107} else 'BPFO'
    if dataset == 'paderborn':
        bearing = Path(file).parent.name
        return 'BPFO+BPFI' if bearing == 'KB24' else ('BPFI' if bearing.startswith('KI') else 'BPFO')
    if dataset == 'xjtu':
        return {'Bearing1_2':'BPFO','Bearing1_3':'BPFO',
                'Bearing2_1':'BPFI','Bearing2_2':'BPFO',
                'Bearing3_1':'BPFO','Bearing3_4':'BPFI'}.get(Path(file).parent.name,'UNKNOWN')
    return 'BPFI' if stem.startswith('I-') else 'BPFO'

rows=[]; selected=[]; keys=set()
for path in sorted(args.root.rglob('result.json')):
    if 'adaptive-band-selection' not in path.parts:
        continue
    result=json.loads(path.read_text())
    key=(result.get('mode'),result.get('file'),result.get('start_sample'))
    if key in keys:
        raise SystemExit(f'Duplicate result {key}')
    keys.add(key)
    candidates=result.get('candidates',[])
    assert {2,3,4} == {int(c['R']) for c in candidates}, path
    assert len(candidates)==9, path
    chosen=(candidates[result['selected_candidate_index']-1]
            if result['status']=='SELECTED' else {})
    row=dict(dataset=result['mode'],file=result['file'],
             bearing=Path(result['file']).parent.name,
             start_sample=result['start_sample'],end_sample=result['end_sample'],
             fs_hz=result['fs_hz'],observation_s=result['observation_s'],
             physical_resolution_hz=result['physical_resolution_hz'],
             status=result['status'],selected_R=result.get('selected_R'),
             selected_hypothesis=result.get('selected_hypothesis'),
             true_label_for_posthoc=label(result['mode'],result['file']),
             J=chosen.get('J'),error_hz=chosen.get('error_hz'),
             contrast_linear=chosen.get('contrast_linear'),
             location_confidence=chosen.get('location_confidence'),
             contrast_utility=chosen.get('contrast_utility'),
             unlabelled_peak_hz=chosen.get('unlabelled_fused_peak_hz'),
             candidates_json=json.dumps(candidates,separators=(',',':')),
             result_path=str(path))
    rows.append(row)
    if result['status']=='SELECTED':selected.append(row)
fields=list(rows[0]) if rows else ['dataset','file','start_sample','status']
write('REAL_DATA_FULL_RESULTS.csv',rows,fields)
write('SELECTED_SEGMENT_RESULTS.csv',selected,fields)
segments=[]
for path in sorted((args.root/'input_segments').rglob('metadata.json')):
    meta=json.loads(path.read_text())
    segments.append(dict(meta,metadata_path=str(path)))
seg_fields=list(segments[0]) if segments else ['dataset','source_file','start_sample','sha256']
write('SEGMENT_MANIFEST.csv',segments,seg_fields)
print(json.dumps({'result_windows':len(rows),'selected':len(selected),
                  'no_valid':sum(r['status']=='NO_VALID_R' for r in rows),
                  'input_segments':len(segments)}))
