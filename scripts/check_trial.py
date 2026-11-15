#!/usr/bin/env python3
import json
import sys
from pathlib import Path

dataset=sys.argv[1]
root=Path('results/adaptive-band-selection')
files=[p for p in root.rglob('result.json') if dataset in p.parts or dataset in str(p)]
assert len(files)==1, f'Expected one trial result, got {files}'
result=json.loads(files[0].read_text())
assert result['mode']==dataset and len(result['candidates'])==9
assert {c['R'] for c in result['candidates']}=={2,3,4}
segment_dir=Path('results/input_segments') / files[0].parent.relative_to(root)
assert (segment_dir/'metadata.json').is_file()
assert (segment_dir/'wvd_input_float64.bin').is_file()
if result['status']=='SELECTED':
    assert (files[0].parent/'paper_figure.png').is_file()
    assert (files[0].parent/'paper_figure.pdf').is_file()
print(json.dumps({'dataset':dataset,'status':result['status'],
                  'selected_R':result.get('selected_R'),
                  'hypothesis':result.get('selected_hypothesis'),
                  'candidate_count':len(result['candidates']),
                  'result_path':str(files[0]),'input_path':str(segment_dir)}))
