% Development evaluation: the oracle below is used only after mask creation.
if ~exist('results/fusion','dir'), mkdir('results/fusion'); end
diary('results/fusion/fusion.log');
run('demo_direct_wvd_signed_amb_temporal_triplets.m');
fusionScore = sqrt(max(S,0).*max(AtUnit,0));
fusionThreshold = sqrt(relativeFreqThreshold*timeScoreThreshold);
Msoft = fusionScore>fusionThreshold & Etime>relativeActivityThreshold;
Wsoft = W.*Msoft;
selfSoft = keepRatio(Wauto,Wauto.*Msoft);
timeRemainSoft = keepRatio(WcrossTime,WcrossTime.*Msoft);
interRemainSoft = keepRatio(WcrossIntermode,WcrossIntermode.*Msoft);
nmseSoft = nmse(Wsoft);
fprintf('\nSOFT FUSION: threshold %.5f, self %.1f%%, across-impact removed %.1f%%, intermode removed %.1f%%, NMSE %.4f\n', ...
    fusionThreshold,100*selfSoft,100*(1-timeRemainSoft),100*(1-interRemainSoft),nmseSoft);
result = struct('threshold',fusionThreshold,'self_retained',selfSoft, ...
    'across_impact_removed',1-timeRemainSoft,'intermode_removed',1-interRemainSoft, ...
    'nmse',nmseSoft,'candidate_impacts_s',tw(peakIdx),'eligible_time_pairs',pairCount);
fid = fopen('results/fusion/fusion.json','w');
fprintf(fid,'%s\n',jsonencode(result));
fclose(fid);
figure('Name','Soft fusion','Color','w','Position',[50 50 1100 760]);
subplot(2,3,1); imagesc(tw,f,asinh(W/scale)); axis xy; ylim([400 1250]); title('Original WVD'); xlabel('Time (s)'); ylabel('Frequency (Hz)');
subplot(2,3,2); imagesc(tw,f,S); axis xy; ylim([400 1250]); title('Frequency score'); xlabel('Time (s)');
subplot(2,3,3); imagesc(tw,f,AtUnit); axis xy; ylim([400 1250]); title('Time score'); xlabel('Time (s)');
subplot(2,3,4); imagesc(tw,f,fusionScore); axis xy; ylim([400 1250]); title('Geometric mean score'); xlabel('Time (s)'); ylabel('Frequency (Hz)');
subplot(2,3,5); imagesc(tw,f,asinh(Wsoft/scale)); axis xy; ylim([400 1250]); title('Soft fusion WVD'); xlabel('Time (s)');
subplot(2,3,6); imagesc(tw,f,asinh(Wauto/scale)); axis xy; ylim([400 1250]); title('Oracle self terms (evaluation only)'); xlabel('Time (s)');
exportgraphics(gcf,'results/fusion/synthetic_fusion.png','Resolution',300);
diary('off');
