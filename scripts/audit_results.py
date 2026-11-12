#!/usr/bin/env python3
"""Compare rerun JSON with the fixed 01ace75 Actions artifacts."""
import csv
import json
from pathlib import Path


def records(root):
    found = {}
    for path in Path(root).rglob('result.json'):
        item = json.loads(path.read_text())
        # The MATLAB setup artifact is an environment smoke test, not an experiment.
        if 'mode' not in item:
            if path.parent.name == 'matlab-verification':
                continue
            raise RuntimeError(f'Missing experiment mode in {path}')
        mode = item['mode']
        key = (mode, Path(item.get('file', '')).name, item.get('start_sample', 0))
        if key in found:
            raise RuntimeError(f'Duplicate {key} under {root}')
        found[key] = item
    return found


def compare(old, new, prefix=''):
    errors = []
    for key, value in old.items():
        if key not in new:
            errors.append(f'{prefix}{key}: missing')
            continue
        current = new[key]
        if isinstance(value, dict) and isinstance(current, dict):
            errors += compare(value, current, prefix + key + '.')
        elif isinstance(value, list) and isinstance(current, list):
            if len(value) != len(current):
                errors.append(f'{prefix}{key}: length {len(value)} != {len(current)}')
            else:
                for i, (a, b) in enumerate(zip(value, current)):
                    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
                        if abs(a-b) > 1e-8*max(1, abs(a), abs(b)):
                            errors.append(f'{prefix}{key}[{i}]: {a} != {b}')
                    elif a != b:
                        errors.append(f'{prefix}{key}[{i}]: {a} != {b}')
        elif isinstance(value, (int, float)) and isinstance(current, (int, float)):
            if abs(value-current) > 1e-8*max(1, abs(value), abs(current)):
                errors.append(f'{prefix}{key}: {value} != {current}')
        elif value != current:
            errors.append(f'{prefix}{key}: {value} != {current}')
    return errors


def main():
    old = records('reference')
    new = records('results')
    assert set(old) == set(new), f'Experiment sets differ: old={len(old)}, new={len(new)}'
    summary = {'baseline_commit': '01ace753f92b4b1b77eb00b310f5e692f63a3637',
               'rerun_count': len(new), 'mismatches': {}, 'synthetic_metrics': {}}
    fields = ['dataset', 'file', 'start_sample', 'samples', 'fs_hz', 'expected_hz',
              'raw_target_peak_hz', 'fused_target_peak_hz', 'target_error_hz',
              'raw_target_contrast', 'fused_target_contrast',
              'unlabelled_raw_peak_hz', 'unlabelled_fused_peak_hz',
              'unlabelled_raw_contrast', 'unlabelled_fused_contrast',
              'retained_pixel_fraction', 'eligible_time_pairs',
              'raster_global_fs_hz', 'raster_segment_fs_hz', 'reference_status']
    with open('AUDIT_RESULTS.csv', 'w', newline='') as out:
        writer = csv.DictWriter(out, fieldnames=fields)
        writer.writeheader()
        for key in sorted(new):
            item = new[key]
            errors = compare(old[key], item)
            if errors:
                summary['mismatches'][str(key)] = errors
            if key[0] == 'synthetic':
                summary['synthetic_metrics'] = item['fusion_metrics']
                continue
            mode, file, start = key
            expected = item.get('expected_fault_hz')
            if mode == 'cwru':
                raw = item['raw_periodicity_peak_hz']; fused = item['fused_periodicity_peak_hz']
                rawc = item['raw_fault_contrast']; fusedc = item['fused_fault_contrast']
            else:
                label = item['fault_name']
                kind = 'bpfi' if label == 'BPFI' else 'bpfo'
                expected = item[kind+'_hz']
                raw = item['raw_'+kind+'_peak_hz']; fused = item['fused_'+kind+'_peak_hz']
                rawc = item['raw_'+kind+'_contrast']; fusedc = item['fused_'+kind+'_contrast']
            raster = item.get('time_raster', {})
            writer.writerow(dict(dataset=mode, file=file, start_sample=start,
                samples=item['end_sample']-start+1, fs_hz=item['fs_hz'],
                expected_hz=expected, raw_target_peak_hz=raw,
                fused_target_peak_hz=fused, target_error_hz=abs(fused-expected),
                raw_target_contrast=rawc, fused_target_contrast=fusedc,
                unlabelled_raw_peak_hz=item['unlabelled_raw_peak_hz'],
                unlabelled_fused_peak_hz=item['unlabelled_fused_peak_hz'],
                unlabelled_raw_contrast=item['unlabelled_raw_contrast'],
                unlabelled_fused_contrast=item['unlabelled_fused_contrast'],
                retained_pixel_fraction=item['retained_pixel_fraction'],
                eligible_time_pairs=item['eligible_time_pairs'],
                raster_global_fs_hz=raster.get('global_implied_fs_hz', ''),
                raster_segment_fs_hz=raster.get('segment_implied_fs_hz', ''),
                reference_status='MATCH' if not errors else 'MISMATCH'))
    Path('results/audit_summary.json').write_text(json.dumps(summary, indent=2))
    print('AUDIT_RERUN', len(new), 'REFERENCE_MATCHES', len(new)-len(summary['mismatches']))
    for key, errors in summary['mismatches'].items():
        print('MISMATCH', key, errors[:5])
    assert not summary['mismatches'], 'Reference JSON comparison failed'


if __name__ == '__main__':
    main()
