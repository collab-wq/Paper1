function result = main_Paper1(mode, dataFile)
% Paper1: direct-WVD dual-direction endpoint/midpoint/endpoint detector.
% Usage: main_Paper1('synthetic') or main_Paper1('cwru','input/cwru/130.mat')
if nargin<1, mode='synthetic'; end
if nargin<2, dataFile='input/cwru/130.mat'; end
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
    x=d.(de); x=double(x(1:2048)); x=x(:); rpm=double(d.(rpmKey));
    p=struct('bands',[],'Lsec',0.006,'hopSec',0.001, ...
        'spanHz',110,'sigmaHz',80,'excludeHz',100, ...
        'freqAvgHz',200,'freqThr',0.10,'timeThr',0.08, ...
        'activityThr',0.005,'maxPairDelaySec',0.08, ...
        'minPeakDistanceSec',0.004);
    outdir=fullfile('results',['cwru-' stem]);
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
    profile=movmean(mean(max(W,0),2),max(3,round(80/df)));
    eligible=f>=1500 & f<=min(4500,0.9*fs/2);
    [pk,loc]=findpeaks(profile(eligible),f(eligible),'MinPeakDistance',600);
    [~,rank]=sort(pk,'descend');
    assert(numel(rank)>=2,'Two distinct WVD resonance bands not found');
    p.bands=sort(loc(rank(1:2)));
    p.bands=[p.bands(:)-175,p.bands(:)+175];
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
    plot_result(tw,f,W,Sf,St,Wout,outdir,[400 1250],Wauto);
else
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
    result.fault_frequency_name=faultName;
    result.expected_fault_hz=expected;
    result.raw_periodicity_peak_hz=peakRaw;
    result.fused_periodicity_peak_hz=peakOut;
    result.raw_fault_contrast=contrastRaw;
    result.fused_fault_contrast=contrastOut;
    fprintf('CWRU %s, RPM %.0f, expected %s %.2f Hz, raw periodicity peak %.2f Hz (contrast %.2f), fused %.2f Hz (contrast %.2f)\n', ...
        stem,rpm,faultName,expected,peakRaw,contrastRaw,peakOut,contrastOut);
    plot_result(tw,f,W,Sf,St,Wout,outdir,[1000 min(4500,fs/2)],[]);
end
fid=fopen(fullfile(outdir,'result.json'),'w');
assert(fid>0); fprintf(fid,'%s\n',jsonencode(result)); fclose(fid);
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

function plot_result(tw,f,W,Sf,St,Wout,outdir,ylimHz,Wauto)
fig=figure('Visible','off','Color','w','Position',[30 30 1200 760]);
scale=0.035*max(abs(W(:)))+eps;
subplot(2,3,1); imagesc(tw,f,asinh(W/scale)); axis xy; ylim(ylimHz);
title('Original WVD'); xlabel('Time (s)'); ylabel('Frequency (Hz)');
subplot(2,3,2); imagesc(tw,f,Sf); axis xy; ylim(ylimHz); title('Frequency triplets'); xlabel('Time (s)');
subplot(2,3,3); imagesc(tw,f,St); axis xy; ylim(ylimHz); title('Time triplets'); xlabel('Time (s)');
subplot(2,3,4); imagesc(tw,f,asinh(Wout/scale)); axis xy; ylim(ylimHz);
title('Fused original WVD'); xlabel('Time (s)'); ylabel('Frequency (Hz)');
subplot(2,3,5); imagesc(tw,f,sqrt(max(Sf,0).*max(St,0))); axis xy; ylim(ylimHz);
title('Geometric fusion'); xlabel('Time (s)');
subplot(2,3,6);
if isempty(Wauto)
    plot(tw,sum(max(Wout,0),1)); ylabel('Positive WVD activity');
    title('Fused activity');
else
    imagesc(tw,f,asinh(Wauto/scale)); axis xy; ylim(ylimHz);
    title('Oracle self terms'); ylabel('Frequency (Hz)');
end
xlabel('Time (s)');
exportgraphics(fig,fullfile(outdir,'paper_figure.png'),'Resolution',300);
close(fig);
end
