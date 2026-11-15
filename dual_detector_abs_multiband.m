function [Sf,St,Etime,peakIdx,pairCount,bandPairCounts]=dual_detector_abs_multiband(W,f,tw,p)
F=numel(f); T=numel(tw); df=median(diff(f)); dt=median(diff(tw));
hopN=max(1,round(p.hopSec/dt)); centers=unique([1:hopN:T,T]); Q=numel(centers);
R=size(p.bands,1); bandPairs=nchoosek(1:R,2);
raw=zeros(F,Q); activity=zeros(Q,1);
bandPairCounts=zeros(Q,size(bandPairs,1));
for q=1:Q
    idx=find(abs(tw-tw(centers(q)))<=p.Lsec/2);
    if numel(idx)<5, continue; end
    g=hann(numel(idx)); g=g(:)/(sum(g)+eps);
    Wq=W(:,idx); bar=Wq*g;
    sd=sqrt(max((Wq.^2)*g-bar.^2,0)); pos=abs(bar);
    mu=nan(R,1); energy=zeros(R,1);
    for r=1:R
        ii=find(f>=p.bands(r,1)&f<=p.bands(r,2));
        mass=sum(pos(ii)); energy(r)=mass*df;
        if mass>1e-12, mu(r)=sum(f(ii).*pos(ii))/mass; end
    end
    activity(q)=prod(energy)^(1/R);
    if any(~isfinite(mu)), continue; end
    local=zeros(F,1); floorSd=0.01*max(sd)+eps;
    for pair=1:size(bandPairs,1)
        r=bandPairs(pair,1); s=bandPairs(pair,2);
        ci=find(f>=p.bands(r,1)&f<=p.bands(r,2)&abs(f-mu(r))<=p.spanHz);
        cj=find(f>=p.bands(s,1)&f<=p.bands(s,2)&abs(f-mu(s))<=p.spanHz);
        for ai=1:numel(ci)
            i=ci(ai); if pos(i)<=0, continue; end
            wi=exp(-0.5*((f(i)-mu(r))/p.sigmaHz)^2);
            for aj=1:numel(cj)
                j=cj(aj);
                if pos(j)<=0 || abs(f(i)-f(j))<=p.excludeHz, continue; end
                wj=exp(-0.5*((f(j)-mu(s))/p.sigmaHz)^2);
                vm=((f(i)+f(j))/2-f(1))/df+1; k0=floor(vm);
                if k0<1 || k0>=F, continue; end
                frac=vm-k0;
                meanMid=(1-frac)*bar(k0)+frac*bar(k0+1);
                stdMid=(1-frac)*sd(k0)+frac*sd(k0+1);
                c=wi*wj*pos(i)*pos(j)*stdMid^2/(stdMid+abs(meanMid)+floorSd);
                local(i)=local(i)+c; local(j)=local(j)+c;
                bandPairCounts(q,pair)=bandPairCounts(q,pair)+1;
            end
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
Pf=abs(Wfreq);
selected=band_union(f,p.bands);
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
for r=1:R
    ii=f>=p.bands(r,1)&f<=p.bands(r,2);
    bandMax=max(spread(ii,:),[],'all');
    if bandMax>0, St(ii,:)=spread(ii,:)/(bandMax+eps); end
end
end
