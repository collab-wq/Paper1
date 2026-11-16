#!/usr/bin/env python3
"""Audit fresh target-informed MATLAB artifacts; never fill missing windows."""
import argparse
import csv
import json
from collections import Counter
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('root',type=Path)
parser.add_argument('--out',type=Path,default=Path('results/summary'))
args=parser.parse_args()
args.out.mkdir(parents=True,exist_ok=True)

def key(dataset,file,start):
    p=Path(file)
    name=p.name if dataset!='xjtu' else f'{p.parent.name}/{p.name}'
    return dataset,name,int(start)

expected=set()
for number in (105,106,107,130,131,132,144,145,146,156,158,159):
    for first in (1,4097,8193): expected.add(('cwru',f'{number}.mat',first))
for bearing in ('KA04','KA16','KB24','KI21','KI17','KI04'):
    for rec in (1,2,3):
        for first in (64001,128001):
            expected.add(('paderborn',f'N15_M07_F10_{bearing}_{rec}.mat',first))
for name in ('I-A-2','I-B-2','I-C-2','O-A-2','O-B-2','O-C-2'):
    starts=set(range(1,2_000_000-65_536+2,32768))
    starts.add(2_000_000-65_536+1)
    for first in starts: expected.add(('ottawa',name+'.mat',first))
for bearing,count in {'Bearing1_2':161,'Bearing1_3':158,'Bearing2_1':491,
                      'Bearing2_2':161,'Bearing3_1':2538,'Bearing3_4':1515}.items():
    for snap in range(1,count+1):
        for first in (4097,16385): expected.add(('xjtu',f'{bearing}/{snap}.csv',first))
assert len(expected)==10486

rows=[]; seen=set()
for path in sorted(args.root.rglob('result.json')):
    if 'adaptive-band-selection' not in path.parts: continue
    obj=json.loads(path.read_text()); dataset=obj['mode']
    window=key(dataset,obj['file'],obj['start_sample'])
    assert window in expected,(path,window)
    target=obj['target_hypothesis']
    assert target in ('BPFO','BPFI')
    ident=window+(target,)
    assert ident not in seen,('duplicate evaluation',ident)
    seen.add(ident)
    candidates=obj['candidates']
    assert [(int(c['R']),c['hypothesis']) for c in candidates]==[
        (2,target),(3,target),(4,target)],path
    assert not any('BSF' in json.dumps(c) for c in candidates),path
    valid=[c for c in candidates if c['valid']]
    if obj['status']=='SELECTED':
        assert valid and obj['selected_R'] in (2,3,4)
        chosen=candidates[obj['selected_candidate_index']-1]
        assert chosen['valid'] and chosen['R']==obj['selected_R']
        assert chosen==min(valid,key=lambda c:(-c['J'],c['R']))
    else:
        assert obj['status']=='NO_VALID_R' and not valid
        chosen={}
    rows.append(dict(dataset=dataset,file=obj['file'],start_sample=obj['start_sample'],
        end_sample=obj['end_sample'],target=target,status=obj['status'],
        selected_R=obj.get('selected_R'),J=chosen.get('J'),
        contrast_linear=chosen.get('contrast_linear'),
        error=chosen.get('error_order',chosen.get('error_hz')),
        candidates_json=json.dumps(candidates,separators=(',',':')),
        result_path=str(path)))

observed={x[:3] for x in seen}
missing=expected-observed
extra=observed-expected
assert not extra
targets_by_window={}
for item in seen:
    targets_by_window.setdefault(item[:3],set()).add(item[3])
for window in expected:
    found=targets_by_window.get(window,set())
    want={'BPFO','BPFI'} if window[0]=='paderborn' and 'KB24' in window[1] else {
        'BPFI' if (window[0]=='cwru' and int(window[1][:-4]) in (105,106,107)) or
                  (window[0]=='paderborn' and '_KI' in window[1]) or
                  (window[0]=='ottawa' and window[1].startswith('I-')) or
                  (window[0]=='xjtu' and window[1].split('/')[0] in ('Bearing2_1','Bearing3_4'))
        else 'BPFO'}
    if found and found!=want: raise AssertionError(('target mismatch',window,found,want))

with (args.out/'REAL_DATA_FULL_RESULTS.csv').open('w',newline='') as fp:
    writer=csv.DictWriter(fp,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
coverage=[]
for dataset in ('cwru','paderborn','ottawa','xjtu'):
    plan=sum(x[0]==dataset for x in expected)
    actual=sum(x[0]==dataset for x in observed)
    coverage.append(dict(dataset=dataset,planned_windows=plan,observed_windows=actual,
                         target_evaluations=sum(r['dataset']==dataset for r in rows),
                         missing_windows=plan-actual))
with (args.out/'COVERAGE.csv').open('w',newline='') as fp:
    writer=csv.DictWriter(fp,fieldnames=list(coverage[0]));writer.writeheader();writer.writerows(coverage)
summary=dict(planned_windows=len(expected),observed_windows=len(observed),
             target_evaluations=len(rows),missing_windows=len(missing),
             selected=sum(r['status']=='SELECTED' for r in rows),
             no_valid=sum(r['status']=='NO_VALID_R' for r in rows),
             coverage=coverage)
(args.out/'AUDIT_STATUS.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary))
assert not missing and len(rows)==10492,('incomplete',summary)
