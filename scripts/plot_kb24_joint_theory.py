#!/usr/bin/env python3
"""Present independently selected KB24 spectra with both physical line sets."""
import csv
import json
import math
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

root=Path('staging/paderborn'); out=Path('figures/full-real');out.mkdir(parents=True,exist_ok=True)
paths=[p for p in root.rglob('result.json') if 'KB24' in str(p)]
assert len(paths)==12,len(paths)
groups={}
for path in paths:
    obj=json.loads(path.read_text())
    assert obj['target_fault_type']=='composite' and obj['target_hypothesis'] in ('BPFO','BPFI')
    key=(Path(obj['file']).stem,int(obj['start_sample']))
    groups.setdefault(key,{})[obj['target_hypothesis']]=(path,obj)
assert len(groups)==6 and all(set(g)=={'BPFO','BPFI'} for g in groups.values())

def spectrum(path,r):
    with (path.parent/f'candidate_R{r}_spectrum.csv').open(newline='') as f:
        rows=list(csv.DictReader(f))
    return tuple(np.array([float(row[k]) for row in rows]) for k in
                 ('repetition_axis','original_power','fused_power'))

for (name,start),both in sorted(groups.items()):
    theory={h:float(obj['candidates'][0]['theoretical_hz']) for h,(p,obj) in both.items()}
    fig,axes=plt.subplots(2,1,figsize=(12,9),constrained_layout=True)
    for ax,h in zip(axes,('BPFO','BPFI')):
        path,obj=both[h]
        r=int(obj['selected_R']) if obj['status']=='SELECTED' else 2
        axis,raw,fused=spectrum(path,r)
        target=theory[h]
        background=(axis>=50)&(axis<=200)&~((axis>=.8*target)&(axis<=1.2*target))
        eps=np.finfo(float).eps
        raw_db=10*np.log10(raw/(np.median(raw[background])+eps)+eps)
        fused_db=10*np.log10(fused/(np.median(fused[background])+eps)+eps)
        upper=50*math.ceil(3.5*max(theory.values())/50)
        shown=(axis>=0)&(axis<=upper)
        ax.plot(axis[shown],raw_db[shown],color='#555555',lw=.85,label='Original')
        ax.plot(axis[shown],fused_db[shown],color='#155f9a',lw=1.1,label='Fused')
        for label,color,style in (('BPFO','#c33b34','--'),('BPFI','#9061a5',':')):
            for n in (1,2,3):
                loc=n*theory[label]
                if loc<=axis[-1]:
                    ax.axvline(loc,color=color,ls=style,lw=.9,
                               label=f'{n}×{label} = {loc:.2f} Hz')
                    ax.text(loc,.97,f'{n}×{label}',transform=ax.get_xaxis_transform(),
                            color=color,ha='center',va='top',fontsize=7,rotation=90,
                            bbox={'facecolor':'white','alpha':.8,'edgecolor':'none','pad':.5})
        ax.set_xlim(0,min(upper,axis[-1]));ax.set_ylabel('Power / background median (dB)')
        visible=np.r_[raw_db[shown],fused_db[shown]]
        visible=visible[np.isfinite(visible)]
        ax.set_ylim(np.percentile(visible,2)-5,np.max(visible)+8)
        title=(f'{h} target · independently selected R={r} · J={obj["selected_score"]:.3f}'
               if obj['status']=='SELECTED' else
               f'{h} target · NO_VALID_R · R=2 spectrum shown only')
        ax.set_title(title)
        ax.grid(alpha=.15)
        ax.legend(loc='lower left',ncol=4,fontsize=7,framealpha=.9)
    axes[-1].set_xlabel('Repetition frequency (Hz)')
    fig.suptitle(f'Paderborn KB24 · {name} · start sample {start} · theoretical lines fixed by geometry/speed',fontsize=12)
    stem=f'kb24-{name}-start{start}-joint-theory'
    fig.savefig(out/(stem+'.png'),dpi=300)
    fig.savefig(out/(stem+'.pdf'))
    plt.close(fig)
print('KB24_JOINT_THEORY_PASS',len(groups))
