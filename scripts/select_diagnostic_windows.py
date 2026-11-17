#!/usr/bin/env python3
"""Select reproducible NO_VALID_R windows from the completed full run."""
import csv
import json
from collections import defaultdict
from pathlib import Path

root = Path(__file__).resolve().parents[1]
with (root/'REAL_DATA_FULL_RESULTS.csv').open(newline='') as f:
    results = list(csv.DictReader(f))
with (root/'SEGMENT_MANIFEST.csv').open(newline='') as f:
    segments = {(r['dataset'], r['source_file'], r['start_sample']): r for r in csv.DictReader(f)}
with (root/'DATASET_MANIFEST.csv').open(newline='') as f:
    sources = {(r['dataset'], r['record']): r for r in csv.DictReader(f)}
groups = defaultdict(list)
for row in results:
    if row['status'] != 'NO_VALID_R':
        continue
    file = Path(row['file'])
    if row['dataset'] == 'ottawa' and file.stem in ('O-A-2', 'O-B-2', 'O-C-2'):
        groups[file.stem].append(row)
    elif row['dataset'] == 'xjtu' and file.parent.name in (
            'Bearing2_1','Bearing3_4','Bearing3_1','Bearing1_2','Bearing1_3','Bearing2_2'):
        groups[file.parent.name].append(row)

def pick(rows, count, early=False):
    rows.sort(key=lambda r: (int(Path(r['file']).stem) if r['dataset']=='xjtu' else int(float(r['start_sample'])), int(float(r['start_sample']))))
    if early:
        maxsnap={'Bearing1_2':161,'Bearing1_3':158,'Bearing2_2':161}[Path(rows[0]['file']).parent.name]
        rows=[r for r in rows if (int(Path(r['file']).stem)-1)/(maxsnap-1)<=1/3]
    assert len(rows)>=count
    if count == 1: return [rows[len(rows)//2]]
    return [rows[round(i*(len(rows)-1)/(count-1))] for i in range(count)]

chosen=[]
for name in ('O-A-2','O-B-2','O-C-2','Bearing2_1','Bearing3_4','Bearing3_1',
             'Bearing1_2','Bearing1_3','Bearing2_2'):
    chosen += pick(groups[name], 1 if name in ('Bearing1_2','Bearing1_3','Bearing2_2') else 2,
                   name in ('Bearing1_2','Bearing1_3','Bearing2_2'))
assert len(chosen)==15 and len({(r['dataset'],r['file'],r['start_sample']) for r in chosen})==15
out=[]
for i,r in enumerate(chosen,1):
    key=(r['dataset'],r['file'],r['start_sample']); m=segments[key]
    source_key=Path(r['file']).stem if r['dataset']=='ottawa' else f'{Path(r["file"]).parent.name}/{Path(r["file"]).stem}'
    s=sources[(r['dataset'],source_key)]
    candidates=json.loads(r['candidates_json'])
    assert len(candidates)==3 and {c['hypothesis'] for c in candidates}=={r['target']}
    theory=candidates[0].get('theoretical_order',candidates[0].get('theoretical_hz'))
    out.append(dict(window_id=f'D{i:02d}',dataset=r['dataset'],bearing_or_condition=Path(r['file']).stem if r['dataset']=='ottawa' else Path(r['file']).parent.name,
                    source_file=r['file'],start_sample=r['start_sample'],end_sample=r['end_sample'],
                    target=r['target'],theoretical_target=theory,target_unit='order' if r['dataset']=='ottawa' else 'Hz',
                    old_status=r['status'],segment_sha256=m['sha256'],source_sha256=s['sha256'],
                    source_url=s['source_url'],result_path=r['result_path']))
with (root/'DIAGNOSTIC_WINDOWS.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(out[0]));w.writeheader();w.writerows(out)
print('SELECTED',len(out),[(r['window_id'],r['bearing_or_condition'],r['source_file'],r['start_sample']) for r in out])
