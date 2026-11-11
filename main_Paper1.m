function result = main_Paper1(mode, dataFile, startIndex)
% Paper1: direct-WVD dual-direction endpoint/midpoint/endpoint detector.
% Usage: main_Paper1('synthetic'), main_Paper1('cwru',file), or
%        main_Paper1('paderborn',file,startIndex)
if nargin<1, mode='synthetic'; end
if nargin<2, dataFile='input/cwru/130.mat'; end
if nargin<3, startIndex=1; end
mode=char(mode);
if strcmp(mode,'synthetic')
    rng(7); fs=4000; t=(0:round(0.27*fs)-1)'/fs;
    impactTimes=0.02:0.05:0.22; fc=[650 980]; amp=[1 0.7]; beta=110;
    atoms=zeros(numel(t),numel(impactTimes)*2); a=0;
    for j=1:numel(impactTimes)
        u=t-impactTimes(j);
        for r=1:2
            a=a+1;
            atoms(:,a)=amp(r)*exp(-beta*max(u,0)).*cos(2*pi*fc(r)*u).*(u>=0);
        end
    end
    xclean=sum(atoms,2); x=xclean+0.04*randn(size(xclean));
    p=struct('bands',[540 770;865 1100],'Lsec',3/beta, ...
        'hopSec',0.005,'spanHz',65,'sigmaHz',40,'excludeHz',60, ...
        'freqAvgHz',40,'freqThr',0.10,'timeThr',0.08, ...
        'activityThr',0.005,'maxPairDelaySec',0.16, ...
        'minPeakDistanceSec',0.015);
    outdir=fullfile('results','synthetic');
elseif strcmp(mode,'cwru')
    d=load(dataFile);
    [~,stem]=fileparts(dataFile);
    id=str2double(stem);
    if id==97, key='X097'; fs=48000;
    else, key=sprintf('X%d',id); fs=12000; end
    de=[key '_DE_time']; rpmKey=[key 'RPM'];
    assert(isfield(d,de) && isfield(d,rpmKey),'Required DE/RPM variables missing');
    record=d.(de);
    assert(startIndex>=1 && startIndex+2047<=numel(record), ...
        'Requested 2048-sample segment is outside record');
    x=double(record(startIndex:startIndex+2047)); x=x(:);
    rpm=double(d.(rpmKey));
    p=struct('bands',[],'Lsec',0.006,'hopSec',0.001, ...
        'spanHz',110,'sigmaHz',80,'excludeHz',100, ...
        'freqAvgHz',200,'freqThr',0.10,'timeThr',0.08, ...
        'activityThr',0.005,'maxPairDelaySec',0.08, ...
        'minPeakDistanceSec',0.004);
    if startIndex==1
        outdir=fullfile('results',['cwru-' stem]);
    else
        outdir=fullfile('results',sprintf('cwru-%s-start%d',stem,startIndex));
    end
elseif strcmp(mode,'paderborn')
    [record,fs,rpm,forceN,torqueNm,channel]=read_paderborn(dataFile);
    segmentN=4096;
    assert(startIndex>=1 && startIndex+segmentN-1<=numel(record), ...
        'Requested Paderborn segment is outside vibration record');
    x=double(record(startIndex:startIndex+segmentN-1)); x=x(:);
    p=struct('bands',[],'Lsec',0.004,'hopSec',0.001, ...
        'spanHz',250,'sigmaHz',180,'excludeHz',700, ...
        'freqAvgHz',400,'freqThr',0.10,'timeThr',0.08, ...
        'activityThr',0.005,'maxPairDelaySec',0.06, ...
        'minPeakDistanceSec',0.003);
    [~,stem]=fileparts(dataFile);
    outdir=fullfile('results','paderborn',sprintf('%s-start%d',stem,startIndex));
elseif strcmp(mode,'xjtu')
    record=readmatrix(dataFile);
    assert(size(record,2)==2 && size(record,1)==32768 && ...
        all(isfinite(record(:))),'Invalid two-channel XJTU-SY snapshot');
    fs=25600; rpm=2100; forceN=12000; torqueNm=NaN;
    channel='Horizontal_vibration_signals';
    segmentN=4096;
    assert(startIndex>=1 && startIndex+segmentN-1<=size(record,1));
    x=double(record(startIndex:startIndex+segmentN-1,1));
    p=struct('bands',[],'Lsec',0.007,'hopSec',0.0015, ...
        'spanHz',120,'sigmaHz',100,'excludeHz',350, ...
        'freqAvgHz',200,'freqThr',0.10,'timeThr',0.08, ...
        'activityThr',0.005,'maxPairDelaySec',0.12, ...
        'minPeakDistanceSec',0.004);
    [~,stem]=fileparts(dataFile);
    outdir=fullfile('results','xjtu',sprintf('Bearing1_1-%s-start%d',stem,startIndex));
else
    error('Unknown mode %s',mode);
end
if ~exist(outdir,'dir'), mkdir(outdir); end
diary(fullfile(outdir,'experiment.log'));
cleanup=onCleanup(@() diary('off'));
[W,f,tw]=wvd(hilbert(x),fs);
W=real(W); f=f(:); tw=tw(:); F=numel(f); T=numel(tw);
df=median(diff(f)); dt=median(diff(tw));
assert(isequal(size(W),[F,T]) && all(diff(f)>0));
if isempty(p.bands)
    if strcmp(mode,'paderborn')
        smoothHz=250; lowerHz=2000; upperHz=min(25000,0.9*fs/2);
        minBandDistanceHz=1800; bandHalfwidthHz=450;
    elseif strcmp(mode,'xjtu')
        smoothHz=150; lowerHz=1200; upperHz=min(10000,0.9*fs/2);
        minBandDistanceHz=1000; bandHalfwidthHz=250;
    else
        smoothHz=80; lowerHz=1500; upperHz=min(4500,0.9*fs/2);
        minBandDistanceHz=600; bandHalfwidthHz=175;
    end
    profile=movmean(mean(max(W,0),2),max(3,round(smoothHz/df)));
    eligible=f>=lowerHz & f<=upperHz;
    [pk,loc]=findpeaks(profile(eligible),f(eligible), ...
        'MinPeakDistance',minBandDistanceHz);
    [~,rank]=sort(pk,'descend');
    assert(numel(rank)>=2,'Two distinct WVD resonance bands not found');
    p.bands=sort(loc(rank(1:2)));
    p.bands=[p.bands(:)-bandHalfwidthHz,p.bands(:)+bandHalfwidthHz];
end
if strcmp(mode,'paderborn') || strcmp(mode,'xjtu')
    % The original signal is passed to wvd. This crops only the calculated
    % WVD frequency grid, retaining both selected bands and their midpoints.
    keep=f>=max(0,p.bands(1,1)-600) & ...
        f<=min(fs/2,p.bands(2,2)+600);
    W=W(keep,:); f=f(keep); F=numel(f);
end
fprintf('Mode %s, fs %g Hz, WVD %d x %d, bands [%.1f %.1f], [%.1f %.1f] Hz\n', ...
    mode,fs,F,T,p.bands(1,1),p.bands(1,2),p.bands(2,1),p.bands(2,2));
[Sf,St,Etime,peakIdx,pairCount]=dual_detector(W,f,tw,p);
Mf=(Sf>p.freqThr) & (Etime>p.activityThr);
Mt=St>p.timeThr;
Mj=Mf & Mt;
fusion=sqrt(max(Sf,0).*max(St,0));
fusionThreshold=sqrt(p.freqThr*p.timeThr);
M=(fusion>fusionThreshold) & (Etime>p.activityThr);
Wout=W.*M;
fprintf('Detected candidate times (ms):'); fprintf(' %.2f',1e3*tw(peakIdx)); fprintf('\n');
fprintf('Eligible time pairs %d; fusion threshold %.5f; retained pixels %.2f%%\n', ...
    pairCount,fusionThreshold,100*nnz(M)/numel(M));
result=struct('mode',mode,'fs_hz',fs,'wvd_size',size(W), ...
    'bands_hz',p.bands,'fusion_threshold',fusionThreshold, ...
    'candidate_impacts_s',tw(peakIdx),'eligible_time_pairs',pairCount, ...
    'retained_pixel_fraction',nnz(M)/numel(M),'parameters',p);
if strcmp(mode,'synthetic')
    Wauto=zeros(size(W));
    for j=1:size(atoms,2)
        Wauto=Wauto+real(wvd(hilbert(atoms(:,j)),fs));
    end
    Wclean=real(wvd(hilbert(xclean),fs));
    mode1=sum(atoms(:,1:2:end),2); mode2=sum(atoms(:,2:2:end),2);
    WcrossTime=real(wvd(hilbert(mode1),fs))+real(wvd(hilbert(mode2),fs))-Wauto;
    WcrossIntermode=Wclean-Wauto-WcrossTime;
    result.fusion_metrics=sim_metrics(M,W,Wauto,WcrossTime,WcrossIntermode);
    result.intersection_metrics=sim_metrics(Mj,W,Wauto,WcrossTime,WcrossIntermode);
    fprintf('Fusion: self %.1f%%, time cross removed %.1f%%, intermode removed %.1f%%, NMSE %.4f\n', ...
        100*result.fusion_metrics.self_retained, ...
        100*result.fusion_metrics.time_cross_removed, ...
        100*result.fusion_metrics.intermode_cross_removed,result.fusion_metrics.nmse);
    fprintf('Intersection: self %.1f%%, time cross removed %.1f%%, intermode removed %.1f%%, NMSE %.4f\n', ...
        100*result.intersection_metrics.self_retained, ...
        100*result.intersection_metrics.time_cross_removed, ...
        100*result.intersection_metrics.intermode_cross_removed, ...
        result.intersection_metrics.nmse);
    plot_result(tw,f,W,Sf,St,Wout,outdir,[400 1250],Wauto,[]);
elseif strcmp(mode,'cwru')
    switch id
        case 105
            faultName='BPFI'; faultFactor=5.4152;
        case 118
            faultName='BSF'; faultFactor=4.7135;
        case 130
            faultName='BPFO'; faultFactor=3.5848;
        otherwise
            error('Fault-frequency evidence is specified for 105, 118, 130 only');
    end
    expected=faultFactor*rpm/60;
    selected=(f>=p.bands(1,1)&f<=p.bands(1,2)) | ...
        (f>=p.bands(2,1)&f<=p.bands(2,2));
    activityRaw=sum(max(W(selected,:),0),1)*df;
    activityOut=sum(max(Wout(selected,:),0),1)*df;
    [peakRaw,contrastRaw]=fault_evidence(activityRaw,dt,expected);
    [peakOut,contrastOut]=fault_evidence(activityOut,dt,expected);
    result.file=dataFile; result.channel=de; result.rpm=rpm;
    result.start_sample=startIndex; result.end_sample=startIndex+2047;
    result.fault_frequency_name=faultName;
    result.expected_fault_hz=expected;
    result.raw_periodicity_peak_hz=peakRaw;
    result.fused_periodicity_peak_hz=peakOut;
    result.raw_fault_contrast=contrastRaw;
    result.fused_fault_contrast=contrastOut;
    if numel(peakIdx)>1
        result.median_candidate_spacing_ms=1000*median(diff(tw(peakIdx)));
    else
        result.median_candidate_spacing_ms=NaN;
    end
    fprintf('CWRU %s, RPM %.0f, expected %s %.2f Hz, raw periodicity peak %.2f Hz (contrast %.2f), fused %.2f Hz (contrast %.2f)\n', ...
        stem,rpm,faultName,expected,peakRaw,contrastRaw,peakOut,contrastOut);
    evidence=struct('raw',activityRaw,'fused',activityOut, ...
        'dt',dt,'expected_hz',expected,'fault_name',faultName);
    plot_result(tw,f,W,Sf,St,Wout,outdir,[1000 min(4500,fs/2)],[],evidence);
else
    % Fault labels and theoretical frequencies enter only after WVD band
    % selection, dual-direction detection, and reconstruction are complete.
    if strcmp(mode,'xjtu')
        faultName='BPFO';
        geometry=struct('balls',8,'ball_diameter_mm',7.92, ...
            'pitch_diameter_mm',34.55,'contact_angle_deg',0);
        rpmSource='nominal test condition';
    else
        if contains(stem,'_KA'), faultName='BPFO';
        elseif contains(stem,'_KI'), faultName='BPFI';
        else, faultName='healthy'; end
        % Nominal 6203 geometry; study notes 1–2% maker variation.
        geometry=struct('balls',8,'ball_diameter_mm',6.75, ...
            'pitch_diameter_mm',28.55,'contact_angle_deg',0);
        rpmSource='MAT speed channel mean';
    end
    ratio=geometry.ball_diameter_mm/geometry.pitch_diameter_mm;
    bpfo=geometry.balls/2*(1-ratio)*rpm/60;
    bpfi=geometry.balls/2*(1+ratio)*rpm/60;
    selected=(f>=p.bands(1,1)&f<=p.bands(1,2)) | ...
        (f>=p.bands(2,1)&f<=p.bands(2,2));
    activityRaw=sum(max(W(selected,:),0),1)*df;
    activityOut=sum(max(Wout(selected,:),0),1)*df;
    [rawBpfo,rawBpfoContrast]=fault_evidence(activityRaw,dt,bpfo);
    [outBpfo,outBpfoContrast]=fault_evidence(activityOut,dt,bpfo);
    [rawBpfi,rawBpfiContrast]=fault_evidence(activityRaw,dt,bpfi);
    [outBpfi,outBpfiContrast]=fault_evidence(activityOut,dt,bpfi);
    result.file=dataFile; result.channel=channel;
    result.start_sample=startIndex; result.end_sample=startIndex+numel(x)-1;
    result.rpm=rpm; result.measured_force_N=forceN;
    result.measured_torque_Nm=torqueNm;
    result.rpm_source=rpmSource;
    if strcmp(mode,'xjtu')
        result.force_source='nominal 12 kN test condition';
        result.nominal_force_N=forceN;
        result.measured_force_N=NaN;
    else
        result.force_source='MAT force channel mean';
    end
    result.nominal_geometry=geometry;
    result.bpfo_hz=bpfo; result.bpfi_hz=bpfi;
    result.fault_name=faultName;
    result.raw_bpfo_peak_hz=rawBpfo;
    result.fused_bpfo_peak_hz=outBpfo;
    result.raw_bpfo_contrast=rawBpfoContrast;
    result.fused_bpfo_contrast=outBpfoContrast;
    result.raw_bpfi_peak_hz=rawBpfi;
    result.fused_bpfi_peak_hz=outBpfi;
    result.raw_bpfi_contrast=rawBpfiContrast;
    result.fused_bpfi_contrast=outBpfiContrast;
    if numel(peakIdx)>1
        result.median_candidate_spacing_ms=1000*median(diff(tw(peakIdx)));
    else
        result.median_candidate_spacing_ms=NaN;
    end
    fprintf('%s %s rpm %.2f, force %.1f N, torque %.3f Nm; nominal BPFO %.2f, BPFI %.2f Hz\n', ...
        mode,stem,rpm,forceN,torqueNm,bpfo,bpfi);
    fprintf('BPFO raw %.2f / %.2f, fused %.2f / %.2f; BPFI raw %.2f / %.2f, fused %.2f / %.2f (peak Hz / contrast)\n', ...
        rawBpfo,rawBpfoContrast,outBpfo,outBpfoContrast, ...
        rawBpfi,rawBpfiContrast,outBpfi,outBpfiContrast);
    if strcmp(faultName,'BPFI'), expected=bpfi;
    else, expected=bpfo; end
    evidence=struct('raw',activityRaw,'fused',activityOut, ...
        'dt',dt,'expected_hz',expected,'fault_name',faultName);
    plotLimits=[max(0,p.bands(1,1)-600) ...
        min(fs/2,p.bands(2,2)+600)];
    plot_result(tw,f,W,Sf,St,Wout,outdir,plotLimits,[],evidence);
    % Artifact grids are thinned only after all calculations. The full
    % resolution input signal and published plot remain archived.
    frequency_stride=4; time_stride=4;
    fi=1:frequency_stride:numel(f); ti=1:time_stride:numel(tw);
    archive=struct('signal',x,'fs_hz',fs,'frequency_hz',f(fi), ...
        'time_s',tw(ti),'original_wvd',single(W(fi,ti)), ...
        'frequency_detection',single(Sf(fi,ti)), ...
        'time_detection',single(St(fi,ti)), ...
        'geometric_fusion',single(fusion(fi,ti)), ...
        'reconstructed_wvd',single(Wout(fi,ti)), ...
        'frequency_stride',frequency_stride,'time_stride',time_stride, ...
        'raw_activity',activityRaw,'fused_activity',activityOut);
    save(fullfile(outdir,'experiment_arrays.mat'),'archive','-v7.3');
    result.artifact_grid_stride=[frequency_stride,time_stride];
end
fid=fopen(fullfile(outdir,'result.json'),'w');
assert(fid>0); fprintf(fid,'%s\n',jsonencode(result)); fclose(fid);
end

function [x,fs,rpm,forceN,torqueNm,channel]=read_paderborn(file)
d=load(file); names=fieldnames(d);
assert(numel(names)==1,'Expected one Paderborn measurement root');
record=d.(names{1});
assert(isfield(record,'Y') && isfield(record,'X'));
yNames=string({record.Y.Name});
v=find(yNames=="vibration_1",1);
s=find(yNames=="speed",1);
q=find(yNames=="force",1);
m=find(yNames=="torque",1);
assert(~isempty(v) && ~isempty(s) && ~isempty(q) && ~isempty(m), ...
    'Official vibration/speed/force/torque channels missing');
channel=char(yNames(v));
x=record.Y(v).Data(:);
time=double(record.X(record.Y(v).XIndex).Data(:));
assert(numel(x)==numel(time) && numel(x)>64000);
observedFs=(numel(time)-1)/(time(end)-time(1));
fprintf('Paderborn raster samples=%d duration=%.9g s implied_fs=%.6f Hz\n', ...
    numel(time),time(end)-time(1),observedFs);
assert(all(diff(time)>0),'Vibration time raster is not monotone');
if abs(observedFs-64000)>=100
    warning('Time raster differs from official 64 kHz; using official rate for segment');
end
fs=64000;
rpm=mean(double(record.Y(s).Data(:)));
forceN=mean(double(record.Y(q).Data(:)));
torqueNm=mean(double(record.Y(m).Data(:)));
assert(rpm>500 && rpm<2500 && all(isfinite(x)));
end

function [Sf,St,Etime,peakIdx,pairCount]=dual_detector(W,f,tw,p)
F=numel(f); T=numel(tw); df=median(diff(f)); dt=median(diff(tw));
hopN=max(1,round(p.hopSec/dt)); centers=unique([1:hopN:T,T]); Q=numel(centers);
raw=zeros(F,Q); activity=zeros(Q,1);
for q=1:Q
    idx=find(abs(tw-tw(centers(q)))<=p.Lsec/2);
    if numel(idx)<5, continue; end
    g=hann(numel(idx)); g=g(:)/(sum(g)+eps);
    Wq=W(:,idx); bar=Wq*g;
    sd=sqrt(max((Wq.^2)*g-bar.^2,0)); pos=max(bar,0);
    mu=nan(2,1); energy=zeros(2,1);
    for r=1:2
        ii=find(f>=p.bands(r,1)&f<=p.bands(r,2));
        mass=sum(pos(ii)); energy(r)=mass*df;
        if mass>1e-12, mu(r)=sum(f(ii).*pos(ii))/mass; end
    end
    activity(q)=sqrt(prod(energy));
    if any(~isfinite(mu)), continue; end
    ci=find(f>=p.bands(1,1)&f<=p.bands(1,2)&abs(f-mu(1))<=p.spanHz);
    cj=find(f>=p.bands(2,1)&f<=p.bands(2,2)&abs(f-mu(2))<=p.spanHz);
    local=zeros(F,1); floorSd=0.01*max(sd)+eps;
    for ai=1:numel(ci)
        i=ci(ai); if pos(i)<=0, continue; end
        wi=exp(-0.5*((f(i)-mu(1))/p.sigmaHz)^2);
        for aj=1:numel(cj)
            j=cj(aj);
            if pos(j)<=0 || abs(f(i)-f(j))<=p.excludeHz, continue; end
            wj=exp(-0.5*((f(j)-mu(2))/p.sigmaHz)^2);
            vm=((f(i)+f(j))/2-f(1))/df+1; k0=floor(vm);
            if k0<1 || k0>=F, continue; end
            frac=vm-k0;
            meanMid=(1-frac)*bar(k0)+frac*bar(k0+1);
            stdMid=(1-frac)*sd(k0)+frac*sd(k0+1);
            c=wi*wj*pos(i)*pos(j)*stdMid^2/(stdMid+abs(meanMid)+floorSd);
            local(i)=local(i)+c; local(j)=local(j)+c;
        end
    end
    raw(:,q)=local;
end
unit=zeros(size(raw));
for q=1:Q
    peak=max(raw(:,q)); if peak>0, unit(:,q)=raw(:,q)/peak; end
end
Sf=interp1(tw(centers),unit.',tw,'linear',0).';
Etime=interp1(tw(centers),activity,tw,'linear',0).';
Etime=Etime/(max(activity)+eps);
halfBins=max(1,round(p.freqAvgHz/(2*df)));
h=hann(2*halfBins+1); h=h/sum(h);
Wfreq=conv2(h,1,W,'same');
WfStd=sqrt(max(conv2(h,1,W.^2,'same')-Wfreq.^2,0));
Pf=max(Wfreq,0);
selected=false(F,1);
for r=1:2, selected=selected|(f>=p.bands(r,1)&f<=p.bands(r,2)); end
activityF=sum(Pf(selected,:),1)*df;
smooth=movmean(activityF,max(3,round(0.002/dt)));
minDist=max(p.minPeakDistanceSec,0.6*p.Lsec);
if max(smooth)>0
    [~,peakIdx]=findpeaks(smooth,'MinPeakDistance',max(1,round(minDist/dt)), ...
        'MinPeakProminence',0.10*max(smooth));
else
    peakIdx=[];
end
peakIdx=peakIdx(:)'; rawTime=zeros(size(W)); pairCount=0;
floorMid=0.02*max(WfStd(:))+eps;
for a=1:numel(peakIdx)-1
    i=peakIdx(a);
    for b=a+1:numel(peakIdx)
        j=peakIdx(b); delay=tw(j)-tw(i);
        if delay<minDist || delay>p.maxPairDelaySec, continue; end
        vm=(i+j)/2; i0=floor(vm);
        if i0<1 || i0>=T, continue; end
        frac=vm-i0;
        midMean=(1-frac)*Wfreq(:,i0)+frac*Wfreq(:,i0+1);
        midStd=(1-frac)*WfStd(:,i0)+frac*WfStd(:,i0+1);
        c=Pf(:,i).*Pf(:,j).*midStd.^2./(midStd+abs(midMean)+floorMid);
        c(~selected)=0;
        rawTime(:,i)=rawTime(:,i)+c; rawTime(:,j)=rawTime(:,j)+c;
        pairCount=pairCount+1;
    end
end
lag=0:round(p.Lsec/dt); kernel=exp(-lag*dt/(p.Lsec/3));
spread=filter(kernel,1,rawTime,[],2);
St=zeros(size(spread));
for r=1:2
    ii=f>=p.bands(r,1)&f<=p.bands(r,2);
    bandMax=max(spread(ii,:),[],'all');
    if bandMax>0, St(ii,:)=spread(ii,:)/(bandMax+eps); end
end
end

function metrics=sim_metrics(mask,W,Wa,Wt,Wi)
sq=@(x)sum(x(:).^2);
metrics=struct('self_retained',sq(Wa.*mask)/(sq(Wa)+eps), ...
    'time_cross_removed',1-sq(Wt.*mask)/(sq(Wt)+eps), ...
    'intermode_cross_removed',1-sq(Wi.*mask)/(sq(Wi)+eps), ...
    'nmse',sq(W.*mask-Wa)/(sq(Wa)+eps));
end

function [peak,contrast]=fault_evidence(activity,dt,expected)
y=activity(:)'-mean(activity);
nfft=2^nextpow2(16*numel(y)); Y=abs(fft(y,nfft)).^2;
freq=(0:nfft-1)/(nfft*dt);
search=freq>=0.8*expected&freq<=1.2*expected;
background=freq>=50&freq<=200&~search;
[power,k]=max(Y(search)); candidates=freq(search);
peak=candidates(k); contrast=power/(median(Y(background))+eps);
end

function plot_result(tw,f,W,Sf,St,Wout,outdir,ylimHz,Wauto,evidence)
fig=figure('Visible','off','Color','w','Position',[30 30 1260 700]);
scale=0.035*max(abs(W(:)))+eps;
layout=tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');
ax=nexttile(layout); imagesc(tw,f,asinh(W/scale)); axis xy; ylim(ylimHz);
title('Original WVD'); xlabel('Time (s)'); ylabel('Frequency (Hz)');
ax.FontSize=9;
ax=nexttile(layout); imagesc(tw,f,Sf); axis xy; ylim(ylimHz); title('Frequency triplets'); xlabel('Time (s)'); ax.FontSize=9;
ax=nexttile(layout); imagesc(tw,f,St); axis xy; ylim(ylimHz); title('Time triplets'); xlabel('Time (s)'); ax.FontSize=9;
ax=nexttile(layout); imagesc(tw,f,asinh(Wout/scale)); axis xy; ylim(ylimHz);
title('Fused original WVD'); xlabel('Time (s)'); ylabel('Frequency (Hz)');
ax.FontSize=9;
ax=nexttile(layout); imagesc(tw,f,sqrt(max(Sf,0).*max(St,0))); axis xy; ylim(ylimHz);
title('Geometric fusion'); xlabel('Time (s)'); ax.FontSize=9;
ax=nexttile(layout); ax.FontSize=9;
if ~isempty(evidence)
    [freq,pRaw]=periodogram_curve(evidence.raw,evidence.dt);
    [~,pFused]=periodogram_curve(evidence.fused,evidence.dt);
    back=freq>=50 & freq<=200;
    h1=plot(freq,10*log10(pRaw/(median(pRaw(back))+eps)+eps),'Color',[.5 .5 .5]); hold on;
    h2=plot(freq,10*log10(pFused/(median(pFused(back))+eps)+eps),'b');
    xline(evidence.expected_hz,'r--',evidence.fault_name);
    xlim([50 200]); ylabel('Periodic power / median (dB)');
    title('Fault repetition evidence'); legend([h1 h2],{'Original','Fused'},'Location','northeast');
    xlabel('Repetition frequency (Hz)');
else
    imagesc(tw,f,asinh(Wauto/scale)); axis xy; ylim(ylimHz);
    title('Oracle self terms'); ylabel('Frequency (Hz)');
    xlabel('Time (s)');
end
exportgraphics(fig,fullfile(outdir,'paper_figure.png'),'Resolution',180);
close(fig);
end

function [freq,power]=periodogram_curve(activity,dt)
y=activity(:)'-mean(activity);
nfft=2^nextpow2(16*numel(y));
power=abs(fft(y,nfft)).^2;
freq=(0:nfft-1)/(nfft*dt);
end
