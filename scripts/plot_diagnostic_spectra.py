#!/usr/bin/env python3
"""Replot saved MATLAB periodicity spectra without rerunning WVD or detection."""
import csv
from collections import defaultdict
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

windows={r['window_id']:r for r in csv.DictReader(open('DIAGNOSTIC_WINDOWS.csv',newline=''))}
peaks=defaultdict(list)
for row in csv.DictReader(open('TARGET_HARMONIC_PEAKS.csv',newline='')):
    peaks[(row['window_id'],int(row['R']),row['ranks'])].append(row)
out=Path('figures/target-harmonic-diagnostics')
for wid,w in windows.items():
    root=Path('staging')/f'diagnostic-{wid}'
    target=float(w['theoretical_target']); unit=w['target_unit']
    for R in (2,3,4):
        ranks='['+' '.join(str(i) for i in range(1,R+1))+']'
        with (root/f'spectrum-R{R}.csv').open(newline='') as f:
            data=list(csv.DictReader(f))
        axis=np.array([float(r['repetition_axis']) for r in data]);
        raw=np.array([float(r['original_power']) for r in data]);
        fused=np.array([float(r['fused_power']) for r in data]);
        upper=min(axis.max(),3.5*target);shown=(axis>=0)&(axis<=upper)
        positive=np.r_[raw[shown],fused[shown]]
        positive=positive[np.isfinite(positive)&(positive>0)]
        assert len(positive)>0
        candidates=[float(p['power']) for p in peaks[(wid,R,ranks)]
                    if 0<=float(p['peak'])<=upper and float(p['power'])>0]
        low=max(np.percentile(positive,1),positive.max()*1e-7)
        if candidates: low=min(low,.7*min(candidates))
        high=positive.max()*40
        fig,ax=plt.subplots(figsize=(14,5.5))
        fig.subplots_adjust(left=.10,right=.78,bottom=.17,top=.86)
        ax.plot(axis[shown],raw[shown],color='#666666',lw=.95,label='Original')
        ax.plot(axis[shown],fused[shown],color='#1765a0',lw=1.15,label='Fused')
        ax.set_yscale('log');ax.set_ylim(low,high);ax.set_xlim(0,upper)
        for h in (1,2,3):
            x=h*target
            if x>upper:continue
            ax.axvline(x,color='#cc342d',ls='--',lw=.85)
            ax.text(x,.98,f'{h}×{w["target"]}',rotation=90,ha='left',va='top',
                    transform=ax.get_xaxis_transform(),color='#b32d28',fontsize=9,
                    bbox={'facecolor':'white','edgecolor':'none','alpha':.75,'pad':1})
        shown_valid=False;shown_invalid=False
        for p in peaks[(wid,R,ranks)]:
            x=float(p['peak']);y=float(p['power']);valid=p['valid']=='1'
            if not (0<=x<=upper and low<=y<=high):continue
            label='Valid local peak' if valid and not shown_valid else (
                'Other local peak' if not valid and not shown_invalid else None)
            ax.plot(x,y,'o' if valid else 'x',color='#168039' if valid else '#ae6c14',
                    ms=4.5 if valid else 4,mew=1,label=label)
            shown_valid|=valid;shown_invalid|=not valid
        ax.set_xlabel('Repetition order' if unit=='order' else 'Repetition frequency (Hz)')
        ax.set_ylabel('Periodicity power (linear; logarithmic axis)')
        ax.set_title(f'{wid} · R={R} · bands {ranks} · theory fixed before peak search',fontsize=12)
        ax.grid(alpha=.15,which='both')
        ax.legend(loc='upper left',bbox_to_anchor=(1.01,1),fontsize=9,framealpha=.95)
        fig.savefig(out/f'{wid}-spectrum-R{R}.png',dpi=300)
        fig.savefig(out/f'{wid}-spectrum-R{R}.pdf')
        plt.close(fig)
print('REPLOTTED_FROM_SAVED_SPECTRA',len(windows)*3)
