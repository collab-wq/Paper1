#!/usr/bin/env python3
"""Post-process the executed target-informed results; no MATLAB recomputation."""
import argparse
import csv
import json
import math
import statistics
from collections import Counter, defaultdict
from pathlib import Path

p=argparse.ArgumentParser()
p.add_argument('--results',type=Path,default=Path('REAL_DATA_FULL_RESULTS.csv'))
p.add_argument('--segments',type=Path,default=Path('SEGMENT_MANIFEST.csv'))
p.add_argument('--sources',type=Path,default=Path('DATASET_MANIFEST.csv'))
p.add_argument('--out',type=Path,default=Path('.'))
a=p.parse_args(); a.out.mkdir(parents=True,exist_ok=True)

def read(path):
    with path.open(newline='') as f: return list(csv.DictReader(f))

def number(value):
    try:
        value=float(value)
        return value if math.isfinite(value) else None
    except (TypeError,ValueError): return None

def median(values):
    v=[x for x in values if x is not None]
    return statistics.median(v) if v else ''

results=read(a.results); segments=read(a.segments); sources=read(a.sources)
assert len(results)==10492 and len(sources)==5060,(len(results),len(sources))
assert len(segments)>=10486
assert not any('118.mat' in r['file'] for r in results)
meta={}
for s in segments:
    k=(s['dataset'],s['source_file'],int(float(s['start_sample'])))
    if k in meta:
        assert meta[k]['sha256']==s['sha256'],('input hash mismatch',k)
    else: meta[k]=s
assert len(meta)==10486,len(meta)
data=[]; seen=set(); window_keys=set()
for r in results:
    ds=r['dataset']; path=Path(r['file']); start=int(float(r['start_sample']))
    key=(ds,r['file'],start); target=r['target']; ident=key+(target,)
    assert ident not in seen,ident
    seen.add(ident);window_keys.add(key)
    assert key in meta,('missing segment',key)
    fault='复合内外圈' if ds=='paderborn' and 'KB24' in path.stem else ('内圈' if target=='BPFI' else '外圈')
    assert target in ('BPFO','BPFI')
    bearing=path.parent.name if ds=='xjtu' else (path.stem.split('_')[-2] if ds=='paderborn' else path.stem)
    condition='';stage='';progress=None
    if ds=='cwru':
        n=int(path.stem)
        load=0 if n in (105,130,144,156) else (1 if n in (106,131,145,158) else 2)
        condition=f'{load} HP; {meta[key]["rpm"]} rpm'
    elif ds=='paderborn': condition='N15_M07_F10'
    elif ds=='ottawa':
        condition={'A':'升速','B':'降速','C':'先升后降'}[path.stem.split('-')[1]]
        bearing=path.stem
    else:
        count={'Bearing1_2':161,'Bearing1_3':158,'Bearing2_1':491,
               'Bearing2_2':161,'Bearing3_1':2538,'Bearing3_4':1515}[bearing]
        snap=int(path.stem)
        progress=(snap-1)/(count-1)
        stage='早期' if progress<=1/3 else ('中期' if progress<=2/3 else '后期')
        condition=stage
    cand=json.loads(r['candidates_json'])
    assert [(c['R'],c['hypothesis']) for c in cand]==[(n,target) for n in (2,3,4)]
    selected=[c for c in cand if c['valid']]
    if r['status']=='SELECTED':
        assert selected
        winner=min(selected,key=lambda c:(-c['J'],c['R']))
        assert int(r['selected_R'])==winner['R']
        assert abs(float(r['J'])-winner['J'])<1e-10
    else:
        assert r['status']=='NO_VALID_R' and not selected
        winner=None
    data.append(dict(dataset=ds,bearing=bearing,fault=fault,target=target,
        condition=condition,stage=stage,progress=progress,record=r,
        candidates=cand,winner=winner))
assert len(window_keys)==10486
kb=defaultdict(set)
for d in data:
    if d['bearing']=='KB24':
        r=d['record'];kb[(r['file'],r['start_sample'])].add(d['target'])
assert len(kb)==6 and all(x=={'BPFO','BPFI'} for x in kb.values())

def group(rows,dataset,bearing,fault,condition):
    valid=[d for d in rows if d['winner']]
    out=dict(dataset=dataset,bearing=bearing,fault_type=fault,
        condition_or_stage=condition,target_hypothesis=rows[0]['target'] if len({x['target'] for x in rows})==1 else 'separate',
        total_evaluations=len(rows),valid_R=len(valid),NO_VALID_R=len(rows)-len(valid),
        valid_rate=len(valid)/len(rows),error_unit='order' if dataset=='ottawa' else 'Hz')
    for R in (2,3,4):
        subset=[d['winner'] for d in valid if d['winner']['R']==R]
        out[f'R{R}_count']=len(subset)
        out[f'R{R}_share_of_valid']=len(subset)/len(valid) if valid else ''
        field='error_order' if dataset=='ottawa' else 'error_hz'
        out[f'R{R}_error_median']=median([number(c.get(field)) for c in subset])
        out[f'R{R}_J_median']=median([number(c.get('J')) for c in subset])
    out['error_median']=median([number(d['winner'].get('error_order' if dataset=='ottawa' else 'error_hz')) for d in valid])
    out['J_median']=median([number(d['winner']['J']) for d in valid])
    return out

groups=[]
for ds in ('cwru','paderborn','ottawa','xjtu'):
    these=[d for d in data if d['dataset']==ds]
    if ds=='cwru':
        keys=sorted({(d['bearing'],d['fault'],d['condition']) for d in these})
        for b,f,c in keys: groups.append(group([d for d in these if (d['bearing'],d['fault'],d['condition'])==(b,f,c)],ds,b,f,c))
    elif ds=='paderborn':
        for b,t in sorted({(d['bearing'],d['target']) for d in these}):
            subset=[d for d in these if (d['bearing'],d['target'])==(b,t)]
            groups.append(group(subset,ds,b,subset[0]['fault'],'N15_M07_F10'))
    elif ds=='ottawa':
        for b in sorted({d['bearing'] for d in these}):
            subset=[d for d in these if d['bearing']==b]
            groups.append(group(subset,ds,b,subset[0]['fault'],subset[0]['condition']))
        for mode in ('升速','降速','先升后降'):
            subset=[d for d in these if d['condition']==mode]
            groups.append(group(subset,ds,'全部六工况', '内圈+外圈分组总计',mode))
    else:
        for b in sorted({d['bearing'] for d in these}):
            for stage in ('早期','中期','后期'):
                subset=[d for d in these if d['bearing']==b and d['stage']==stage]
                groups.append(group(subset,ds,b,subset[0]['fault'],stage))
        for stage in ('早期','中期','后期'):
            subset=[d for d in these if d['stage']==stage]
            groups.append(group(subset,ds,'六轴承合计','内圈+外圈分组总计',stage))
    groups.append(group(these,ds,'数据集合计','内圈+外圈分组总计','全部'))

def cause(candidates):
    reasons=[c['reason'] for c in candidates]
    rs=set(reasons)
    if any(x.startswith('R_EXECUTION_FAILED') for x in reasons): return 'R_EXECUTION_FAILED_OR_MIXED'
    if all(x.startswith('INSUFFICIENT_BANDS') for x in reasons): return 'INSUFFICIENT_BANDS'
    if rs=={'CONTRAST_NOT_ABOVE_BACKGROUND'}: return 'CONTRAST_NOT_ABOVE_BACKGROUND'
    if rs=={'ERROR_EXCEEDS_PHYSICAL_RESOLUTION'}: return 'ERROR_EXCEEDS_PHYSICAL_RESOLUTION'
    if rs=={'NONFINITE_OR_MISSING_PHYSICS'}: return 'NONFINITE_OR_MISSING_PHYSICS'
    if rs=={'NONFINITE_SCORE'}: return 'NONFINITE_SCORE'
    if rs <= {'CONTRAST_NOT_ABOVE_BACKGROUND','ERROR_EXCEEDS_PHYSICAL_RESOLUTION'}:
        return 'MIXED_CONTRAST_AND_RESOLUTION'
    return 'UNDETERMINED_OR_MIXED'

cause_rows=[]
for ds in ('cwru','paderborn','ottawa','xjtu'):
    subset=[d for d in data if d['dataset']==ds and not d['winner']]
    dimensions={(d['fault'],d['target'],d['bearing'],d['stage'] if ds=='xjtu' else '全部') for d in subset}
    dimensions|={(d['fault'],d['target'],'全部','全部') for d in subset}
    for fault,target,bearing,stage in sorted(dimensions):
        chosen=[d for d in subset if d['fault']==fault and d['target']==target and
                (bearing=='全部' or d['bearing']==bearing) and
                (stage=='全部' or d['stage']==stage)]
        counter=Counter(cause(d['candidates']) for d in chosen)
        for why,n in sorted(counter.items()):
            cause_rows.append(dict(dataset=ds,bearing=bearing,fault_type=fault,
                target_hypothesis=target,stage=stage,cause=why,count=n,
                NO_VALID_R_total=len(chosen)))

def write(name,items):
    with (a.out/name).open('w',newline='') as fp:
        writer=csv.DictWriter(fp,fieldnames=list(items[0]));writer.writeheader();writer.writerows(items)
write('NO_VALID_R_SUMMARY.csv',groups)
write('NO_VALID_R_CAUSES.csv',cause_rows)

lines=['# 全量真实轴承实验：NO_VALID_R 专项统计分析','',
       '## 数据完整性与方法','',
       f'本轮共 {len(window_keys):,} 个不同分析窗口、{len(data):,} 次目标评价；KB24 的 6 个物理窗口各有 BPFO 和 BPFI 两套独立结果。全部记录各含 R=2、3、4 三条候选。输入片段 SHA-256、数据来源 SHA-256 与本轮 Artifact 清单核对；没有重新计算 WVD。', '',
       '有效候选严格沿用 MATLAB `evaluate_band_count.m`：线性对比度 $C>1$、定位误差不超过物理分辨率 $\\Delta$，且 $J$ 有限并大于 0。程序不存在额外的 J 分数阈值。无效原因依据三条候选保存的 `reason` 字段分类；`ERROR_EXCEEDS_PHYSICAL_RESOLUTION` 只表示局部最大峰定位超限，不能由此单独断言数据长度不足或故障物理不存在。', '',
       'XJTU-SY 数据仅有每分钟顺序快照和标称工况，本报告用快照序号的归一化进度 $(n-1)/(N-1)$ 划分早（$p\\le1/3$）、中（$1/3<p\\le2/3$）、晚（$p>2/3$）。这不是官方损伤等级。每快照两个固定窗口分别计数。Ottawa 误差为阶次，其他数据集为 Hz，不跨单位合并。', '',
       '## 统一汇总表','',
       '| 数据集 | 轴承/记录 | 故障类型 | 工况/阶段 | 总评价 | 有效 R | NO_VALID_R | 有效率 | R2/R3/R4 | 误差中位数 | J 中位数 |',
       '|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|']
for g in groups:
    lines.append(f"| {g['dataset']} | {g['bearing']} | {g['fault_type']} ({g['target_hypothesis']}) | {g['condition_or_stage']} | {g['total_evaluations']} | {g['valid_R']} | {g['NO_VALID_R']} | {g['valid_rate']:.1%} | {g['R2_count']}/{g['R3_count']}/{g['R4_count']} | {g['error_median']:.4g} {g['error_unit'] if g['error_median']!='' else ''} | {g['J_median']:.4g} |")
lines += ['', '各 R 的选择占比、误差及 J 中位数见 `NO_VALID_R_SUMMARY.csv`。占比以本组有效 R 数为分母；误差与 J 只取实际选中的有效候选。', '',
          '## NO_VALID_R 原因分布','',
          '原因统计见 `NO_VALID_R_CAUSES.csv`，按数据集、故障目标、轴承和 XJTU 寿命阶段分层。候选同时存在对比度不足和定位超限时列为混合原因，不强行归于单一物理机制。数值/执行失败与候选峰不足单列。', '']
for ds in ('cwru','paderborn','ottawa','xjtu'):
    counts=Counter(cause(d['candidates']) for d in data if d['dataset']==ds and not d['winner'])
    lines.append(f"- {ds}："+'；'.join(f'{k} {v}' for k,v in sorted(counts.items()))+'。')
lines += ['', '## 重点观察','']
for b in ('Bearing1_2','Bearing1_3','Bearing2_1','Bearing2_2','Bearing3_1','Bearing3_4'):
    bb=[g for g in groups if g['dataset']=='xjtu' and g['bearing']==b]
    lines.append(f"- {b}：早/中/晚有效率 "+' / '.join(f"{g['valid_rate']:.1%}" for g in bb)+'；R2/R3/R4 次数依次为 '+ '、'.join(f"{g['R2_count']}/{g['R3_count']}/{g['R4_count']}" for g in bb)+'。')
lines += ['', 'KB24 复合损伤须分别读取汇总表中的 BPFO 和 BPFI 行；两种理论频率的误差与有效率不能混算。Ottawa 的六条记录及升/降/先升后降模式行分别列出，但模式合计包含内、外圈两种故障，解读时须结合目标类型。', '',
          '## 限制','',
          '本分析依赖本轮保存的 MATLAB 候选与输入元数据，不把 `NO_VALID_R` 等同于无故障或算法故障。局部峰不足、频率分辨率与物理弱证据不能仅凭一个失败代码进一步区分；无法从现有字段证实的原因保持程序级描述。', '']
(a.out/'NO_VALID_R_ANALYSIS.md').write_text('\n'.join(lines))
print(json.dumps({'windows':len(window_keys),'evaluations':len(data),
                  'NO_VALID_R':sum(not d['winner'] for d in data),
                  'groups':len(groups),'cause_rows':len(cause_rows)}))
