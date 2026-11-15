#!/usr/bin/env python3
"""Plot all executed windows; do not fill missing snapshots or failed windows."""
import csv
from collections import defaultdict
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

root=Path('results/summary')
with (root/'REAL_DATA_FULL_RESULTS.csv').open() as f:
    rows=list(csv.DictReader(f))

def number(value):
    try: return float(value)
    except (ValueError,TypeError): return float('nan')

def save(fig,name):
    fig.set_size_inches(14,18)
    fig.tight_layout(pad=2)
    fig.savefig(root/name,dpi=300)
    fig.savefig(root/name.replace('.png','.pdf'))
    plt.close(fig)

for bearing in ['Bearing1_2','Bearing1_3','Bearing2_1','Bearing2_2','Bearing3_1','Bearing3_4']:
    subset=[r for r in rows if r['dataset']=='xjtu' and r['bearing']==bearing]
    subset.sort(key=lambda r:(int(Path(r['file']).stem),int(r['start_sample'])))
    if not subset: continue
    x=[int(Path(r['file']).stem) for r in subset]
    fig,axes=plt.subplots(4,2)
    fields=[('selected_R','Selected R'),('J','Score J'),('error_hz','Error (Hz)'),
            ('contrast_linear','Contrast (linear power)'),
            ('location_confidence','Location confidence'),
            ('contrast_utility','Contrast utility'),
            ('status','NO_VALID_R'),('selected_hypothesis','Hypothesis rank 1')]
    for ax,(field,title) in zip(axes.flat,fields):
        if field=='status': values=[int(r[field]=='NO_VALID_R') for r in subset]
        elif field=='selected_hypothesis':
            values=[{'BPFO':1,'BPFI':2,'BSF':3}.get(r[field],float('nan')) for r in subset]
            ax.set_yticks([1,2,3],['BPFO','BPFI','BSF'])
        else: values=[number(r[field]) for r in subset]
        ax.scatter(x,values,s=5,alpha=.6)
        ax.set(title=title,xlabel='Snapshot number (1 minute spacing)',ylabel=title)
        ax.grid(alpha=.2)
    fig.suptitle(f'{bearing}: all executed windows; two windows per snapshot')
    save(fig,f'xjtu-{bearing}-lifetime.png')

for stem in ['I-A-2','I-B-2','I-C-2','O-A-2','O-B-2','O-C-2']:
    subset=[r for r in rows if r['dataset']=='ottawa' and Path(r['file']).stem==stem]
    subset.sort(key=lambda r:int(r['start_sample']))
    if not subset: continue
    x=[(int(r['start_sample'])-1)/200000 for r in subset]
    fig,axes=plt.subplots(3,2)
    fields=[('rpm','Encoder RPM'),('selected_R','Selected R'),
            ('J','Score J'),('error_order','Order error'),
            ('contrast_linear','Order contrast (linear power)'),
            ('status','NO_VALID_R')]
    for ax,(field,title) in zip(axes.flat,fields):
        values=([int(r[field]=='NO_VALID_R') for r in subset] if field=='status'
                else [number(r[field]) for r in subset])
        ax.plot(x,values,'.-',markersize=3,linewidth=.8)
        ax.set(title=title,xlabel='Record time (s)',ylabel=title)
        ax.grid(alpha=.2)
    fig.suptitle(f'Ottawa {stem}: encoder-referenced order evidence')
    save(fig,f'ottawa-{stem}-trend.png')
