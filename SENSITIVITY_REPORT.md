# J 饱和阈值与目标搜索窗口敏感性报告

## 目的与范围

本分析仅重评分已保存的目标约束 R=2、3、4 周期功率谱，不重新计算 WVD，不调整双方向三点检测、选带、融合掩膜或原有诊断指标。目标故障类型由原实验元数据指定。J 只衡量同一目标下不同 R 的周期证据，不能单独证明故障诊断成功；谐波图提供额外人工核查材料。KB24 保留历史结果但不纳入本分析。

基准代码：`c145c3cdfe265a50fa92e79f4694fbd8acf516fa`；源数据：[Actions 43831825178](https://github.com/collab-wq/Paper1/actions/runs/43831825178) 的四套目标约束代表运行 Artifact。分析样本为 CWRU 105/BPFI、Paderborn KA04/BPFO、Ottawa I-A-2/BPFI、XJTU Bearing1_2 快照 1 与 123/BPFO；这些是五个预先指定的片段，不代表全数据集统计。

## 实际数学定义

从融合功率谱的 $[(1-r)f_0,(1+r)f_0]$（Ottawa 为阶次 $O_0$）内取最大谱峰。背景功率中位数使用恒速 50–200 Hz、Ottawa 0.5–12 阶，并排除该目标窗口。$C=P_{\mathrm{peak}}/(\operatorname{median}P_{\mathrm{background}}+\epsilon)$，$e=|f_{\mathrm{peak}}-f_0|$，$Q_e=\exp[-(e/\Delta)^2/2]$，$Q_C=0$（$C\le1$），否则 $Q_C=\min(1,\ln C/\ln C_{\mathrm{sat}})$，$J=Q_eQ_C$。只有 $C>1$、$e\le\Delta$ 且 J 为有限正数的候选参与排序；同分取较小 R，否则 `NO_VALID_R`。恒速 $\Delta=f_s/N$；Ottawa $\Delta=1/\Delta N_{\mathrm{rev}}$。

测试 $C_{\mathrm{sat}}\in\{5,8,10,12,15,20\}$ 与 $r\in\{5\%,10\%,15\%,20\%,25\%,30\%\}$。固定背景辅助对照始终排除目标 ±30%，仅改变寻峰范围；正式定义仍为背景随搜索窗口变化。所有表中的 `contrast_linear` 是线性功率比。

## 基准复现

脚本在写入结果前对每个样本、每个 R 的理论值、峰位、原始及融合对比度、误差、Qe、Qc、J、有效性、失败原因和最终 R 与存档 `candidates.csv`/`result.json` 比较；差异超出 CSV 浮点写出容差时立即失败。

| 样本 | 目标 | 理论值 | 物理分辨率 | 基准最优 R |
|---|---|---:|---:|---|
| cwru-105 | BPFI | 162.185240 Hz | 5.859375 Hz | 3 |
| paderborn-ka04 | BPFO | 76.347049 Hz | 15.625000 Hz | 2 |
| ottawa-i-a-2 | BPFI | 5.430000 order | 0.231976 order | 3 |
| xjtu-bearing1_2-1 | BPFO | 107.907381 Hz | 6.250000 Hz | NO_VALID_R |
| xjtu-bearing1_2-123 | BPFO | 107.907381 Hz | 6.250000 Hz | 3 |

## 单因素与联合结果

| 样本 | Csat 5–20：基准 R 改变 | 窗口 ±5–30%：基准 R 改变 | 36 格：基准 R 改变 | 36 格 NO_VALID_R 数 | 固定背景 36 格改变 |
|---|---:|---:|---:|---:|---:|
| cwru-105 | 0/6 | 0/6 | 2/36 | 0/36 | 6/36 |
| paderborn-ka04 | 0/6 | 0/6 | 0/36 | 0/36 | 0/36 |
| ottawa-i-a-2 | 2/6 | 2/6 | 14/36 | 0/36 | 12/36 |
| xjtu-bearing1_2-1 | 0/6 | 1/6 | 6/36 | 30/36 | 6/36 |
| xjtu-bearing1_2-123 | 0/6 | 0/6 | 0/36 | 0/36 | 0/36 |

正式背景规则在各配置下的选择次数（每个样本一个选择，共 180 次）：

| 选择 | 次数 |
|---|---:|
| 2 | 56 |
| 3 | 92 |
| 4 | 2 |
| NO_VALID_R | 30 |

窗口改变时，目标峰与对比度可能同时改变，因为背景排除范围也变；`TARGET_WINDOW_SENSITIVITY.csv` 并列保存正式动态背景和固定 ±30% 背景。联合表同样保留两种背景规则。固定背景只用于机制对照，不参与正式算法修订。

## 早期 XJTU 的 NO_VALID_R

- ±5%：R=2: peak 108.203 Hz, e 0.296 Hz, C 3.84, VALID, R=3: peak 102.734 Hz, e 5.173 Hz, C 1.99, VALID, R=4: peak 102.734 Hz, e 5.173 Hz, C 4.95, VALID。
- ±10%：R=2: peak 97.266 Hz, e 10.642 Hz, C 11.52, ERROR_EXCEEDS_PHYSICAL_RESOLUTION, R=3: peak 97.266 Hz, e 10.642 Hz, C 12.98, ERROR_EXCEEDS_PHYSICAL_RESOLUTION, R=4: peak 97.266 Hz, e 10.642 Hz, C 16.57, ERROR_EXCEEDS_PHYSICAL_RESOLUTION。
- ±15%：R=2: peak 95.703 Hz, e 12.204 Hz, C 13.76, ERROR_EXCEEDS_PHYSICAL_RESOLUTION, R=3: peak 95.703 Hz, e 12.204 Hz, C 18.05, ERROR_EXCEEDS_PHYSICAL_RESOLUTION, R=4: peak 96.484 Hz, e 11.423 Hz, C 18.35, ERROR_EXCEEDS_PHYSICAL_RESOLUTION。
- ±20%：R=2: peak 95.703 Hz, e 12.204 Hz, C 16.22, ERROR_EXCEEDS_PHYSICAL_RESOLUTION, R=3: peak 95.703 Hz, e 12.204 Hz, C 19.08, ERROR_EXCEEDS_PHYSICAL_RESOLUTION, R=4: peak 96.484 Hz, e 11.423 Hz, C 20.32, ERROR_EXCEEDS_PHYSICAL_RESOLUTION。
- ±25%：R=2: peak 95.703 Hz, e 12.204 Hz, C 20.30, ERROR_EXCEEDS_PHYSICAL_RESOLUTION, R=3: peak 95.703 Hz, e 12.204 Hz, C 23.97, ERROR_EXCEEDS_PHYSICAL_RESOLUTION, R=4: peak 96.484 Hz, e 11.423 Hz, C 21.24, ERROR_EXCEEDS_PHYSICAL_RESOLUTION。
- ±30%：R=2: peak 95.703 Hz, e 12.204 Hz, C 20.30, ERROR_EXCEEDS_PHYSICAL_RESOLUTION, R=3: peak 95.703 Hz, e 12.204 Hz, C 20.55, ERROR_EXCEEDS_PHYSICAL_RESOLUTION, R=4: peak 96.484 Hz, e 11.423 Hz, C 18.25, ERROR_EXCEEDS_PHYSICAL_RESOLUTION。

若宽窗口中高对比度峰仍落在物理分辨尺度之外，应解释为本片段在目标附近缺少足够准确的周期证据；若窄窗口出现有效候选，需进一步检查它是局部次峰还是物理一致的多谐波结构。此结论只针对该代表性早期窗口。

## 多谐波理论位置与图件

每个样本各有一张 R=2、3、4 三面板图，原始与融合谱同时呈现；1×、2×、3× 理论位置在看谱峰前由存档物理目标值直接计算。图上的蓝点只标示基准 J 使用的实际基频峰。图片用于人工判断谐波联合表现，不引入多谐波 J。

- [cwru-105 三谐波谱](figures/sensitivity/cwru-105-three-harmonics.png)（[PDF](figures/sensitivity/cwru-105-three-harmonics.pdf)）；[R 选择热图](figures/sensitivity/cwru-105-selection-heatmap.png)（[PDF](figures/sensitivity/cwru-105-selection-heatmap.pdf)）。
- [paderborn-ka04 三谐波谱](figures/sensitivity/paderborn-ka04-three-harmonics.png)（[PDF](figures/sensitivity/paderborn-ka04-three-harmonics.pdf)）；[R 选择热图](figures/sensitivity/paderborn-ka04-selection-heatmap.png)（[PDF](figures/sensitivity/paderborn-ka04-selection-heatmap.pdf)）。
- [ottawa-i-a-2 三谐波谱](figures/sensitivity/ottawa-i-a-2-three-harmonics.png)（[PDF](figures/sensitivity/ottawa-i-a-2-three-harmonics.pdf)）；[R 选择热图](figures/sensitivity/ottawa-i-a-2-selection-heatmap.png)（[PDF](figures/sensitivity/ottawa-i-a-2-selection-heatmap.pdf)）。
- [xjtu-bearing1_2-1 三谐波谱](figures/sensitivity/xjtu-bearing1_2-1-three-harmonics.png)（[PDF](figures/sensitivity/xjtu-bearing1_2-1-three-harmonics.pdf)）；[R 选择热图](figures/sensitivity/xjtu-bearing1_2-1-selection-heatmap.png)（[PDF](figures/sensitivity/xjtu-bearing1_2-1-selection-heatmap.pdf)）。
- [xjtu-bearing1_2-123 三谐波谱](figures/sensitivity/xjtu-bearing1_2-123-three-harmonics.png)（[PDF](figures/sensitivity/xjtu-bearing1_2-123-three-harmonics.pdf)）；[R 选择热图](figures/sensitivity/xjtu-bearing1_2-123-selection-heatmap.png)（[PDF](figures/sensitivity/xjtu-bearing1_2-123-selection-heatmap.pdf)）。

## 数据与限制

`J_SATURATION_SENSITIVITY.csv` 为固定 ±20% 搜索、动态背景的逐 R 结果；`TARGET_WINDOW_SENSITIVITY.csv` 为固定 Csat=10 的逐 R 结果；`JOINT_SENSITIVITY.csv` 为 6×6×两种背景的逐 R 结果。每行含实际峰、原始峰、理论目标、误差、物理分辨率、对比度、Qe、Qc、J、有效性、原因和最终 R。谱来自目标约束分支的已运行 MATLAB 产物，CSV 写出可能带来微小浮点差异。五个片段不能代表全量稳健性；本次没有重新检验 WVD 图或核心算法，也不根据36格挑选更高分设置。
