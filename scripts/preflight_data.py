#!/usr/bin/env python3
"""Inspect downloaded sources without reporting an experiment as completed."""
import argparse
import hashlib
import json
from pathlib import Path
from scipy.io import whosmat, loadmat

parser = argparse.ArgumentParser()
parser.add_argument('dataset', choices=['cwru', 'paderborn', 'ottawa'])
args = parser.parse_args()
root = Path('input') / args.dataset
out = Path('results/preflight') / args.dataset
out.mkdir(parents=True, exist_ok=True)
records = []
for path in sorted(root.rglob('*.mat')):
    variables = whosmat(path)
    info = {'file': str(path), 'bytes': path.stat().st_size,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'variables': [{'name': name, 'shape': shape, 'class': typ}
                          for name, shape, typ in variables]}
    if args.dataset == 'cwru':
        mat = loadmat(path)
        names = [v['name'] for v in info['variables']]
        assert len([n for n in names if n.endswith('_DE_time')]) == 1
        assert len([n for n in names if n.endswith('_RPM')]) == 1
        de = next(n for n in names if n.endswith('_DE_time'))
        rpm = next(n for n in names if n.endswith('_RPM'))
        info['samples'] = mat[de].size
        info['rpm'] = float(mat[rpm].ravel()[0])
        assert info['samples'] >= 10240
    if args.dataset == 'ottawa':
        mat = loadmat(path)
        assert 'Channel_1' in mat and 'Channel_2' in mat
        vib = mat['Channel_1'].ravel(); enc = mat['Channel_2'].ravel()
        assert len(vib) == len(enc) and len(vib) >= 1900000
        info.update(samples=len(vib), sampling_hz=200000,
                    encoder_min=float(enc.min()), encoder_max=float(enc.max()),
                    encoder_median=float(__import__('numpy').median(enc)))
    records.append(info)
report = {'dataset': args.dataset, 'count': len(records), 'records': records}
with (out / 'data_manifest.json').open('w') as f:
    json.dump(report, f, indent=2)
print(json.dumps({'dataset': args.dataset, 'count': len(records),
                  'files': [r['file'] for r in records]}, indent=2))
