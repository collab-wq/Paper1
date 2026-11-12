# Paper1 第二阶段：真实轴承数据执行记录

> 此文件保留第二阶段运行记录；KA04 局部时间栅格核查和最终实验结论以 `AUDIT_REPORT.md`、`AUDIT_RESULTS.csv`、`FINAL_RESULTS.md` 为准。

## 共用处理

两个新数据集都把原始振动片段直接送入 `hilbert` 和 `wvd`。频率与时间方向三点检测、端点累积及几何平均融合保持 `METHOD.md` 中的公式。每段在计算出的原始 WVD 平均谱中自动选择两条候选共振带；故障类别与理论频率只在输出后核对。每项实验的 PNG 包含原始 WVD、频率检测、时间检测、融合检测、重构 WVD 及周期谱；MAT、JSON、CSV 和执行日志保存于 Actions Artifact。为限制 Artifact 体积，MAT 时频数组在计算完成后沿两个网格方向每 4 格保存 1 格，图和指标来自完整网格。

| 参数 | Paderborn | XJTU-SY |
| --- | ---: | ---: |
| 原始采样率 | 64 kHz | 25.6 kHz |
| 分段长度 | 4096 点，64 ms | 4096 点，160 ms |
| 无标签候选共振范围 | 2–25 kHz | 1.2–10 kHz |
| 候选带半宽 / 最小带距 | 450 / 1800 Hz | 250 / 1000 Hz |
| 局部时间窗 / 步长 | 4 / 1 ms | 7 / 1.5 ms |
| 最大候选时间对间隔 | 60 ms | 120 ms |

## Paderborn 官方数据

[官方数据页](https://mb.uni-paderborn.de/en/kat/research/bearing-datacenter/data-sets-and-download)与[原始研究的损伤表](https://mb.uni-paderborn.de/fileadmin-mb/kat/PDF/Veroeffentlichungen/20160703_PHME16_CM_bearing.pdf)确认 K001 健康、KA04 加速寿命试验形成的外圈单点疲劳点蚀、KI04 内圈多点疲劳点蚀。`N15_M07_F10` 的标称工况为 1500 rpm、0.7 Nm、1000 N。MATLAB 实际读取 `Y.Name=vibration_1` 的轴承座振动和 `speed`、`force`、`torque` 通道；各压缩包的官方测量日志指定振动 64 kHz、机械量 4 kHz。三份官方 RAR 的 SHA-256 固定于 `scripts/download_paderborn.sh`。6203 的名义几何值为 8 球、球径 6.75 mm、节圆直径 28.55 mm、接触角 0°；结合 MAT 实测转速，BPFO 约 76.34 Hz、BPFI 约 123.62 Hz。原研究指出不同制造商的特征频率可能相差 1–2%。

[18 段 MATLAB 成功运行及 Artifact](https://github.com/collab-wq/Paper1/actions/runs/42999351710)：每轴承三条独立 MAT 记录，每条取起始样本 64001、128001 两段。零填充周期图插值峰位置，物理分辨率仍受 64 ms 窗长限制。

| 轴承 | 标签 | 六段融合目标峰（Hz） | 融合对比度中位数 | 解释 |
| --- | --- | --- | ---: | --- |
| K001 | 健康 | BPFO 窗：90.82、75.20、73.24、61.52、82.03、73.24 | 2.73 | 个别健康片段也有目标窗峰，不能只用峰位置诊断 |
| KA04 | 外圈真实点蚀 | BPFO 窗：73.24、76.17、76.17、77.15、77.15、75.20 | 9.85 | 六段接近理论值；单段对比度仍与健康最大值重叠 |
| KI04 | 内圈真实点蚀 | BPFI 窗：122.07、120.12、103.52、99.61、123.05、124.02 | 4.73 | 四段接近理论值，两段偏离 |

KA04 第 2 条 MAT 的振动时间栅格为 262062 点、约 4 秒，按首尾推算 65.515 kHz，偏离官方 64 kHz；第 3 条为 257144 点、推算 64.286 kHz。程序记录警告并按官方采样率分析连续原始样本。第 2 条的绝对频率须谨慎解释；仅采用第 1、3 条的四段仍得到 73.24、76.17、77.15、75.20 Hz 的 BPFO 窗峰。MAT 中实测轴速约 1499.6–1500.0 rpm，实测轴扭矩约 1.24–1.28 Nm，不应与工况名称中的标称 0.7 Nm 混同。

## XJTU-SY 同一轴承寿命阶段

[作者入口](https://github.com/WangBiaoXJTU/xjtu-sy-bearing-datasets)提供交互式网盘。云端通过[公开 ZIP 镜像](https://huggingface.co/datasets/DavidNguyen/XJTU-SY_Bearing_Datasets)的 HTTP Range 仅获取 6 份原始 CSV，逐一验证 ZIP CRC、固定 SHA-256、两列通道名和每列 32768 点；[数据验证运行](https://github.com/collab-wq/Paper1/actions/runs/42997010913)留有来源日志。Bearing1_1 的已报道最终损伤为外圈；工况标称 2100 rpm、12 kN，CSV 没有实测转速。LDK UER204 名义几何值为 8 球、球径 7.92 mm、节圆直径 34.55 mm、接触角 0°，对应 BPFO 107.91 Hz。

[12 段 MATLAB 成功运行及 Artifact](https://github.com/collab-wq/Paper1/actions/runs/42999351656)：早期快照 1/2，中期 69/82，后期 109/123；每条取起始样本 4097、16385 两段。阶段仅表示记录先后，没有独立损伤测量支持将最早快照直接标作健康或将某一时点定为严重故障。

| 寿命阶段 | 四段融合 BPFO 窗峰（Hz） | 融合对比度中位数 | 原始 WVD 对比度中位数 |
| --- | --- | ---: | ---: |
| 早期 1/2 | 110.55、99.22、86.33、104.30 | 9.35 | 6.87 |
| 中期 69/82 | 107.42、107.42、109.77、108.98 | 26.14 | 6.28 |
| 后期 109/123 | 108.98、108.59、107.81、108.20 | 218.98 | 24.87 |

中、后期八段的融合峰接近理论 BPFO；最早四段的峰位置不稳定。后期四段融合对比度分别为 97.31、336.15、263.71、174.24，高于中期四段的 4.06–32.71。趋势支持故障发展后周期结构的稳定保留，早期诊断仍有限制。

**Paper1 主案例建议：KA04 外圈真实疲劳点蚀。** 它有官方原始数据、同工况健康对照和三记录重复验证。XJTU-SY Bearing1_1 展示随寿命发展的增强趋势，适合作为第二数据集验证；KI04 的结果应如实报告为部分片段未稳定检出。

已执行结果的代表图：[Paderborn KA04](figures/paderborn-ka04.png)、[XJTU-SY Bearing1_1 后期](figures/xjtu-bearing1_1-late.png)。其余每段图、MAT、JSON 和日志在对应 Actions Artifact。
