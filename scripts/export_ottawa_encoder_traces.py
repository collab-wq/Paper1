#!/usr/bin/env python3
"""Export measured shaft-speed and theoretical fault-frequency trajectories."""
import csv
import hashlib
from pathlib import Path

import numpy as np
from scipy.io import loadmat

source = Path('input/ottawa')
target = Path('results/summary')
target.mkdir(parents=True, exist_ok=True)
with (target / 'DATASET_MANIFEST.csv').open(newline='') as stream:
    expected = {row['record']: row['sha256'] for row in csv.DictReader(stream)
                if row['dataset'] == 'ottawa'}
assert len(expected) == 6
for name in ('I-A-2', 'I-B-2', 'I-C-2', 'O-A-2', 'O-B-2', 'O-C-2'):
    file = source / (name + '.mat')
    digest = hashlib.sha256(file.read_bytes()).hexdigest()
    assert digest == expected[name], f'Ottawa source changed: {name}'
    channel = np.asarray(loadmat(file,
                                 variable_names=['Channel_2'])['Channel_2'],
                         dtype=np.float64).ravel()
    ordered = np.sort(channel)
    low = ordered[max(1, round(.05 * len(ordered))) - 1]
    high = ordered[min(len(ordered), round(.95 * len(ordered))) - 1]
    assert high > low
    threshold = (low + high) / 2
    edges = np.flatnonzero((channel[:-1] < threshold) &
                           (channel[1:] >= threshold)) + 1
    edge_time = edges / 200_000
    span = 1024
    assert len(edge_time) > span
    rpm = 60 / (edge_time[span:] - edge_time[:-span])
    times = (edge_time[span:] + edge_time[:-span]) / 2
    assert np.all(np.isfinite(rpm)) and np.all((rpm > 100) & (rpm < 10_000))
    stride = max(1, len(times) // 2000)
    indices = np.unique(np.r_[np.arange(0, len(times), stride), len(times)-1])
    with (target / f'ottawa-{name}-encoder-trace.csv').open('w', newline='') as out:
        writer = csv.writer(out)
        writer.writerow(('time_s', 'rpm', 'bpfo_hz', 'bpfi_hz', 'encoder_ppr'))
        for index in indices:
            speed = rpm[index]
            writer.writerow((times[index], speed, 3.57*speed/60,
                             5.43*speed/60, span))
    print(name, len(edges), 'rising edges;', len(indices), 'speed samples;',
          float(rpm.min()), float(rpm.max()), 'RPM')
