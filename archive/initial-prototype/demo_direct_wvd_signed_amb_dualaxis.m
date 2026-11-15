%% Direct-WVD, signed-time local AMB-like detector + frequency-signed comparison
% Research prototype, not a mathematically classical bispectrum estimator.
% Requires Signal Processing Toolbox: hilbert, wvd, hann.
% No modal decomposition, no bandpass filtering, no signal pre-processing
% beyond the analytic representation for computing the WVD.
%
% Core idea:
%   1) Signed mean along time: oscillating cross-terms can cancel.
%   2) Band-wise frequency centroids are calculated ON the original WVD.
%   3) The midpoint temporal fluctuation indicates geometric cross-coupling.
%   4) Accumulate each three-point score to BOTH endpoint frequencies.
%   5) A mask selects values from the ORIGINAL, unsmoothed WVD.
% This third-order homogeneous score is NOT the traditional bispectrum.
clear; close all; clc;
rng(7);

%% 1. Test signal: five periodic impulses excite two damped resonances
fs = 4000;                    % Hz
Tfault = 0.05;                % only to SYNTHESIZE signals, NOT used in detector
beta = 110;                   % amplitude decay, s^-1
fc = [650 980];               % only to SYNTHESIZE signals
amp = [1.0 0.7];
t = (0:round(0.27*fs)-1)'/fs;
impactTimes = 0.02:Tfault:0.22;
atoms = zeros(numel(t),numel(impactTimes)*numel(fc));
a = 0;
for j = 1:numel(impactTimes)
    u = t-impactTimes(j);
    for r = 1:numel(fc)
        a = a+1;
        atoms(:,a) = amp(r)*exp(-beta*max(u,0)) ...
            .*cos(2*pi*fc(r)*u).*(u>=0);
    end
end
xclean = sum(atoms,2);
x = xclean + 0.04*randn(size(xclean));

%% 2. WVD directly from the original input: NO filtering or decomposition
[W,f,tw] = wvd(hilbert(x),fs);
W = real(W); f = f(:); tw = tw(:);
assert(size(W,1)==numel(f) && size(W,2)==numel(tw));
df = median(diff(f));
assert(all(diff(f)>0),'Frequency bins must be ascending.');
assert(max(abs(diff(f)-df)) < 1e-7*fs,'Uniform frequency grid required.');

%% 3. Detector settings: band limits are specified on the WVD frequency axis
bands = [540 770; 865 1100];  % Hz; edit these for real vibration data
Lsec = 3/beta;                 % response-length window, seconds
hopSec = 0.005;                % hop of 5 ms
spanHz = 65;                   % candidates around the measured band centroids
sigmaHz = 40;                  % Gaussian weighting of endpoint candidates
excludeHz = 60;                % remove near-diagonal pairs
relativeFreqThreshold = 0.10;  % threshold within each time window
relativeActivityThreshold = 0.005; % gate only near numerical/noise floor

hopN = max(1,round(hopSec/median(diff(tw))));
centers = unique([1:hopN:numel(tw), numel(tw)]);
F = numel(f); Q = numel(centers);
scoreRaw = zeros(F,Q);
WbarByWindow = zeros(F,Q);
mu = nan(2,Q);
activity = zeros(Q,1);
midCancellation = nan(Q,1);

%% 4. Signed temporal averaging and three-point accumulation in each window
for q = 1:Q
    tq = tw(centers(q));
    idx = find(abs(tw-tq)<=Lsec/2);
    if numel(idx)<5, continue; end

    g = hann(numel(idx));
    g = g(:)/(sum(g)+eps);      % nonnegative time weights of total mass 1
    Wq = W(:,idx);
    wbar = Wq*g;               % SIGNED average, NO abs(W) before averaging
    wsigma = sqrt(max((Wq.^2)*g - wbar.^2,0));
    p = max(wbar,0);            % positive support AFTER signed cancellation
    WbarByWindow(:,q) = wbar;

    E = zeros(1,2);
    for r = 1:2
        kBand = find(f>=bands(r,1) & f<=bands(r,2));
        s = sum(p(kBand));
        E(r) = s*df;
        if s>1e-12
            % Local band-wise first-order frequency centroid of WVD values.
            % This is NOT asserted to equal the full-band WVD instantaneous
            % frequency moment, and is NOT computed on a filtered signal.
            mu(r,q) = sum(f(kBand).*p(kBand))/s;
        end
    end
    activity(q) = sqrt(E(1)*E(2));
    if any(~isfinite(mu(:,q))) || activity(q)<=0, continue; end

    iCandidates = find(f>=bands(1,1) & f<=bands(1,2) & ...
                       abs(f-mu(1,q))<=spanHz);
    jCandidates = find(f>=bands(2,1) & f<=bands(2,2) & ...
                       abs(f-mu(2,q))<=spanHz);
    local = zeros(F,1);
    sigmaFloor = 0.01*max(wsigma)+eps;
    for ia = 1:numel(iCandidates)
        i = iCandidates(ia);
        if p(i)<=0, continue; end
        wi = exp(-0.5*((f(i)-mu(1,q))/sigmaHz)^2);
        for ja = 1:numel(jCandidates)
            j = jCandidates(ja);
            if p(j)<=0 || abs(f(i)-f(j))<=excludeHz, continue; end
            wj = exp(-0.5*((f(j)-mu(2,q))/sigmaHz)^2);

            % Midpoint index, with linear interpolation if necessary.
            vm = (((f(i)+f(j))/2)-f(1))/df+1;
            k0 = floor(vm);
            if k0<1 || k0>=F, continue; end
            aMid = vm-k0;
            midMean = (1-aMid)*wbar(k0) + aMid*wbar(k0+1);
            midStd = (1-aMid)*wsigma(k0) + aMid*wsigma(k0+1);

            % True signed cancellation is retained in midMean.
            % The high midpoint fluctuation is used only as a LOCATION cue;
            % it is NOT copied to the output WVD.
            oscillationContrast = midStd/(midStd+abs(midMean)+sigmaFloor);
            c = wi*wj*p(i)*p(j)*midStd*oscillationContrast;
            local(i) = local(i)+c;
            local(j) = local(j)+c;    % accumulate to both endpoints
        end
    end
    scoreRaw(:,q) = local;

    % Diagnostic: midpoint signed mean relative to its fluctuations.
    vm = ((mean(mu(:,q))-f(1))/df)+1;
    km = max(1,min(F-1,floor(vm)));
    aMid = vm-km;
    mbar = (1-aMid)*wbar(km)+aMid*wbar(km+1);
    mstd = (1-aMid)*wsigma(km)+aMid*wsigma(km+1);
    midCancellation(q) = abs(mbar)/(mstd+eps);
end

%% 5. Window-wise normalization, then a mask of ORIGINAL WVD
% Do NOT multiply again by instantaneous period peaks. That caused severe
% loss of the damped self-term tails in the previous prototype.
scoreUnit = zeros(size(scoreRaw));
for q = 1:Q
    peak = max(scoreRaw(:,q));
    if peak>0, scoreUnit(:,q) = scoreRaw(:,q)/peak; end
end
S = interp1(tw(centers),scoreUnit.',tw,'linear',0).';
Etime = interp1(tw(centers),activity,tw,'linear',0);
Etime = Etime(:)'/(max(activity)+eps);
M = (S > relativeFreqThreshold) & ...
    repmat(Etime > relativeActivityThreshold,F,1);
Wout = W.*M;

%% 5b. ADD ONLY ONE operation: signed FREQUENCY averaging on the WVD.
% The existing detector/mask M above is UNCHANGED.
% Time-separated repeated impulses cause cross-terms that oscillate in
% FREQUENCY: their fringe spacing is approximately 1/(time separation).
% A 40-Hz Hann window spans about two fringes for a 50-ms separation.
% This is WVD-DOMAIN post-processing, not filtering the original signal.
% It changes the WVD pixel amplitudes: compare both outputs, do not label
% WoutFreq as merely 'masked original WVD'.
freqAvgHz = 40;                         % test 20 / 40 / 60 Hz later
halfBins = max(1,round(freqAvgHz/(2*df)));
freqKernel = hann(2*halfBins+1);
freqKernel = freqKernel/sum(freqKernel);
actualAvgHz = (numel(freqKernel)-1)*df;
Wfreq = conv2(freqKernel,1,W,'same');   % first dimension = frequency
WoutFreq = Wfreq.*M;                   % keep SAME M for fair comparison

% Optional: frequency SIGN-CONSISTENCY as a NEW temporal-cross-term cue.
% A fast sign-changing fringe has small signed mean relative to mean abs.
% This branch changes the mask ONLY and still selects ORIGINAL WVD pixels.
% It is a WVD-domain heuristic detector, NOT a conventional bispectrum.
freqAbsAvg = conv2(freqKernel,1,abs(W),'same');
freqSignConsistency = abs(Wfreq)./(freqAbsAvg+eps);
freqSignThreshold = 0.40;               % trial value; use ablation study
Msign = M & (freqSignConsistency>freqSignThreshold);
WoutSign = W.*Msign;                     % no amplitude smoothing of output

assert(isequal(size(M),size(W)));
assert(all(M(:)==0 | M(:)==1));
assert(all(Wout(~M)==0));
assert(isequal(Wout(M),W(M)));

%% 6. Diagnostics and oracle metrics (simulation ONLY; never used in mask)
active = all(isfinite(mu),1) & activity.'>0.3*max(activity);
if any(active)
    fprintf('WVD-band frequency centroids: %.1f, %.1f Hz\n', ...
        median(mu(1,active)),median(mu(2,active)));
    fprintf('Median |signed mean(midpoint)|/std(midpoint): %.3f\n', ...
        median(midCancellation(active),'omitnan'));
end
Wauto = zeros(size(W));
for j = 1:size(atoms,2)
    Wauto = Wauto + real(wvd(hilbert(atoms(:,j)),fs));
end
Wclean = real(wvd(hilbert(xclean),fs));
Wcross = Wclean-Wauto;
selfRetained = sum(abs(Wauto(M)).^2)/(sum(abs(Wauto(:)).^2)+eps);
crossRemaining = sum(abs(Wcross(M)).^2)/(sum(abs(Wcross(:)).^2)+eps);
ratioBefore = 10*log10((sum(abs(Wauto(:)).^2)+eps) / ...
                       (sum(abs(Wcross(:)).^2)+eps));
ratioAfter = 10*log10((sum(abs(Wauto(M)).^2)+eps) / ...
                      (sum(abs(Wcross(M)).^2)+eps));
fprintf('Self energy retained: %.1f%%\n',100*selfRetained);
fprintf('Cross energy removed: %.1f%%\n',100*(1-crossRemaining));
fprintf('Self/cross ratio: %.2f dB -> %.2f dB\n',ratioBefore,ratioAfter);

%% 6b. ORACLE diagnosis by cross-term type (simulation ONLY)
% Each impact creates TWO modal atoms (columns 1,3,5,... vs 2,4,6,...).
% Same-mode cross terms across DIFFERENT impacts = time-separated class.
% Cross terms across DIFFERENT modes = frequency-separated/mixed class.
% These oracle quantities are used ONLY for assessment, never for the mask.
mode1 = sum(atoms(:,1:2:end),2);
mode2 = sum(atoms(:,2:2:end),2);
Wmode1 = real(wvd(hilbert(mode1),fs));
Wmode2 = real(wvd(hilbert(mode2),fs));
WcrossTime = (Wmode1+Wmode2)-Wauto;
WcrossIntermode = Wclean-(Wmode1+Wmode2);

WautoFreq = conv2(freqKernel,1,Wauto,'same');
WcrossTimeFreq = conv2(freqKernel,1,WcrossTime,'same');
WcrossIntermodeFreq = conv2(freqKernel,1,WcrossIntermode,'same');

sq = @(X) sum(abs(X(:)).^2);
keepRatio = @(X,Y) sq(Y)/(sq(X)+eps);
selfOriginal = keepRatio(Wauto,Wauto.*M);
selfFreq = keepRatio(Wauto,WautoFreq.*M);
timeRemainOriginal = keepRatio(WcrossTime,WcrossTime.*M);
timeRemainFreq = keepRatio(WcrossTime,WcrossTimeFreq.*M);
interRemainOriginal = keepRatio(WcrossIntermode,WcrossIntermode.*M);
interRemainFreq = keepRatio(WcrossIntermode,WcrossIntermodeFreq.*M);
selfSign = keepRatio(Wauto,Wauto.*Msign);
timeRemainSign = keepRatio(WcrossTime,WcrossTime.*Msign);
interRemainSign = keepRatio(WcrossIntermode,WcrossIntermode.*Msign);

fprintf('\n--- Signed FREQUENCY averaging comparison; same AMB mask ---\n');
fprintf('Nominal frequency window: %.1f Hz; realized span: %.2f Hz\n',freqAvgHz,actualAvgHz);
% Kernel response at the periodic-impact time separations (ideal cos fringes)
kOffsets = (-halfBins:halfBins)';
for d = Tfault*(1:4)
    fringeGain = abs(sum(freqKernel .* exp(1i*2*pi*(kOffsets*df)*d)));
    fprintf('Predicted signed-frequency average fringe gain (delay %.0f ms): %.4f\n', ...
        1000*d,fringeGain);
end
fprintf('Self squared-magnitude ratio to original: mask only %.1f%% | + f-average %.1f%%\n', ...
    100*selfOriginal,100*selfFreq);
fprintf('Time-separated cross-term removed: mask only %.1f%% | + f-average %.1f%%\n', ...
    100*(1-timeRemainOriginal),100*(1-timeRemainFreq));
fprintf('Intermode cross-term removed: mask only %.1f%% | + f-average %.1f%%\n', ...
    100*(1-interRemainOriginal),100*(1-interRemainFreq));
fprintf('Frequency sign-consistency gate (threshold %.2f):\n',freqSignThreshold);
fprintf('  Self retained %.1f%% | across-impact cross removed %.1f%% | intermode cross removed %.1f%%\n', ...
    100*selfSign,100*(1-timeRemainSign),100*(1-interRemainSign));

%% 7. A small mathematical sanity check: midpoint signed cancellation
Ltest = round(Lsec*fs);
ttest = (0:Ltest-1)'/fs;
midToy = 2*cos(2*pi*(fc(2)-fc(1))*ttest);
fprintf('Pure-two-tone midpoint: signed mean %.3f, RMS %.3f\n', ...
    mean(midToy),sqrt(mean(midToy.^2)));

%% 8. Figures
scale = 0.035*max(abs(W(:)))+eps;
WbarTime = interp1(tw(centers),WbarByWindow.',tw,'linear',0).';
figure('Name','Direct WVD - Signed local three-point AMB-like detector','Color','w');
subplot(2,2,1);
imagesc(tw,f,asinh(W/scale)); axis xy; ylim([400 1250]);
xlabel('Time (s)'); ylabel('Frequency (Hz)'); title('Original WVD');
subplot(2,2,2);
imagesc(tw,f,asinh(WbarTime/scale)); axis xy; ylim([400 1250]);
xlabel('Time (s)'); ylabel('Frequency (Hz)'); title('Signed time average of WVD');
subplot(2,2,3);
imagesc(tw,f,S); axis xy; ylim([400 1250]);
xlabel('Time (s)'); ylabel('Frequency (Hz)'); title('Signed-window guided accumulation score');
subplot(2,2,4);
imagesc(tw,f,asinh(Wout/scale)); axis xy; ylim([400 1250]);
xlabel('Time (s)'); ylabel('Frequency (Hz)'); title('Original WVD after mask');

figure('Name','Direct WVD - local frequency centroids','Color','w');
plot(tw(centers),mu(1,:),'b.',tw(centers),mu(2,:),'r.');
ylim([400 1200]); xlabel('Time (s)'); ylabel('Frequency (Hz)');
legend('Band 1 centroid','Band 2 centroid','Location','best');
title('First-order frequency centroids from signed WVD window averages');


%% 9. Direct comparison with the SAME mask: do not infer from color alone
figure('Name','Two directions - time-separated cross terms','Color','w');
sharedCLim = asinh(max(abs(W(:)))/scale);
subplot(2,3,1);
imagesc(tw,f,asinh(WcrossTime/scale)); axis xy; ylim([400 1250]);
caxis([-sharedCLim sharedCLim]); xlabel('Time (s)'); ylabel('Frequency (Hz)');
title('Oracle: across-impact cross terms');
subplot(2,3,2);
imagesc(tw,f,asinh(Wout/scale)); axis xy; ylim([400 1250]);
caxis([-sharedCLim sharedCLim]); xlabel('Time (s)');
title('Original WVD * existing mask');
subplot(2,3,3);
imagesc(tw,f,asinh(WoutFreq/scale)); axis xy; ylim([400 1250]);
caxis([-sharedCLim sharedCLim]); xlabel('Time (s)');
title('Frequency-signed WVD * same mask');
subplot(2,3,4);
imagesc(tw,f,asinh(WcrossTimeFreq/scale)); axis xy; ylim([400 1250]);
caxis([-sharedCLim sharedCLim]); xlabel('Time (s)'); ylabel('Frequency (Hz)');
title('Across-impact cross after f-average');
subplot(2,3,5);
imagesc(tw,f,asinh((WcrossTime.*M)/scale)); axis xy; ylim([400 1250]);
caxis([-sharedCLim sharedCLim]); xlabel('Time (s)');
title('Across-impact cross after mask');
subplot(2,3,6);
imagesc(tw,f,asinh((WcrossTimeFreq.*M)/scale)); axis xy; ylim([400 1250]);
caxis([-sharedCLim sharedCLim]); xlabel('Time (s)');
title('Across-impact cross after BOTH');
sgtitle('Fixed detector/mask; only add signed averaging along frequency');


%% 10. Frequency sign-consistency: detector-only update (W pixels unchanged)
figure('Name','Frequency sign-consistency as a time-cross-term discriminator','Color','w');
subplot(1,3,1);
imagesc(tw,f,freqSignConsistency); axis xy; ylim([400 1250]); caxis([0 1]);
xlabel('Time (s)'); ylabel('Frequency (Hz)');
title('Frequency sign consistency');
subplot(1,3,2);
imagesc(tw,f,asinh(Wout/scale)); axis xy; ylim([400 1250]);
caxis([-sharedCLim sharedCLim]); xlabel('Time (s)');
title('Previous AMB mask * WVD');
subplot(1,3,3);
imagesc(tw,f,asinh(WoutSign/scale)); axis xy; ylim([400 1250]);
caxis([-sharedCLim sharedCLim]); xlabel('Time (s)');
title('Joint mask * ORIGINAL WVD');
sgtitle('Frequency-sign consistency added to original AMB candidate mask');
