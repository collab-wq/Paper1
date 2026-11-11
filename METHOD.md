# Paper1 数学模型：原始 WVD 的双方向中点三点检测

## 1. 信号与时频表示

设实值振动序列为 (x[n])，采样率为 (f_s)，(n=0,ldots,N-1)。其解析信号及 Wigner–Ville 分布（WVD）定义为

\[
z[n]=x[n]+\mathrm j\mathcal H\{x[n]\}, \tag{1}
\]

\[
W_z(t,f)=\int z(t+\tau/2)z^*(t-\tau/2)
             e^{-\mathrm j2\pi f\tau}\,\mathrm d\tau . \tag{2}
\]

离散实验由 MATLAB `wvd(hilbert(x),fs)` 给出矩阵 (W[k,n])、单调递增的频率网格 (f_k) 和时间网格 (t_n)。(k) 是频率索引，(n) 是 MATLAB 返回的 WVD 时间索引；程序以返回的网格计算 \(\Delta f\) 和 \(\Delta t\)，不将输入样本索引误当成 WVD 时间索引。检测器对原始 WVD 操作，最终输出仍取原始 WVD 像素。输入信号不作带通、模态分解或其他预处理。

## 2. 频率方向三点检测

在以 \(t_q\) 为中心、长度 \(L\) 的时间窗内，令非负 Hann 权重 \(g_{q,n}\) 的和为 1。定义有符号均值和波动量

\[
\bar W_t(k,q)=\sum_{n\in I_q}g_{q,n}W[k,n],\quad
\sigma_t(k,q)=\sqrt{\max\{\sum_{n\in I_q}g_{q,n}W[k,n]^2-
\bar W_t(k,q)^2,0\}} . \tag{3}
\]

沿时间振荡的交叉项先在 \(\bar W_t\) 中正负抵消；此后才构造正支撑 \(P_t(k,q)=\max(\bar W_t(k,q),0)\)。对于 WVD 频率轴上预设或数据驱动的两个候选带 \(B_1,B_2\)，各带一阶频率中心为

\[
\mu_r(q)=\frac{\sum_{k:f_k\in B_r} f_k P_t(k,q)}
                 {\sum_{k:f_k\in B_r}P_t(k,q)},\quad r=1,2 . \tag{4}
\]

在两个频带内选取分别靠近 \(\mu_1,\mu_2\) 的端点 \(i,j\)，且 \(|f_i-f_j|>d_f\)。中点频率 \(f_m=(f_i+f_j)/2\) 的均值与标准差由相邻频率格点线性插值。令 \(G_i=\exp[-(f_i-\mu_1)^2/(2s_f^2)]\)，\(G_j\) 同理，则三点耦合分数为

\[
C_f(i,j;q)=G_iG_jP_t(i,q)P_t(j,q)
\frac{\sigma_t(m,q)^2}{\sigma_t(m,q)+|\bar W_t(m,q)|+\epsilon_f} . \tag{5}
\]

中点的高波动与低有符号均值指示振荡交叉项的位置；该位置只参与检测，不复制到重构结果。式 (5) 的 \(\epsilon_f=0.01\max_k\sigma_t(k,q)+\epsilon_{\rm mach}\)，用于避免零分母。\(d_f\) 为端点最小频率间隔，\(s_f\) 为端点高斯权重尺度。将每个分数同时累积给两个端点：

\[
A_f(k,q)=\sum_{(i,j)}C_f(i,j;q)
          (\mathbf1_{k=i}+\mathbf1_{k=j}). \tag{6}
\]

各时间窗按本窗最大值归一化，再沿时间线性插值到 \(t_n\)，得到 \(S_f[k,n]\in[0,1]\)。两带正支撑能量几何平均形成活动量 \(E[n]\)，仅作为接近噪声底的门控。

## 3. 时间方向三点检测

以非负、单位和的频率 Hann 核 \(h[u]\) 在原始 WVD 上计算有符号频率均值和波动量：

\[
\bar W_f(k,n)=\sum_u h[u]W[k+u,n],\quad
\sigma_f(k,n)=\sqrt{\max\{\sum_u h[u]W[k+u,n]^2-
\bar W_f(k,n)^2,0\}} . \tag{7}
\]

频率振荡的跨冲击交叉项先在 \(\bar W_f\) 中抵消。随后令 \(P_f=\max(\bar W_f,0)\)，对两个候选频带内的 \(P_f\) 积分形成 WVD 活动曲线，并按最小峰距与峰显著度找时间端点候选 \(t_i\)。候选来自实测 WVD，不输入合成冲击的真值时刻或真实故障频率。对符合时间间隔范围的候选对 \((i,j)\)，定义 \(t_m=(t_i+t_j)/2\)，中点统计量以时间格点线性插值；固定频率 \(f_k\) 的三点分数为

\[
C_t(i,j;k)=P_f(k,i)P_f(k,j)
\frac{\sigma_f(k,m)^2}{\sigma_f(k,m)+|\bar W_f(k,m)|+\epsilon_t}. \tag{8}
\]

两个端点都得到分数。为覆盖冲击后的衰减共振，自端点向后传播 \(0\leq t_n-t_i\leq L\) 的指数核 \(e^{-(t_n-t_i)/(L/3)}\)，得到 \(A_t[k,n]\)；每个候选频带按全带最大值归一化，得到 \(S_t[k,n]\in[0,1]\)。此传播只作用于检测分数，不平滑输出 WVD。

式 (8) 的 \(\epsilon_t=0.02\max_{k,n}\sigma_f(k,n)+\epsilon_{\rm mach}\)。时间端点最大允许间隔为 `maxPairDelaySec`，最小允许间隔与候选峰最小峰距相同。

## 4. 融合与重构

两图的连续融合与最终掩膜为

\[
S[k,n]=\sqrt{S_f[k,n]S_t[k,n]},\qquad
M[k,n]=\mathbf1\{S[k,n]>\sqrt{\theta_f\theta_t}\}
       \mathbf1\{E[n]>\theta_E\}, \tag{9}
\]

\[
W_{\mathrm{out}}[k,n]=M[k,n]W[k,n]. \tag{10}
\]

\(\theta_f=0.10\)、\(\theta_t=0.08\) 沿用原型单方向阈值；融合阈值取二者几何平均。相较二值交集，强方向证据可补偿另一方向稍弱的像素证据。算法核心仍是频率和时间两组端点—中点—端点的三点检测及累积。

## 5. 方法定位

Gaikwad 与 Sircar（2018，DOI: 10.1007/s11760-017-1211-7）提出利用修改三谱的中点关系与累积抑制二次时频表示的交叉项。本方法借鉴中点几何关系和向自项端点累积的思路，改为原始 WVD 上的双方向有符号局部统计及波动对比。式 (5)、(8) 是非负的三点检测统计量，不是经典统计双谱或三谱估计；“双方向中点三点耦合/累积检测”准确描述其实现。
