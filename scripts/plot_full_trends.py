#!/usr/bin/env python3
"""Plot all executed windows; do not fill missing snapshots or failed windows."""
import csv
import json
from collections import defaultdict
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

root=Path('results/summary')
with (root/'REAL_DATA_FULL_RESULTS.csv').open() as f:
    rows=list(csv.DictReader(f))

def number(value):
    try: return float(value)
    except (ValueError,TypeError): return float('nan')

def sample_index(value):
    number_value=float(value)
    assert number_value.is_integer(),f'Nonintegral sample index: {value}'
    return int(number_value)

def save(fig,name):
    fig.set_size_inches(14,18)
    fig.tight_layout(rect=[0,0,1,.975],pad=2)
    fig.savefig(root/name,dpi=300)
    fig.savefig(root/name.replace('.png','.pdf'))
    plt.close(fig)

for bearing in ['Bearing1_2','Bearing1_3','Bearing2_1','Bearing2_2','Bearing3_1','Bearing3_4']:
    subset=[r for r in rows if r['dataset']=='xjtu' and r['bearing']==bearing]
    subset.sort(key=lambda r:(int(Path(r['file']).stem),sample_index(r['start_sample'])))
    if not subset: continue
    full_count={'Bearing1_2':161,'Bearing1_3':158,'Bearing2_1':491,
                'Bearing2_2':161,'Bearing3_1':2538,'Bearing3_4':1515}[bearing]
    fig,axes=plt.subplots(4,2)
    fields=[('selected_R','Selected R'),('J','Score J'),('error_hz','Error (Hz)'),
            ('contrast_linear','Contrast (linear power)'),
            ('location_confidence','Location confidence'),
            ('contrast_utility','Contrast utility'),
            ('status','NO_VALID_R fraction per snapshot'),
            ('candidate_ranks','Valid hypothesis ranks by J')]
    for ax,(field,title) in zip(axes.flat,fields):
        if field=='status':
            by_snapshot=defaultdict(list)
            for row in subset: by_snapshot[int(Path(row['file']).stem)].append(row)
            xs=list(range(1,full_count+1))
            values=[sum(r['status']=='NO_VALID_R' for r in by_snapshot[n])/2
                    if len(by_snapshot[n])==2 else float('nan') for n in xs]
            ax.plot(xs,values,'.',markersize=3)
            ax.set_yticks([0,.5,1]); ax.set_ylim(-.08,1.08)
        elif field=='candidate_ranks':
            for hypothesis,color in [('BPFO','tab:red'),('BPFI','tab:blue'),('BSF','tab:green')]:
                xs=[]; ranks=[]
                for row in subset:
                    best={}
                    for candidate in json.loads(row['candidates_json']):
                        score=number(candidate.get('J'))
                        if candidate.get('valid') and np.isfinite(score):
                            name=candidate['hypothesis']
                            best[name]=max(best.get(name,-np.inf),score)
                    ordered=sorted(best,key=lambda name:(-best[name],name))
                    if hypothesis in ordered:
                        xs.append(int(Path(row['file']).stem))
                        ranks.append(ordered.index(hypothesis)+1)
                ax.scatter(xs,ranks,s=6,alpha=.35,color=color,label=hypothesis)
            ax.set_yticks([1,2,3]); ax.set_ylim(3.3,.7)
            ax.legend(fontsize=8)
        else:
            for start,marker,color,label in [
                (4097,'o','tab:blue','Window 1'),
                (16385,'x','tab:orange','Window 2')]:
                selected=[r for r in subset if sample_index(r['start_sample'])==start]
                values=[number(r[field]) for r in selected]
                positions=[int(Path(r['file']).stem) for r in selected]
                ax.scatter(positions,values,s=6,alpha=.6,marker=marker,
                           color=color,label=label)
            if field=='selected_R': ax.legend(fontsize=8)
        ylabel=('Fraction' if field=='status' else
                'Rank (1 best)' if field=='candidate_ranks' else title)
        ax.set(title=title,xlabel='Snapshot number (1 minute spacing)',ylabel=ylabel)
        ax.set_xlim(1,full_count)
        ax.grid(alpha=.2)
    fig.suptitle(f'{bearing}: all executed windows; two windows per snapshot')
    save(fig,f'xjtu-{bearing}-lifetime.png')

for stem in ['I-A-2','I-B-2','I-C-2','O-A-2','O-B-2','O-C-2']:
    subset=[r for r in rows if r['dataset']=='ottawa' and Path(r['file']).stem==stem]
    subset.sort(key=lambda r:sample_index(r['start_sample']))
    if not subset: continue
    x=[(sample_index(r['start_sample'])-1)/200000 for r in subset]
    trace_path=root/f'ottawa-{stem}-encoder-trace.csv'
    assert trace_path.is_file(),f'Missing measured speed trajectory: {trace_path}'
    with trace_path.open(newline='') as stream: trace=list(csv.DictReader(stream))
    t=[number(r['time_s']) for r in trace]
    fig,axes=plt.subplots(4,2)
    ax=axes.flat[0]
    ax.plot(t,[number(r['rpm']) for r in trace],lw=1,label='Encoder RPM')
    ax.plot(x,[number(r['rpm']) for r in subset],'.',markersize=2,label='Window median')
    ax.set(title='Instantaneous shaft speed',ylabel='Speed (rpm)')
    ax.legend(fontsize=8); ax.grid(alpha=.2)
    ax=axes.flat[1]
    for field,label,color in [('bpfo_hz','BPFO','tab:red'),('bpfi_hz','BPFI','tab:green')]:
        ax.plot(t,[number(r[field]) for r in trace],color=color,lw=1,label=label)
    ax.set(title='Encoder-derived theoretical frequencies',ylabel='Frequency (Hz)')
    ax.legend(fontsize=8); ax.grid(alpha=.2)
    fields=[('selected_R','Selected R','Bands'),('J','Score J','Score'),
            ('error_order','Order error','Order'),
            ('contrast_linear','Order contrast','Power ratio')]
    for ax,(field,title,unit) in zip(axes.flat[2:6],fields):
        ax.plot(x,[number(r[field]) for r in subset],'.-',markersize=3,linewidth=.8)
        ax.set(title=title,ylabel=unit); ax.grid(alpha=.2)
    axes.flat[2].set_yticks([2,3,4])
    ax=axes.flat[6]
    for field,label in [('location_confidence','Qe'),('contrast_utility','Qc')]:
        ax.plot(x,[number(r[field]) for r in subset],'.-',markersize=2,
                linewidth=.8,label=label)
    ax.set(title='Score components',ylabel='0–1')
    ax.legend(fontsize=8); ax.grid(alpha=.2)
    ax=axes.flat[7]
    ax.step(x,[int(r['status']=='NO_VALID_R') for r in subset],where='mid')
    ax.set(title='NO_VALID_R by window',ylabel='0 or 1',ylim=(-.08,1.08))
    ax.set_yticks([0,1]); ax.grid(alpha=.2)
    for ax in axes.flat: ax.set_xlabel('Record time (s)')
    fig.suptitle(f'Ottawa {stem}: encoder-referenced order evidence')
    save(fig,f'ottawa-{stem}-trend.png')
