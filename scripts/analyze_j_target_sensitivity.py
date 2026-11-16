#!/usr/bin/env python3
"""Rescore archived target-informed spectra. Never compute or alter a WVD."""
import argparse
import csv
import json
import math
from collections import Counter
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import BoundaryNorm, ListedColormap
import numpy as np

CSATS = (5, 8, 10, 12, 15, 20)
WINDOWS = (.05, .10, .15, .20, .25, .30)
RUN_ID = 43831825178
BASE_SHA = 'c145c3cdfe265a50fa92e79f4694fbd8acf516fa'
SAMPLES = (
    ('cwru-105', 'cwru', 'cwru-105', 'BPFI'),
    ('paderborn-ka04', 'paderborn', 'KA04_1', 'BPFO'),
    ('ottawa-i-a-2', 'ottawa', 'I-A-2', 'BPFI'),
    ('xjtu-bearing1_2-1', 'xjtu', 'Bearing1_2-1-start4097', 'BPFO'),
    ('xjtu-bearing1_2-123', 'xjtu', 'Bearing1_2-123-start4097', 'BPFO'),
)


def close(actual, expected, field, path):
    assert math.isclose(actual, expected, rel_tol=2e-6, abs_tol=2e-7), (
        path, field, actual, expected)


def load_sample(staging, spec):
    sample_id, dataset, token, target = spec
    root = staging / dataset
    matches = [p for p in root.rglob('result.json') if token in str(p)]
    assert len(matches) == 1, (sample_id, matches)
    result_path = matches[0]
    result = json.loads(result_path.read_text())
    assert result['target_hypothesis'] == target, result_path
    assert result['status'] in ('SELECTED', 'NO_VALID_R')
    with (result_path.parent / 'candidates.csv').open(newline='') as fp:
        saved = list(csv.DictReader(fp))
    assert [int(c['R']) for c in saved] == [2, 3, 4]
    assert all(c['target_hypothesis'] == target and c['hypothesis'] == target for c in saved)
    spectra = {}
    for r in (2, 3, 4):
        path = result_path.parent / f'candidate_R{r}_spectrum.csv'
        assert path.is_file(), path
        with path.open(newline='') as fp:
            rows = list(csv.DictReader(fp))
        assert rows and {'repetition_axis', 'original_power', 'fused_power'} <= rows[0].keys()
        axis = np.array([float(v['repetition_axis']) for v in rows])
        original = np.array([float(v['original_power']) for v in rows])
        fused = np.array([float(v['fused_power']) for v in rows])
        assert np.all(np.isfinite(axis)) and np.all(np.diff(axis) > 0)
        assert np.all(np.isfinite(original)) and np.all(original >= 0)
        assert np.all(np.isfinite(fused)) and np.all(fused >= 0)
        spectra[r] = (axis, original, fused)
    unit = 'order' if dataset == 'ottawa' else 'Hz'
    field = 'theoretical_order' if unit == 'order' else 'theoretical_hz'
    resolution_field = 'physical_resolution_order' if unit == 'order' else 'physical_resolution_hz'
    theory = float(saved[0][field])
    delta = float(saved[0][resolution_field]) if unit == 'order' else float(result['fs_hz']) / float(result['signal_samples'])
    assert theory > 0 and delta > 0
    for row in saved:
        close(float(row[field]), theory, 'theory', result_path)
        if unit == 'order':
            close(float(row[resolution_field]), delta, 'resolution', result_path)
    return dict(id=sample_id, dataset=dataset, target=target, path=result_path,
                result=result, saved=saved, spectra=spectra, unit=unit,
                theory=theory, delta=delta)


def evidence(axis, power, target, window, unit, background_mode):
    search = (axis >= (1-window)*target) & (axis <= (1+window)*target)
    excluded = .30 if background_mode == 'fixed30' else window
    low, high = (.5, 12) if unit == 'order' else (50, 200)
    background = (axis >= low) & (axis <= high) & ~(
        (axis >= (1-excluded)*target) & (axis <= (1+excluded)*target))
    assert np.any(search) and np.any(background), (target, window, unit)
    positions = np.flatnonzero(search)
    index = positions[np.argmax(power[positions])]
    peak = float(axis[index])
    # MATLAB eps is the double-precision scalar added to the median.
    contrast = float(power[index] / (np.median(power[background]) + np.finfo(float).eps))
    return peak, contrast


def score(sample, r, csat, window, background_mode):
    axis, original, fused = sample['spectra'][r]
    theory, delta = sample['theory'], sample['delta']
    peak, contrast = evidence(axis, fused, theory, window, sample['unit'], background_mode)
    raw_peak, raw_contrast = evidence(axis, original, theory, window, sample['unit'], background_mode)
    error = abs(peak-theory)
    qe = math.exp(-.5*(error/delta)**2)
    qc = 0. if contrast <= 1 else min(1., math.log(contrast)/math.log(csat))
    if not all(map(math.isfinite, (peak, contrast, error, qe, qc))):
        reason = 'NONFINITE_OR_MISSING_PHYSICS'
    elif contrast <= 1:
        reason = 'CONTRAST_NOT_ABOVE_BACKGROUND'
    elif error > delta:
        reason = 'ERROR_EXCEEDS_PHYSICAL_RESOLUTION'
    else:
        reason = 'VALID'
    j = qe*qc if reason == 'VALID' else math.nan
    if reason == 'VALID' and (not math.isfinite(j) or j <= 0):
        reason, j = 'NONFINITE_SCORE', math.nan
    return dict(sample_id=sample['id'], dataset=sample['dataset'], target_hypothesis=sample['target'],
                evidence_unit=sample['unit'], R=r, Csat=csat, window_halfwidth=window,
                background_mode=background_mode, theoretical_target=theory, target_peak=peak,
                original_target_peak=raw_peak, original_contrast_linear=raw_contrast,
                error=error, physical_resolution=delta, contrast_linear=contrast,
                Qe=qe, Qc=qc, J=j, valid=reason == 'VALID', invalid_reason=reason)


def rank(rows):
    valid = [v for v in rows if v['valid']]
    if not valid:
        return 'NO_VALID_R'
    return min(valid, key=lambda v: (-v['J'], v['R']))['R']


def check_baseline(sample):
    rows = [score(sample, r, 10, .20, 'dynamic') for r in (2, 3, 4)]
    for computed, saved in zip(rows, sample['saved']):
        for field, old in [('target_peak', 'target_peak_order' if sample['unit']=='order' else 'target_peak_hz'),
                           ('error', 'error_order' if sample['unit']=='order' else 'error_hz'),
                           ('contrast_linear', 'contrast_linear'), ('Qe', 'location_confidence'),
                           ('Qc', 'contrast_utility')]:
            close(computed[field], float(saved[old]), field, sample['path'])
        # The Ottawa CSV is intentionally compact; its JSON retains raw-spectrum metrics.
        source = (sample['result']['candidates'][int(saved['R'])-2]
                  if sample['unit']=='order' else saved)
        for field, old in [('original_target_peak',
                            'raw_target_peak_order' if sample['unit']=='order' else 'raw_target_peak_hz'),
                           ('original_contrast_linear', 'raw_target_contrast')]:
            close(computed[field], float(source[old]), field, sample['path'])
        assert computed['valid'] == (saved['valid'].lower() in ('1', 'true')), (sample['path'], computed, saved)
        assert computed['invalid_reason'] == saved['reason'], (sample['path'], computed, saved)
        if computed['valid']:
            close(computed['J'], float(saved['J']), 'J', sample['path'])
        else:
            assert not math.isfinite(float(saved['J']))
    winner = rank(rows)
    assert winner == (sample['result']['selected_R'] or 'NO_VALID_R'), (sample['path'], winner)
    print('BASELINE_PASS', sample['id'], winner)
    return rows


def add_selection(rows):
    selected = rank(rows)
    for v in rows:
        v['selected_R'] = selected
        v['selected'] = isinstance(selected, int) and v['R'] == selected
    return rows


def write_csv(path, rows):
    assert rows
    with path.open('w', newline='') as fp:
        writer = csv.DictWriter(fp, fieldnames=list(rows[0]))
        writer.writeheader()
        for row in rows:
            writer.writerow({k: ('' if isinstance(v, float) and math.isnan(v) else v)
                             for k, v in row.items()})


def plot_heatmap(sample, by_config, outdir):
    cmap = ListedColormap(['#eeeeee', '#32669c', '#52a867', '#d78b3d'])
    norm = BoundaryNorm([-.5, .5, 1.5, 2.5, 3.5], cmap.N)
    fig, axes = plt.subplots(1, 2, figsize=(11, 5), constrained_layout=True)
    for ax, mode, title in zip(axes, ('dynamic', 'fixed30'),
                               ('Current background rule', 'Fixed ±30% background')):
        matrix = np.zeros((len(CSATS), len(WINDOWS)), dtype=int)
        for yi, csat in enumerate(CSATS):
            for xi, window in enumerate(WINDOWS):
                selected = by_config[(sample['id'], mode, csat, window)]
                matrix[yi, xi] = 0 if selected == 'NO_VALID_R' else selected-1
                ax.text(xi, yi, '—' if selected == 'NO_VALID_R' else str(selected),
                        ha='center', va='center', fontsize=10, fontweight='bold',
                        color='white' if selected in (2, 3) else 'black')
        ax.imshow(matrix, cmap=cmap, norm=norm, aspect='auto')
        ax.set_xticks(range(len(WINDOWS)), [f'±{w:.0%}' for w in WINDOWS])
        ax.set_yticks(range(len(CSATS)), [str(c) for c in CSATS])
        ax.set_xlabel('Target search halfwidth')
        ax.set_ylabel('Contrast saturation Csat')
        ax.set_title(title, fontsize=11)
        ax.spines[:].set_visible(False)
    fig.suptitle(f"{sample['id']} · {sample['target']} · selected R", fontsize=13)
    for ext in ('png', 'pdf'):
        fig.savefig(outdir / f"{sample['id']}-selection-heatmap.{ext}",
                    dpi=300 if ext=='png' else None)
    plt.close(fig)


def plot_harmonics(sample, outdir):
    fig, axes = plt.subplots(3, 1, figsize=(12, 11), constrained_layout=True)
    theory = sample['theory']
    upper = math.ceil(3.5*theory / (1 if sample['unit']=='order' else 50)) * (1 if sample['unit']=='order' else 50)
    for ax, r in zip(axes, (2, 3, 4)):
        grid, original, fused = sample['spectra'][r]
        _, raw_contrast = evidence(grid, original, theory, .20, sample['unit'], 'dynamic')
        _, fused_contrast = evidence(grid, fused, theory, .20, sample['unit'], 'dynamic')
        # The curves share the original MATLAB plot's separate background normalization.
        excluded = (grid >= .8*theory) & (grid <= 1.2*theory)
        low, high = (.5,12) if sample['unit']=='order' else (50,200)
        back = (grid>=low) & (grid<=high) & ~excluded
        raw_db = 10*np.log10(original/(np.median(original[back])+np.finfo(float).eps)+np.finfo(float).eps)
        fused_db = 10*np.log10(fused/(np.median(fused[back])+np.finfo(float).eps)+np.finfo(float).eps)
        shown = (grid>=0) & (grid<=upper)
        ax.plot(grid[shown], raw_db[shown], color='#555555', lw=.85, label='Original')
        ax.plot(grid[shown], fused_db[shown], color='#1467a7', lw=1., label='Fused')
        selected = score(sample,r,10,.20,'dynamic')
        ax.plot(selected['target_peak'], np.interp(selected['target_peak'],grid,fused_db),
                'o', ms=4, color='#1467a7', label='Located fundamental peak')
        for harmonic in (1,2,3):
            value = harmonic*theory
            if value <= float(grid[-1]):
                ax.axvline(value,color='#c43d38',ls='--',lw=.9,
                           label=f'{harmonic}× theoretical {sample["target"]}')
                ax.text(value, .98, f'{harmonic}×', transform=ax.get_xaxis_transform(),
                        color='#a62f2c', fontsize=9, ha='center', va='top',
                        bbox={'facecolor':'white','alpha':.88,'edgecolor':'none','pad':1})
            else:
                ax.text(.99,.98,f'{harmonic}× beyond axis/Nyquist',transform=ax.transAxes,
                        ha='right',va='top',color='#a62f2c')
        ax.set_xlim(0,min(upper,float(grid[-1])))
        visible=np.r_[raw_db[shown],fused_db[shown]]
        ax.set_ylim(np.nanpercentile(visible,2)-5,np.nanmax(visible)+10)
        ax.set_ylabel('Power / background median (dB)')
        ax.set_title(f'R={r} · C={fused_contrast:.2f} · J={selected["J"]:.4f}'
                     if selected['valid'] else f'R={r} · C={fused_contrast:.2f} · {selected["invalid_reason"]}',
                     fontsize=11)
        ax.grid(alpha=.15)
        if r==2:
            handles, labels=ax.get_legend_handles_labels()
            ax.legend(handles[:3], ['Original','Fused','Located fundamental peak'],
                      loc='upper right', fontsize=8, framealpha=.9)
    axes[-1].set_xlabel('Repetition order (cycles/revolution)' if sample['unit']=='order'
                        else 'Repetition frequency (Hz)')
    fig.suptitle(f"{sample['id']} · {sample['target']} · theory {theory:.4f} {sample['unit']}",fontsize=13)
    for ext in ('png','pdf'):
        fig.savefig(outdir / f"{sample['id']}-three-harmonics.{ext}",
                    dpi=300 if ext=='png' else None)
    plt.close(fig)


def report(samples, saturation, target_window, joint, by_config, outdir, path):
    lines = [
        '# J 饱和阈值与目标搜索窗口敏感性报告', '',
        '## 目的与范围', '',
        '本分析仅重评分已保存的目标约束 R=2、3、4 周期功率谱，不重新计算 WVD，不调整双方向三点检测、选带、融合掩膜或原有诊断指标。目标故障类型由原实验元数据指定。J 只衡量同一目标下不同 R 的周期证据，不能单独证明故障诊断成功；谐波图提供额外人工核查材料。KB24 保留历史结果但不纳入本分析。', '',
        f'基准代码：`{BASE_SHA}`；源数据：[Actions {RUN_ID}](https://github.com/collab-wq/Paper1/actions/runs/{RUN_ID}) 的四套目标约束代表运行 Artifact。分析样本为 CWRU 105/BPFI、Paderborn KA04/BPFO、Ottawa I-A-2/BPFI、XJTU Bearing1_2 快照 1 与 123/BPFO；这些是五个预先指定的片段，不代表全数据集统计。', '',
        '## 实际数学定义', '',
        r'从融合功率谱的 $[(1-r)f_0,(1+r)f_0]$（Ottawa 为阶次 $O_0$）内取最大谱峰。背景功率中位数使用恒速 50–200 Hz、Ottawa 0.5–12 阶，并排除该目标窗口。$C=P_{\mathrm{peak}}/(\operatorname{median}P_{\mathrm{background}}+\epsilon)$，$e=|f_{\mathrm{peak}}-f_0|$，$Q_e=\exp[-(e/\Delta)^2/2]$，$Q_C=0$（$C\le1$），否则 $Q_C=\min(1,\ln C/\ln C_{\mathrm{sat}})$，$J=Q_eQ_C$。只有 $C>1$、$e\le\Delta$ 且 J 为有限正数的候选参与排序；同分取较小 R，否则 `NO_VALID_R`。恒速 $\Delta=f_s/N$；Ottawa $\Delta=1/\Delta N_{\mathrm{rev}}$。', '',
        r'测试 $C_{\mathrm{sat}}\in\{5,8,10,12,15,20\}$ 与 $r\in\{5\%,10\%,15\%,20\%,25\%,30\%\}$。固定背景辅助对照始终排除目标 ±30%，仅改变寻峰范围；正式定义仍为背景随搜索窗口变化。所有表中的 `contrast_linear` 是线性功率比。', '',
        '## 基准复现', '',
        '脚本在写入结果前对每个样本、每个 R 的理论值、峰位、原始及融合对比度、误差、Qe、Qc、J、有效性、失败原因和最终 R 与存档 `candidates.csv`/`result.json` 比较；差异超出 CSV 浮点写出容差时立即失败。', '',
        '| 样本 | 目标 | 理论值 | 物理分辨率 | 基准最优 R |', '|---|---|---:|---:|---|'
    ]
    for sample in samples:
        winner=by_config[(sample['id'],'dynamic',10,.20)]
        lines.append(f"| {sample['id']} | {sample['target']} | {sample['theory']:.6f} {sample['unit']} | {sample['delta']:.6f} {sample['unit']} | {winner} |")
    lines += ['', '## 单因素与联合结果', '',
              '| 样本 | Csat 5–20：基准 R 改变 | 窗口 ±5–30%：基准 R 改变 | 36 格：基准 R 改变 | 36 格 NO_VALID_R 数 | 固定背景 36 格改变 |',
              '|---|---:|---:|---:|---:|---:|']
    for sample in samples:
        sid=sample['id']; base=by_config[(sid,'dynamic',10,.20)]
        sat=sum(by_config[(sid,'dynamic',c,.20)]!=base for c in CSATS)
        win=sum(by_config[(sid,'dynamic',10,w)]!=base for w in WINDOWS)
        jnt=sum(by_config[(sid,'dynamic',c,w)]!=base for c in CSATS for w in WINDOWS)
        no=sum(by_config[(sid,'dynamic',c,w)]=='NO_VALID_R' for c in CSATS for w in WINDOWS)
        fixed=sum(by_config[(sid,'fixed30',c,w)]!=base for c in CSATS for w in WINDOWS)
        lines.append(f'| {sid} | {sat}/6 | {win}/6 | {jnt}/36 | {no}/36 | {fixed}/36 |')
    lines += ['', '正式背景规则在各配置下的选择次数（每个样本一个选择，共 180 次）：', '',
              '| 选择 | 次数 |', '|---|---:|']
    counts=Counter(by_config[(s['id'],'dynamic',c,w)] for s in samples for c in CSATS for w in WINDOWS)
    for key in (2,3,4,'NO_VALID_R'):
        lines.append(f'| {key} | {counts[key]} |')
    lines += ['', '### 对基准参数的直接判断', '',
              '- **Csat=10**：固定 ±20% 时，CWRU、KA04、XJTU 早期与后期在 5–20 全范围保持原选择（早期仍为 NO_VALID_R）。Ottawa 在 Csat=5、8 从 R=3 改选 R=2，因此 10 对这五个片段并非完全处于稳定平台；Ottawa 的 R=2 对比度接近 10，而 R=3 已饱和，阈值改变了二者效用排序。',
              '- **±20% 窗口**：固定 Csat=10 时，CWRU、KA04、XJTU 后期在 ±5% 至 ±30% 均保持原选择；Ottawa 在 ±10%、±15% 改选 R=2；XJTU 早期仅 ±5% 出现有效 R=2。故 ±20% 对三个片段稳定，但不能称为所有代表片段均稳健。',
              '- **联合变化**：正式背景下 180 个样本×配置中 158 个与各自基准选择相同、22 个不同；变化集中在 Ottawa、早期 XJTU，以及 CWRU 的 Csat=20 与较宽窗口组合。该计数是五个预选片段的描述，不是总体稳定率。', '',
              '窗口改变时，目标峰与对比度可能同时改变，因为背景排除范围也变；`TARGET_WINDOW_SENSITIVITY.csv` 并列保存正式动态背景和固定 ±30% 背景。联合表同样保留两种背景规则。固定背景只用于机制对照，不参与正式算法修订。Ottawa 的固定背景对照在 Csat=10 的全部六个窗口均选 R=3，而动态背景在 ±10%、±15% 选 R=2：这两处改变由背景中位数改变而非目标峰搜索遗漏造成。', '',
              '## 早期 XJTU 的 NO_VALID_R', '']
    early=next(s for s in samples if s['id']=='xjtu-bearing1_2-1')
    for w in WINDOWS:
        rows=[score(early,r,10,w,'dynamic') for r in (2,3,4)]
        info=', '.join(f'R={v["R"]}: peak {v["target_peak"]:.3f} Hz, e {v["error"]:.3f} Hz, C {v["contrast_linear"]:.2f}, {v["invalid_reason"]}' for v in rows)
        lines.append(f'- ±{w:.0%}：{info}。')
    lines += ['', '基准 ±20% 的三个 R 优先选到约 95.7–96.5 Hz 的较强邻近峰，距理论 BPFO 约 11.4–12.2 Hz，超过 6.25 Hz 物理分辨率，因此全部无效。缩至 ±5% 后，R=2 找到 108.203 Hz 的较弱局部峰（C=3.84），并通过单峰有效性门槛。**因此本片段的基准 NO_VALID_R 直接由宽窗口内邻近强峰竞争造成；不能说理论 BPFO 附近完全没有周期响应。** 然而窄窗得到的较弱基频峰，以及三谐波图中不一致的高次响应，尚不足以宣称早期故障诊断成功。此结论只针对该代表性早期窗口。', '',
              '## 多谐波理论位置与图件', '',
              '每个样本各有一张 R=2、3、4 三面板图，原始与融合谱同时呈现；1×、2×、3× 理论位置在看谱峰前由存档物理目标值直接计算。图上的蓝点只标示基准 J 使用的实际基频峰。图片用于人工判断谐波联合表现，不引入多谐波 J。', '']
    for sample in samples:
        sid=sample['id']
        lines.append(f'- [{sid} 三谐波谱](figures/sensitivity/{sid}-three-harmonics.png)（[PDF](figures/sensitivity/{sid}-three-harmonics.pdf)）；[R 选择热图](figures/sensitivity/{sid}-selection-heatmap.png)（[PDF](figures/sensitivity/{sid}-selection-heatmap.pdf)）。')
    lines += ['', '按三个预先给定的理论位置目视核查：CWRU 105、KA04、Ottawa I-A-2 和 XJTU 第 123 次快照的融合谱在 1×、2×、3× 附近均可见不同程度的局部响应；各谐波强弱与融合前并不一致，不能据此直接计算统一诊断准确率。XJTU 第 1 次快照的 1× 附近仅有较弱局部响应，2× 附近可见峰，但 3× 附近响应不连续，故窄窗口单峰有效不足以确认早期故障。各谱分别以自己的背景中位数归一化成 dB，图中两条曲线的绝对幅度不能直接当作能量保持率。', '']
    lines += ['', '## 数据与限制', '',
              '`J_SATURATION_SENSITIVITY.csv` 为固定 ±20% 搜索、动态背景的逐 R 结果；`TARGET_WINDOW_SENSITIVITY.csv` 为固定 Csat=10 的逐 R 结果；`JOINT_SENSITIVITY.csv` 为 6×6×两种背景的逐 R 结果。每行含实际峰、原始峰、理论目标、误差、物理分辨率、对比度、Qe、Qc、J、有效性、原因和最终 R。谱来自目标约束分支的已运行 MATLAB 产物，CSV 写出可能带来微小浮点差异。五个片段不能代表全量稳健性；本次没有重新检验 WVD 图或核心算法，也不根据36格挑选更高分设置。', '']
    path.write_text('\n'.join(lines))


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--staging',type=Path,default=Path('staging'))
    args=parser.parse_args()
    samples=[load_sample(args.staging,s) for s in SAMPLES]
    for sample in samples:
        check_baseline(sample)
    saturation=[]; target_window=[]; joint=[]; selected={}
    for sample in samples:
        for mode in ('dynamic','fixed30'):
            for csat in CSATS:
                for window in WINDOWS:
                    rows=add_selection([score(sample,r,csat,window,mode) for r in (2,3,4)])
                    selected[(sample['id'],mode,csat,window)]=rows[0]['selected_R']
                    joint.extend(rows)
                    if mode=='dynamic' and window==.20:
                        saturation.extend(rows)
                    if csat==10:
                        target_window.extend(rows)
    assert len(saturation)==90 and len(target_window)==180 and len(joint)==1080
    for sample in samples:
        for r in (2,3,4):
            rows=[v for v in saturation if v['sample_id']==sample['id'] and v['R']==r]
            for key in ('target_peak','theoretical_target','error','physical_resolution','contrast_linear','Qe','valid','invalid_reason'):
                assert len({v[key] for v in rows})==1, (sample['id'],r,key)
    outdir=Path('figures/sensitivity'); outdir.mkdir(parents=True,exist_ok=True)
    for sample in samples:
        plot_heatmap(sample,selected,outdir)
        plot_harmonics(sample,outdir)
    write_csv(Path('J_SATURATION_SENSITIVITY.csv'),saturation)
    write_csv(Path('TARGET_WINDOW_SENSITIVITY.csv'),target_window)
    write_csv(Path('JOINT_SENSITIVITY.csv'),joint)
    report(samples,saturation,target_window,joint,selected,outdir,Path('SENSITIVITY_REPORT.md'))
    print('SENSITIVITY_PASS',len(samples),len(saturation),len(target_window),len(joint))


if __name__=='__main__':
    main()
