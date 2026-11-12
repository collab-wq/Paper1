# Paper1 已执行实验与结果

> 此文件保留前期运行记录；最终一致性核查和统一结论以 `AUDIT_REPORT.md`、`AUDIT_RESULTS.csv`、`FINAL_RESULTS.md` 为准。

## 云端 MATLAB 环境

GitHub Actions 在 Ubuntu 24.04 上通过 MathWorks 官方 `setup-matlab@v3` 安装 MATLAB R2026b Update 1（26.2.0.3433840）和 Signal Processing Toolbox；`run-command@v3` 执行了最小测试。`hilbert`、`wvd` 路径均可解析，256 点双频实信号得到 256×512 WVD，所有值有限。测试日志、JSON 与 MAT 结果在 [首次环境验证运行及 Artifact](https://github.com/collab-wq/Paper1/actions/runs/42977349694) 中。

最终三类真实故障记录、外圈故障三段重复实验及合成信号的运行：[GitHub Actions 42980685605](https://github.com/collab-wq/Paper1/actions/runs/42980685605)，Artifact `matlab-results`（ID `13837352754`）包含每项实验的 `experiment.log`、`result.json` 和 `paper_figure.png`，以及 MATLAB 环境测试、四份 MAT 文件校验结果。运行分支为 `work`。

## CWRU 原始数据核对

四份文件均从 [CWRU 官方数据中心](https://engineering.case.edu/bearingdatacenter/download-data-file) 链接下载，`scripts/download_cwru.sh` 校验以下 SHA-256。工况来自官方 [正常数据表](https://engineering.case.edu/bearingdatacenter/normal-baseline-data) 与 [12 kHz 驱动端故障表](https://engineering.case.edu/bearingdatacenter/12k-drive-end-bearing-fault-data)；驱动端 SKF 6205-2RS JEM 的故障频率系数取自 [官方轴承参数页](https://engineering.case.edu/bearingdatacenter/bearing-information)。

| 文件 | 工况 / 0 HP | DE 变量 | 样本数 | MAT 中 RPM | 采样率 | SHA-256 |
| --- | --- | --- | ---: | ---: | ---: | --- |
| `97.mat` | 正常 | `X097_DE_time` | 243938 | 1796 | 正常基线按 48 kHz 记录 | `16bf48babcf1c7ac224bc1a81cd9eafdb27e42d5cf559761907e067e8eeadf3c` |
| `105.mat` | 内圈 0.007 in | `X105_DE_time` | 121265 | 1797 | 12 kHz | `f80b0ea04fd06b372a0eaec7c056543ea37e4bb4727a5b173d2a5bacd2aa9cab` |
| `118.mat` | 滚动体 0.007 in | `X118_DE_time` | 122571 | 1796 | 12 kHz | `b00628f8dd8d1d930af77fa465d1e5cdb385fe259489053f91f3680bda7f640e` |
| `130.mat` | 外圈 0.007 in、6 点位置 | `X130_DE_time` | 121991 | 1796 | 12 kHz | `35a095307d0971477049b343a1b5981dde465a58fb7f233ad89b035068c1717d` |

MAT 文件包含振动通道和转速，不包含采样率字段。故障三文件来自官方明确标为 12 kHz 的表；`97.mat` 位于独立的正常基线表，不能将其标成该 12 kHz 故障表中的文件。正常文件已完成格式与工况核对，本轮论文定量故障证据使用同为 12 kHz 的故障记录。

## 合成信号

输入设置：`fs=4000 Hz`，五次冲击位于 20、70、120、170、220 ms，激发 650 Hz 与 980 Hz 的指数衰减共振，`beta=110 s^-1`，加性高斯噪声系数 0.04，随机种子 7。检测器只读取混合信号的原始 WVD；各原子 WVD 仅用于完成掩膜后的评价。

| 检测与融合 | 自项保持率 | 同模态跨冲击交叉项去除率 | 跨模态交叉项去除率 | NMSE |
| --- | ---: | ---: | ---: | ---: |
| 频率方向三点检测（原型） | 55.3% | 63.7% | 98.0% | 1.5528 |
| 时间方向三点检测（原型） | 68.7% | 71.4% | 98.4% | 1.1946 |
| 双方向二值交集 | 45.9% | 87.2% | 99.3% | 0.9227 |
| 双方向几何平均融合（本文） | **54.3%** | 80.1% | 98.9% | 1.0715 |

前三行由最新原型在云端 MATLAB 实际复现；第四行由 `main_Paper1.m` 实际运行。融合阈值为 $\sqrt{0.10\times0.08}=0.08944$。相对二值交集，自项保持率增加 8.4 个百分点；其对应的跨冲击交叉项去除率和 NMSE 见表。WVD 自身检出的候选冲击时刻为 21.00、71.00、122.62、171.00、221.00 ms。合成实验图见 [figures/synthetic.png](figures/synthetic.png)。

## CWRU 实测信号

三个故障文件均使用 DE 通道开头连续 2048 个原始样本（每段 0.17067 s），采样率 12 kHz；直接计算原始 WVD，所得网格为 2048×4096。两个候选共振带由每段原始 WVD 的时间均值自动选出。官方驱动端轴承故障系数分别为 BPFI `5.4152`、BSF `4.7135`、BPFO `3.5848` 倍轴频；理论频率使用 MAT 内 RPM/60 计算。周期性谱峰取理论频率 ±20% 内的最大值；对比度是该峰功率与 50–200 Hz 非目标背景谱功率中位数之比。

| 文件 | 理论故障频率 | 原始 WVD 活动谱峰 / 对比度 | 融合 WVD 活动谱峰 / 对比度 | 自动选出的两带（Hz） |
| --- | ---: | ---: | ---: | --- |
| `105.mat` 内圈 | BPFI 162.19 Hz | 162.23 Hz / 12.57 | 161.50 Hz / 13.78 | 2580.3–2930.3；3427.3–3777.3 |
| `118.mat` 滚动体 | BSF 141.09 Hz | 138.06 Hz / 4.89 | 113.16 Hz / 6.02 | 1794.7–2144.7；3172.3–3522.3 |
| `130.mat` 外圈 | BPFO 107.31 Hz | 107.67 Hz / 64.57 | 107.67 Hz / 66.84 | 2603.7–2953.7；3236.8–3586.8 |

`130.mat` 给出本论文最清楚的单一应用：外圈 6 点位置故障冲击节律识别。理论 BPFO 周期为 9.32 ms。除首段外，又以完全相同的参数分析起始样本 4097、8193 的两个不重叠 2048 点片段：

| 起始样本 | 候选冲击数 | 相邻候选中位间隔 | 原始谱峰 / 对比度 | 融合谱峰 / 对比度 |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 17 | 约 9.31 ms | 107.67 Hz / 64.57 | 107.67 Hz / 66.84 |
| 4097 | 17 | 约 9.31 ms | 107.67 Hz / 61.30 | 107.30 Hz / 53.47 |
| 8193 | 19 | 约 9.30 ms | 107.30 Hz / 60.25 | 107.30 Hz / 97.38 |

三个片段的候选间隔与 107.31 Hz 理论 BPFO 一致，融合活动谱峰距理论值不超过 0.36 Hz。第一、二段各有一处约 18.5 ms 的候选漏检间隔；第三段的连续候选间隔均约 9.2–9.4 ms。融合保留两个共振带的周期结构；谱峰背景对比在第一、三段提高，在第二段下降。外圈主结果图见 [figures/cwru-130.png](figures/cwru-130.png)，其余两段的图与 JSON 均在 Artifact。`118.mat` 融合谱峰落在目标搜索窗下缘，不用于论文主结论。

图中的 `Original WVD`、两个检测图、融合分数与输出 WVD来自同一原始信号。合成图的自项真值只用于展示和指标评价。实验未使用外部方法 baseline、输入信号带通或模态分解。

第二阶段 Paderborn 与 XJTU-SY 的实际运行、逐段结果和数据质量说明见 [REAL_DATA_RESULTS.md](REAL_DATA_RESULTS.md)。
