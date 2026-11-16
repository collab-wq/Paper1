#!/usr/bin/env python3
"""Gate the three target-informed MATLAB end-to-end cases."""
import json
from pathlib import Path

root=Path('results/adaptive-band-selection')
cases={
    'cwru-105': {'BPFO': 0, 'BPFI': 1},
    'cwru-130': {'BPFO': 1, 'BPFI': 0},
    'KB24_1-start64001': {'BPFO': 1, 'BPFI': 1},
}
for token, targets in cases.items():
    for target, expected in targets.items():
        found=[p for p in root.rglob('result.json')
               if token in str(p) and p.parent.name==f'target-{target.lower()}']
        assert len(found)==expected, (token,target,found)
        for path in found:
            result=json.loads(path.read_text())
            assert result['target_hypothesis']==target
            assert [(c['R'],c['hypothesis']) for c in result['candidates']]==[
                (2,target),(3,target),(4,target)]
            assert all(c['hypothesis']!='BSF' for c in result['candidates'])
            assert (path.parent/'candidate_spectra.png').is_file()
            if result['status']=='SELECTED':
                assert (path.parent/'paper_figure.png').is_file()
            print('CORRECTED_TARGET_PASS',token,target,result['status'],result['selected_R'])
