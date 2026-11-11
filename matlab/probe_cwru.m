% Inspect the original-WVD frequency axis of one official CWRU record.
if ~exist('results/cwru-probe','dir'), mkdir('results/cwru-probe'); end
diary('results/cwru-probe/probe.log');
data = load('input/cwru/130.mat');
fs = 12000;
x = data.X130_DE_time(1:2048);
[W,f,tw] = wvd(hilbert(x),fs);
W = real(W); f = f(:);
profile = mean(max(W,0),2);
profileSmooth = movmean(profile,max(3,round(80/median(diff(f)))));
select = f>=500 & f<=5500;
[pks,locs] = findpeaks(profileSmooth(select),f(select),'MinPeakDistance',350);
[~,ord] = sort(pks,'descend');
ord = ord(1:min(10,numel(ord)));
fprintf('CWRU 130.mat, DE, RPM %.0f, fs %.0f Hz, samples %d, WVD %d x %d\n', ...
    data.X130RPM,fs,numel(x),size(W,1),size(W,2));
fprintf('Strong positive-WVD frequency locations (Hz):');
fprintf(' %.1f',locs(ord)); fprintf('\n');
fprintf('Corresponding strengths:'); fprintf(' %.3g',pks(ord)); fprintf('\n');
result = struct('file','130.mat','channel','X130_DE_time','rpm',data.X130RPM, ...
    'fs',fs,'sample_count',numel(x),'wvd_size',size(W), ...
    'wvd_peak_hz',locs(ord),'wvd_peak_strength',pks(ord));
fid = fopen('results/cwru-probe/probe.json','w');
fprintf(fid,'%s\n',jsonencode(result)); fclose(fid);
figure('Visible','off','Color','w');
plot(f,profileSmooth); xlim([500 5500]); xlabel('Frequency (Hz)');
ylabel('Mean positive WVD'); title('CWRU 130 DE: raw-WVD frequency profile');
exportgraphics(gcf,'results/cwru-probe/frequency_profile.png','Resolution',200);
close(gcf);
diary('off');
