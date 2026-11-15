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
             rpm=result.get('rpm',result.get('rpm_median')),
             physical_resolution_hz=result.get('physical_resolution_hz'),
             physical_resolution_order=result.get('physical_resolution_order'),
             status=result['status'],selected_R=result.get('selected_R'),
             selected_hypothesis=result.get('selected_hypothesis'),
             true_label_for_posthoc=label(result['mode'],result['file']),
             J=chosen.get('J'),error_hz=chosen.get('error_hz'),
             error_order=chosen.get('error_order'),
             contrast_linear=chosen.get('contrast_linear'),
             location_confidence=chosen.get('location_confidence'),
             contrast_utility=chosen.get('contrast_utility'),
             unlabelled_peak_hz=chosen.get('unlabelled_fused_peak_hz'),
             target_peak_order=chosen.get('target_peak_order'),
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
failures=[]
for path in sorted((args.root/'failures').glob('*.json')):
    failures.append(json.loads(path.read_text()))
write('FAILED_SEGMENTS.csv',failures, ...
      ['dataset','file','start_sample','status','reason','identifier'])
expected={'cwru':36,'paderborn':36,'ottawa':366,'xjtu':10048}
coverage=[]
for dataset,planned in expected.items():
    actual=sum(r['dataset']==dataset for r in rows)
    failed=sum(r['dataset']==dataset for r in failures)
    coverage.append(dict(dataset=dataset,planned=planned,result_rows=actual,
                         failed_rows=failed,unaccounted=planned-actual-failed))
write('COVERAGE.csv',coverage, ...
      ['dataset','planned','result_rows','failed_rows','unaccounted'])
sourceRows=[]
for path in sorted((args.root/'source').glob('*.csv')):
    dataset=path.name.split('-')[0]
    with path.open() as stream:
        for row in csv.DictReader(stream):
            sourceRows.append(dict(dataset=dataset,record=row.get('record') or row.get('bearing'),
                source_url=row.get('source_url'),sha256=row.get('sha256') or row.get('archive_sha256'),
                bytes=row.get('bytes') or row.get('archive_bytes')))
for path in sorted((args.root/'source').glob('xjtu-*.json')):
    obj=json.loads(path.read_text())
    for number,snap in obj['snapshots'].items():
        sourceRows.append(dict(dataset='xjtu',record=obj['bearing']+'/'+number,
            source_url=obj['mirror']+'#'+snap['zip_member'],
            sha256=snap['sha256'],bytes=snap['bytes']))
write('DATASET_MANIFEST.csv',sourceRows, ...
      ['dataset','record','source_url','sha256','bytes'])
snapshotRows=[]
groups={}
for row in rows:
    if row['dataset']=='xjtu':
        groups.setdefault((row['bearing'],Path(row['file']).stem),[]).append(row)
for (bearing,snapshot),group in sorted(groups.items(),key=lambda x:(x[0][0],int(x[0][1]))):
    snapshotRows.append(dict(bearing=bearing,snapshot=int(snapshot),
        windows=len(group),valid_windows=sum(r['status']=='SELECTED' for r in group),
        no_valid_windows=sum(r['status']=='NO_VALID_R' for r in group),
        selected_R=';'.join(str(r['selected_R']) for r in group),
        selected_hypothesis=';'.join(str(r['selected_hypothesis']) for r in group),
        J=';'.join(str(r['J']) for r in group),
        error_hz=';'.join(str(r['error_hz']) for r in group),
        contrast_linear=';'.join(str(r['contrast_linear']) for r in group)))
write('XJTU_LIFETIME_SUMMARY.csv',snapshotRows,
      ['bearing','snapshot','windows','valid_windows','no_valid_windows',
       'selected_R','selected_hypothesis','J','error_hz','contrast_linear'])
ottawaRows=[]
for row in rows:
    if row['dataset']=='ottawa':
        ottawaRows.append({k:row.get(k) for k in ['file','start_sample','end_sample',
            'rpm','status','selected_R','selected_hypothesis','target_peak_order',
            'error_order','contrast_linear','location_confidence',
            'contrast_utility','J']})
write('OTTAWA_ORDER_TRACKING.csv',ottawaRows,
      ['file','start_sample','end_sample','rpm','status','selected_R',
       'selected_hypothesis','target_peak_order','error_order',
       'contrast_linear','location_confidence','contrast_utility','J'])
print(json.dumps({'result_windows':len(rows),'selected':len(selected),
                  'no_valid':sum(r['status']=='NO_VALID_R' for r in rows),
                  'input_segments':len(segments),'coverage':coverage}))
