#!/usr/bin/env python3
"""Rebuild input/source SHA manifests from the current full-run Artifacts."""
import csv
import json
from pathlib import Path

root=Path('collected'); out=Path('results/summary');out.mkdir(parents=True,exist_ok=True)
def write(name,rows,fields):
    with (out/name).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields,extrasaction='ignore');w.writeheader();w.writerows(rows)

segments={}
for path in sorted((root/'input_segments').rglob('metadata.json')):
    m=json.loads(path.read_text())
    key=(m['dataset'],m['source_file'],int(m['start_sample']))
    if key in segments:
        assert segments[key]['sha256']==m['sha256'],('same window, different input',key)
    else:
        segments[key]=dict(m,metadata_path=str(path))
assert len(segments)==10486,len(segments)
segment_rows=list(segments.values())
fields=list(dict.fromkeys(k for row in segment_rows for k in row))
write('SEGMENT_MANIFEST.csv',segment_rows,fields)

sources=[]
for path in sorted((root/'source').glob('*.csv')):
    dataset=path.name.split('-')[0]
    with path.open(newline='') as f:
        for r in csv.DictReader(f):
            sources.append(dict(dataset=dataset,record=r.get('record') or r.get('bearing'),
                source_url=r.get('source_url'),sha256=r.get('sha256') or r.get('archive_sha256'),
                bytes=r.get('bytes') or r.get('archive_bytes')))
for path in sorted((root/'source').glob('xjtu-*.json')):
    obj=json.loads(path.read_text())
    for number,snap in obj['snapshots'].items():
        sources.append(dict(dataset='xjtu',record=obj['bearing']+'/'+number,
            source_url=obj['mirror']+'#'+snap['zip_member'],
            sha256=snap['sha256'],bytes=snap['bytes']))
sources=list({(r['dataset'],r['record'],r['sha256']):r for r in sources}.values())
assert len(sources)==5060,len(sources)
assert all(len(r['sha256'])==64 for r in sources)
write('DATASET_MANIFEST.csv',sources,['dataset','record','source_url','sha256','bytes'])
print(json.dumps({'input_segments':len(segments),'source_records':len(sources)}))
