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

原始数据由 `scripts/` 下的下载程序按需取得，不提交仓库。正式自检见 [GitHub Actions](.github/workflows/adaptive-self-check.yml)，未来真实数据验证只由[手动工作流](.github/workflows/future-real-validation.yml)触发。本次集成尚无新自适应真实数据实验，历史固定 R 的实验不被重新命名为自适应结果。

## 文档与历史资料

- [METHOD.md](METHOD.md)：数学模型、饱和型评分和有效性规则。
- [ALGORITHM.md](ALGORITHM.md)：离散流程、接口与复现。
- [RESULTS.md](RESULTS.md)：原方法与固定 R 实验的详细历史记录。
- [FINAL_RESULTS.md](FINAL_RESULTS.md)：现阶段方法决定与已有证据边界。
- [AUDIT_REPORT.md](AUDIT_REPORT.md)：历史一致性核查及新方法自检状态。
- [MULTIBAND_RESULTS.csv](MULTIBAND_RESULTS.csv)：绝对值支撑下固定 R 的逐段真实数据结果。
- [archive/previous-algorithm/AUDIT_RESULTS.csv](archive/previous-algorithm/AUDIT_RESULTS.csv)：原算法逐段核查表。
- [archive/initial-prototype/](archive/initial-prototype/)：最初 `main` 原型代码、任务书、参考论文和图片，内容未改。
- [AGENTS.md](AGENTS.md)：项目执行与成果管理规范。

`figures/` 保存历史 MATLAB 实验论文图（PNG/PDF）；新的自适应方案仅在未来实际运行后才生成相应实验图。`work` 与 `experiment/absolute-support-multiband` 分支继续保存方法演进记录。

## 全量真实数据实验分支

`experiment/full-real-bearing-validation` 从正式 `main` 派生。新增四套数据的下载、元信息核查、分片批处理和 Ottawa 编码器阶次评价；完整工作流见 `.github/workflows/full-real-bearing-validation.yml`。实验结果在该分支核查，不自动合并回 `main`。历史固定 R 结果与本轮自适应真实数据结果分开解释。
