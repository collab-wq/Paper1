# Paper1 算法流程与复现

## 执行入口

GitHub Actions 工作流 `.github/workflows/matlab.yml` 使用 `matlab-actions/setup-matlab@v3` 安装 MATLAB 与 Signal Processing Toolbox，以 `matlab-actions/run-command@v3` 执行测试及实验。`scripts/download_cwru.sh` 从 CWRU 官方站点下载首批四份原始 MAT 文件，逐一校验 SHA-256；`matlab/validate_cwru.m` 检查变量、样本数、DE 通道及 MAT 内记录的转速。原始数据置于 `input/cwru/`，不提交到 Paper1 仓库。日志、JSON 指标及 PNG 图保存为 Actions Artifact。

MATLAB 主入口：

```matlab
main_Paper1('synthetic')
main_Paper1('cwru','input/cwru/130.mat')
main_Paper1('cwru','input/cwru/130.mat',4097)
main_Paper1('cwru','input/cwru/130.mat',8193)
main_Paper1('paderborn','input/paderborn/KA04/N15_M07_F10_KA04_1.mat',64001)
main_Paper1('xjtu','input/xjtu-sy/35Hz12kN/Bearing1_1/123.csv',4097)
```

## 离散步骤

1. 读取原始实信号 $x$。合成实验固定随机种子 7；CWRU 读取 DE 原始样本和 MAT 内 RPM。调用 `hilbert` 和 `wvd`，得到 $W[k,n]$、$f_k$、$t_n$。
2. 在 WVD 频率轴确定两带。合成实验固定为 540–770 Hz、865–1100 Hz；CWRU 实验在 1.5–4.5 kHz 区间对正 WVD 时间均值作 80 Hz 平滑，取间隔至少 600 Hz 的两个最强峰，各扩展 ±175 Hz。真值类别和理论故障频率不参与选带。
3. 以时间窗 $L$、步长 `hopSec` 扫描 WVD。每窗计算有符号加权均值、标准差、两带正支撑的一阶频率矩。只对靠近两个频率中心的频率端点成对计算式 (5)，将分数累积到两个端点。逐窗归一化并插值得到 $S_f$。
4. 用频率方向 Hann 核计算原始 WVD 的有符号均值及标准差。两带正支撑积分的活动曲线经 2 ms 移动均值后，通过峰距与相对显著度寻找时间端点。候选时间对的中点线性插值，依式 (8) 计算分数，同时累积到两个端点。
5. 将端点分数沿正时间方向按指数核扩展一个响应窗，分别在两个频带归一化为 $S_t$。计算几何平均 $S=\sqrt{S_f S_t}$，以 $\sqrt{0.10\cdot0.08}$ 阈值及低活动门控产生掩膜。输出 `Wout=W.*M`。
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

`.github/workflows/audit.yml` 固定下载前次已执行运行 `42999351528`、`42999351710`、`42999351656` 的 JSON 结果作为逐项数值参考；再次下载并校验三套原始数据，使用 `matlab/run_audit.m` 重跑固定片段与参数，调用 `scripts/audit_results.py` 输出 `AUDIT_RESULTS.csv`。35 段真实数据和一项合成信号均参与比较。脚本将旧 JSON 的每个字段与新 JSON 比对（相对容差 `1e-8`），并把新加的无标签周期峰、目标峰误差和 Paderborn 局部时间栅格另列供核查。核查结果与逐段日志、JSON、代表图保存在 `paper1-audit` Actions Artifact。

真实数据参数分别在 `main_Paper1.m` 对应模式中定义；Paderborn、XJTU-SY 的分段长度、时间窗和自动选带范围另见 `REAL_DATA_RESULTS.md`。理论故障频率只在完成检测和重构后用于评价；正常记录的目标频率窗口也仅作为事后响应对照。最终核查与物理分辨率解释见 `AUDIT_REPORT.md`，统一实验结论见 `FINAL_RESULTS.md`。
