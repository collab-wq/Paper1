#!/usr/bin/env python3
"""Collect executed per-window MATLAB diagnostics and write descriptive counts."""
import csv
import json
from collections import defaultdict
from pathlib import Path

root=Path('staging')
def read(name):
    files=list(root.rglob(name))
    assert len(files)==15,(name,len(files))
    rows=[]
    for f in files:
        with f.open(newline='') as src: rows+=list(csv.DictReader(src))
    return rows

tops=read('RESONANCE_CANDIDATES_TOP8.csv')
peaks=read('TARGET_HARMONIC_PEAKS.csv')
combos=read('BAND_COMBINATION_DIAGNOSTICS.csv')
assert len({r['window_id'] for r in tops})==15
assert all(4<=sum(r['window_id']==w for r in tops)<=8 for w in {r['window_id'] for r in tops})
assert len(combos)==sum(__import__('math').comb(sum(r['window_id']==w for r in tops),n)
    for w in {r['window_id'] for r in tops} for n in (2,3,4))
for filename,rows in [('RESONANCE_CANDIDATES_TOP8.csv',tops),
                      ('TARGET_HARMONIC_PEAKS.csv',peaks),
                      ('BAND_COMBINATION_DIAGNOSTICS.csv',combos)]:
    with open(filename,'w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
windows=list(csv.DictReader(open('DIAGNOSTIC_WINDOWS.csv',newline='')))
bywindow=defaultdict(list)
for row in combos:bywindow[row['window_id']].append(row)
assert set(bywindow)=={r['window_id'] for r in windows}
def yes(row,key): return row[key].lower() in ('true','1')
out=[]
for w in windows:
    rows=bywindow[w['window_id']];baseline=[r for r in rows if yes(r,'baseline')]
    assert len(baseline)==3
    extended=[r for r in rows if not yes(r,'baseline') and any(str(n) in r['ranks'].replace('[',' ').replace(']',' ').split() for n in range(5,9))]
    out.append(dict(window_id=w['window_id'],dataset=w['dataset'],bearing_or_condition=w['bearing_or_condition'],
        old_valid=int(any(yes(r,'old_valid') for r in baseline)),
        new_fundamental_valid=int(any(yes(r,'fundamental_valid') for r in baseline)),
        second_valid=int(any(yes(r,'second_harmonic_valid') for r in baseline)),
        third_valid=int(any(yes(r,'third_harmonic_valid') for r in baseline)),
        two_line_valid=int(any(yes(r,'two_line_valid') for r in baseline)),
        three_line_valid=int(any(yes(r,'three_line_valid') for r in baseline)),
        extended_fundamental_valid=int(any(yes(r,'fundamental_valid') for r in extended)),
        extended_two_line_valid=int(any(yes(r,'two_line_valid') for r in extended)),
        extended_three_line_valid=int(any(yes(r,'three_line_valid') for r in extended))))
groups=defaultdict(list)
for row in out:groups[(row['dataset'],row['bearing_or_condition'])].append(row)
summary=[]
for (ds,b),rows in sorted(groups.items()):
    summary.append(dict(dataset=ds,bearing_or_condition=b,windows=len(rows),
        **{k:sum(r[k] for r in rows) for k in out[0] if k.endswith('_valid')}))
with open('TARGET_HARMONIC_SUMMARY.csv','w',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=list(summary[0]));writer.writeheader();writer.writerows(summary)
tot={k:sum(r[k] for r in out) for k in out[0] if k.endswith('_valid')}
lines=['# Target and harmonic mechanism diagnostic','',
       'This is a retrospective mechanism test on 15 previously NO_VALID_R windows. It is not a revised production accuracy estimate.', '',
       '## Execution and definitions','',
       'Each source window is processed with one WVD call. The unchanged dual-direction detector and mask are rerun for all combinations of 2, 3 or 4 bands among up to eight eligible candidates. If the fixed original search and spacing rules yield fewer than eight candidates, only actual candidates are enumerated. Current top-R combinations are marked `baseline`; all other combinations are post hoc diagnostics. Local peaks use the original search interval, background median and physical resolution. A valid peak must simultaneously satisfy contrast > 1 and error <= resolution. Among valid peaks, the highest J is reported. Two-line evidence requires fundamental plus second or third harmonic; three-line evidence requires all three.', '',
       '## Sample results','',
       '| Dataset | Bearing / condition | Windows | Old valid | New fundamental | Two-line | Three-line | Extended fundamental |',
       '|---|---|---:|---:|---:|---:|---:|---:|']
for r in summary:
    lines.append(f"| {r['dataset']} | {r['bearing_or_condition']} | {r['windows']} | {r['old_valid']} | {r['new_fundamental_valid']} | {r['two_line_valid']} | {r['three_line_valid']} | {r['extended_fundamental_valid']} |")
lines+=['',f"Across 15 windows, the old top-R method validates {tot['old_valid']}, the all-local-peak search on the same top-R bands validates {tot['new_fundamental_valid']}, and {tot['extended_fundamental_valid']} have at least one post hoc combination containing rank 5–8 with a valid fundamental.",'',
       'A post hoc valid combination is evidence that resonance ranking can omit useful bands in these windows. It does not establish an online band-selection rule. Fundamental evidence alone is not sufficient to claim full fault recognition. See the two-line and three-line columns and per-peak CSV.', '',
       '## Source and reproducibility','',
       'Window IDs, segment hashes, source hashes, channels and original result paths are in `DIAGNOSTIC_WINDOWS.csv`. Candidate centers and boundaries, every local peak, and each band combination are preserved in the corresponding CSV. MATLAB logs and per-window plots are in the GitHub Actions Artifact. Ottawa errors are in order; XJTU errors are in Hz. No full-data rerun was performed.']
Path('TARGET_HARMONIC_DIAGNOSTICS.md').write_text('\n'.join(lines)+'\n')
print(json.dumps({'windows':len(out),'combinations':len(combos),'baseline_old_valid':tot['old_valid'],
                  'baseline_new_valid':tot['new_fundamental_valid'],'extended_valid':tot['extended_fundamental_valid']}))
