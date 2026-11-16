# Paper1 算法流程与复现

## 执行入口

历史 GitHub Actions 工作流 `matlab.yml` 使用 `matlab-actions/setup-matlab@v3` 安装 MATLAB 与 Signal Processing Toolbox，以 `matlab-actions/run-command@v3` 执行测试及实验。`scripts/download_cwru.sh` 从 CWRU 官方站点下载首批四份原始 MAT 文件，逐一校验 SHA-256；`matlab/validate_cwru.m` 检查变量、样本数、DE 通道及 MAT 内记录的转速。原始数据置于 `input/cwru/`，不提交到 Paper1 仓库。日志、JSON 指标及 PNG 图保存为 Actions Artifact。

MATLAB 四类实验入口（均调用同一个 `main_Paper1.m`）：

```matlab
addpath('matlab')
run_synthetic_batch
run_cwru_batch
run_paderborn_batch
run_xjtu_batch
```

历史实验分支的 `main_Paper1(mode,dataFile,startIndex,numBands)` 接受 `numBands=2,3,4`，缺省为 2；四类历史入口也接受可选 `numBands`。合成信号只有两个已知物理共振带，只运行 R=2。历史分支工作流 `absolute-support-multiband.yml` 先运行 `verify_abs_support_multiband` 与合成回归，成功后才分别运行三套真实数据的 R=2、3、4。逐段失败记录于 `validation_status.csv`，不自动降级 R。

`run_audit` 顺序调用上述四个入口，并在 GitHub Actions 中与固定历史 Artifact 对比。数据完整性检查由 `validate_cwru` 等独立程序完成，不包含在批量入口内。

## 离散步骤

1. 读取原始实信号 $x$。合成实验固定随机种子 7；CWRU 读取 DE 原始样本和 MAT 内 RPM。调用 `hilbert` 和 `wvd`，得到 $W[k,n]$、$f_k$、$t_n$。
2. 在 WVD 频率轴确定 R 个带。合成实验仍固定为 540–770 Hz、865–1100 Hz；真实数据以 $Q(f_k)=\operatorname{mean}_n|W[k,n]|$ 作局部平滑，用原有搜索范围和峰间距找候选峰，按强度取前 R 个，最终按频率升序排列。CWRU 的范围为 1.5–4.5 kHz、平滑 80 Hz、最小峰间距 600 Hz、半宽 175 Hz；其他数据集保留各自既定参数。候选不足即报错。真值类别和理论故障频率不参与选带。
3. 以时间窗 $L$、步长 `hopSec` 扫描 WVD。每窗计算有符号加权均值及标准差，随后取均值的绝对值支撑，并对全部 R 带计算一阶频率矩与活动量。遍历 $\binom R2$ 个不同带对，分别计算式 (5)，将每个三点分数累积到两端点。记录逐窗有效带对数，逐窗归一化并插值得到 $S_f$。R 带活动量用几何平均归一化为 $E$。
4. 用频率方向 Hann 核计算原始 WVD 的有符号均值及标准差，再取均值的绝对值支撑。对全部 R 带积分形成活动曲线，经原有 2 ms 移动均值、峰距与相对显著度寻找时间端点。候选时间对的中点线性插值，依式 (8) 计算分数，同时累积到两个端点。
5. 将端点分数沿正时间方向按指数核扩展一个响应窗，分别在全部 R 带归一化为 $S_t$。计算几何平均 $S=\sqrt{S_f S_t}$，以 $\sqrt{0.10\cdot0.08}$ 阈值及低活动门控产生掩膜。输出 `Wout=W.*M`。
6. 合成实验在掩膜完成后，单独生成自项及两类交叉项真值，计算自项能量保持率、两类交叉项能量去除率及 NMSE。真实实验使用官方轴承故障频率系数和 MAT 转速计算理论频率，报告 WVD 活动序列在故障频率附近的周期性峰与背景对比。

## 参数与数据边界

| 参数 | 合成实验 | CWRU 真实实验 | 作用 |
| --- | ---: | ---: | --- |
| `Lsec` | 0.02727 s | 0.006 s | 局部响应窗及时间分数后向扩展范围 |
| `hopSec` | 0.005 s | 0.001 s | 频率检测窗的步长 |
| `spanHz` | 65 Hz | 110 Hz | 频率中心周围的端点候选半宽 |
| `sigmaHz` | 40 Hz | 80 Hz | 端点高斯权重尺度 |
| `excludeHz` | 60 Hz | 100 Hz | 频率端点最小分离 |
| `freqAvgHz` | 40 Hz | 200 Hz | 时间检测用有符号频率平均标称宽度 |
| `freqThr`, `timeThr` | 0.10, 0.08 | 0.10, 0.08 | 两方向原型阈值；融合阈值为几何平均 |
| `activityThr` | 0.005 | 0.005 | 归一化活动量门控 |
| `maxPairDelaySec` | 0.16 s | 0.08 s | 时间候选对最大间隔 |

首批数据工况：`97.mat` 正常 0 HP，`105.mat` 驱动端内圈 0.007 in 故障 0 HP，`118.mat` 滚动体 0.007 in 故障 0 HP，`130.mat` 驱动端外圈 0.007 in、6 点位置 0 HP。后三份在 CWRU 官方 **12k Drive End Bearing Fault Data** 表内。`97.mat` 来自独立 **Normal Baseline Data** 表，应按正常基线的 48 kHz 采样处理；MAT 文件本身没有采样率变量，不能把采样率“读取自 MAT”。

## 三套数据集的最终核查入口

历史工作流 `audit.yml` 固定下载前次已执行运行 `42999351528`、`42999351710`、`42999351656` 的 JSON 结果作为逐项数值参考；再次下载并校验三套原始数据，使用 `matlab/run_audit.m` 重跑固定片段与参数，调用 `scripts/audit_results.py` 输出当时的 `AUDIT_RESULTS.csv`（现已原样归档）。35 段真实数据和一项合成信号均参与比较。脚本将旧 JSON 的每个字段与新 JSON 比对（相对容差 `1e-8`），并把新加的无标签周期峰、目标峰误差和 Paderborn 局部时间栅格另列供核查。核查结果与逐段日志、JSON、代表图保存在 `paper1-audit` Actions Artifact。

真实数据参数分别在 `main_Paper1.m` 对应模式中定义；四类实验的片段、时间窗和自动选带范围详见 `RESULTS.md`。理论故障频率只在完成检测和重构后用于评价；正常记录的目标频率窗口也仅作为事后响应对照。最终核查与物理分辨率解释见 `AUDIT_REPORT.md`，统一实验结论见 `FINAL_RESULTS.md`。

## 正式主支：自适应选带流程

在本分支中，真实数据自动模式须显式调用 `main_Paper1(mode,dataFile,startIndex,'auto',targetHypothesis)`，其中 `targetHypothesis` 是实验元数据给出的 `BPFO` 或 `BPFI`；缺省、`unknown` 和 `BSF` 均被拒绝。第四参数取 `2`、`3`、`4` 的固定 R 历史入口仍保留。合成信号仅允许固定 $R=2$。本分支自检入口为 `addpath('matlab'); verify_target_informed_selection; verify_ottawa_order`。以下旧版遍历多假设的伪代码仅反映 `main` 和历史全量实验分支，本分支改为单一目标。

```matlab
% 实际代码分布于 main_Paper1、run_adaptive_candidates 等函数。
[W,f,tw] = wvd(hilbert(x),fs); % 每段仅一次
ranked = find_resonance_candidates(W,f,...); % 幅值峰强度降序
H = bearing_hypotheses(mode,rpm,targetHypothesis); % 单一目标
for R = 2:4
    if numel(ranked) < R
        % 记录 INSUFFICIENT_BANDS，不影响其他 R
        continue
    end
    bands = sort(ranked(1:R));
    % 对该 R 调用原双方向检测器；遍历所有 nchoosek(R,2) 个带对。
    % 原有掩膜、Wout、周期谱及 fault_evidence 均保持定义。
    % 仅依据 H(1) 的目标频率，使用 fs/N 和式 (12)–(13) 评分。
end
% 同一目标的三个有效候选按 J 降序；精确同分 R 升序。
```

本分支结果写入 `results/adaptive-band-selection/<dataset>/<segment>/target-<bpfo|bpfi>/result.json` 与 `candidates.csv`。每个 $R$ 包括频带、三点计数、目标峰、对比度、物理分辨尺度、误差、$Q_e$、$Q_C$、$J$、有效状态及原因；胜出方案另存八联图和抽样 MAT 网格。诊断活动量仍采用旧版正值 WVD 积分，区别于检测阶段的绝对值局部均值支撑。

当前仅自动运行 `.github/workflows/adaptive-self-check.yml` 的确定性 MATLAB 检查。`.github/workflows/future-real-validation.yml` 只允许手动触发，尚未执行新的自适应真实数据实验。上文提及的旧工作流及 `run_audit` 为历史复现说明，旧工作流已从正式主支清理，历史数值见 `MULTIBAND_RESULTS.csv` 和 `archive/previous-algorithm/AUDIT_RESULTS.csv`。

## 实验分支：四套真实数据全量验证（待最终核查）

`experiment/full-real-bearing-validation` 仅在分支内扩展数据读取、批处理与变转速评价，沿用 `main_Paper1.m` 的原始 WVD、绝对值支撑、双方向三点检测、R=2/3/4 候选、掩膜和饱和型评分。CWRU、Paderborn、XJTU-SY 仍以未知 BPFO/BPFI/BSF 假设分别评分；真实标签只在汇总时由文件名作事后核对。

Ottawa 原始 Channel_1 为 200 kHz 加速度振动，Channel_2 为编码器。对每个 65536 点原始窗口，统一用 `resample(...,2,25)` 抗混叠转换到 16 kHz 后计算 WVD。预检中六份信号的强谱峰均在约 4.8–5.1 kHz，低于 8 kHz 新奈奎斯特频率；原始与实际输入窗口均保存并分别计算 SHA-256。编码器在原始 200 kHz 下检上升沿，以 1024 脉冲/转恢复转数及局部 RPM。WVD 检测仍在时间域完成；只将原始和融合后的 WVD 频带活动曲线按轴转数插值到均匀角度网格，计算目标阶次谱峰与 0.5–12 阶、排除目标窗口后的背景中位数之比。物理阶次分辨尺度为窗口内累计转数的倒数，定位可信度、对比度饱和函数、有效性约束及同分规则与恒速算法同形。平均 RPM 不参与阶次定位。

四类入口为 `run_cwru_full_batch`、`run_paderborn_full_batch`、`run_ottawa_batch` 与 `run_xjtu_lifetime_batch`；它们仅组织原始文件及固定片段，均调用 `main_Paper1`。`full-real-bearing-validation.yml` 先执行 `verify_adaptive_band_selection` 与 `verify_ottawa_order`，再完成来源预检和单段试运行，最后拆分全量任务。每个实际 WVD 输入在 `results/input_segments/` 留存样本、来源、通道、采样率、窗口位置和 SHA-256；自动选择失败时也留存。大型输入和完整实验产物只上传 Actions Artifact。

## 目标约束实验分支

`experiment/target-informed-R-selection` 从全量验证分支建立。每个自动 R 调用只接收一个目标 BPFO 或 BPFI，分别计算三个 $R$ 的周期谱峰、对比度、$Q_e$、$Q_C$ 和 $J$；`select_optimal_band_count` 对混合故障假设直接报错。KB24 同一片段执行 BPFO、BPFI 两次，输出目录分别以 `target-bpfo`、`target-bpfi` 结尾。各目标只生成三条候选记录，并在 JSON、CSV 中保存 `target_fault_type`、`target_hypothesis` 和 `selected_R`。代表图同时绘制红色理论谐波线和蓝色实际定位峰。检测器、WVD、频带选择、掩膜及分辨率定义未改。

`.github/workflows/target-informed-self-check.yml` 先运行确定性 MATLAB 自检；通过后仅执行四套数据的代表片段。本分支不执行全部 10,486 段；旧分支结果与统计表保持历史原状。
