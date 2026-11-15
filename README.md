# Paper1：原始 WVD 双方向三点检测与自适应共振带

本仓库研究原始振动信号 Wigner–Ville 分布中的交叉项抑制。正式方法先对局部**有符号均值**取绝对值作支撑，沿频率与时间分别执行端点—中点—端点检测，按几何平均融合掩膜重构 WVD。真实记录默认在嵌套的 $R=2,3,4$ 个共振带中，以故障周期峰定位精度和饱和型对比度评分选择最佳候选；得分不满足有效条件时返回 `NO_VALID_R`。合成原型保持两条物理共振带。

## 入口

```matlab
addpath('matlab')
verify_adaptive_band_selection                    % 确定性自检
main_Paper1('cwru','input/cwru/130.mat',1)         % 默认自适应 R，未知故障假设
main_Paper1('cwru','input/cwru/130.mat',1,3)       % 手动固定 R=3
main_Paper1('cwru','input/cwru/130.mat',1,'auto','BPFO') % 明确待检假设
```

原始数据由 `scripts/` 下的下载程序按需取得，不提交仓库。正式自检见 [GitHub Actions](.github/workflows/adaptive-self-check.yml)；本分支的四套真实数据正式运行见[全量工作流](.github/workflows/full-real-bearing-validation.yml)和[审计发布工作流](.github/workflows/full-real-presentation.yml)。历史固定 R 的实验与本轮自适应实验分开解释。

## 文档与历史资料

- [METHOD.md](METHOD.md)：数学模型、饱和型评分和有效性规则。
- [ALGORITHM.md](ALGORITHM.md)：离散流程、接口与复现。
- [RESULTS.md](RESULTS.md)：历史实验与本分支四套真实数据的详细记录。
- [FINAL_RESULTS.md](FINAL_RESULTS.md)：历史结论与全量自适应验证总结。
- [AUDIT_REPORT.md](AUDIT_REPORT.md)：历史核查、全量来源与逐窗一致性核查。
- [REAL_DATA_FULL_RESULTS.csv](REAL_DATA_FULL_RESULTS.csv)：10,486 个真实窗口及九个候选的完整数值。
- [FULL_STATISTICS.csv](FULL_STATISTICS.csv)、[POSTHOC_TARGET_STATISTICS.csv](POSTHOC_TARGET_STATISTICS.csv)：分工况中位数、四分位数和事后真实目标证据。
- [DATASET_MANIFEST.csv](DATASET_MANIFEST.csv)、[SEGMENT_MANIFEST.csv](SEGMENT_MANIFEST.csv)：原始来源及实际 WVD 输入片段的 SHA 和位置。
- [MULTIBAND_RESULTS.csv](MULTIBAND_RESULTS.csv)：绝对值支撑下固定 R 的逐段真实数据结果。
- [archive/previous-algorithm/AUDIT_RESULTS.csv](archive/previous-algorithm/AUDIT_RESULTS.csv)：原算法逐段核查表。
- [archive/initial-prototype/](archive/initial-prototype/)：最初 `main` 原型代码、任务书、参考论文和图片，内容未改。
- [AGENTS.md](AGENTS.md)：项目执行与成果管理规范。

`figures/` 保存历史论文图；[figures/full-real/](figures/full-real/) 保存四张新八联代表图与十二张趋势图的 PNG/PDF。`work` 与 `experiment/absolute-support-multiband` 分支继续保存方法演进记录。

## 全量真实数据实验分支

`experiment/full-real-bearing-validation` 从正式 `main` 派生。固定提交 `c2144d2` 的[MATLAB 正式运行](https://github.com/collab-wq/Paper1/actions/runs/43720147268)完成 CWRU 36、Paderborn 36、Ottawa 366、XJTU-SY 10048 个窗口；[独立审计发布](https://github.com/collab-wq/Paper1/actions/runs/43746468737)核查 10,486/10,486 个结果及输入，失败 0，8,670 个有效选择、1,816 个 `NO_VALID_R`。全量逐段 Artifacts 与[汇总/图片 Artifact](https://github.com/collab-wq/Paper1/actions/runs/43746468737/artifacts/14174343297)保留 90 天。高选中 J 并不保证真实故障类型正确；Paderborn KA04 与 CWRU 的证据较稳，Ottawa 外圈和 XJTU 内圈的事后类型一致性有限。实验结果只保存在本分支，不自动合并回 `main`。
