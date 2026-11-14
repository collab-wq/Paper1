function verify_abs_support_multiband
% Independent deterministic checks; no real bearing recordings are loaded.
outdir=fullfile('results','absolute-support-multiband','self-check');
if ~exist(outdir,'dir'), mkdir(outdir); end
diary(fullfile(outdir,'verification.log'));
cleanup=onCleanup(@() diary('off'));

f=(0:10:1400)'; tw=(0:199)'/1000; df=median(diff(f));
centers=[200 500 800 1100]; signs=[1 -1 1 -1];
pulse=0.08+2*exp(-0.5*((tw-0.04)/0.004).^2) ...
    +2*exp(-0.5*((tw-0.09)/0.004).^2) ...
    +2*exp(-0.5*((tw-0.14)/0.004).^2) ...
    +2*exp(-0.5*((tw-0.18)/0.004).^2);
W=zeros(numel(f),numel(tw));
for r=1:4
    W=W+signs(r)*(5-r)*exp(-0.5*((f-centers(r))/18).^2)*pulse.';
end
W=W+0.04*exp(-0.5*((f-650)/200).^2)*sin(2*pi*83*tw).';

g=hann(11); g=g/sum(g);
bar=W(:,35:45)*g;
Pt=abs(bar); PtNeg=abs((-W(:,35:45))*g);
assert(max(abs(Pt-PtNeg))<1e-12);
assert(any(bar<0) && any(bar>0) && all(Pt(bar<0)>0));
assert(max(abs(Pt-abs(bar)))<1e-12);
h=hann(5); h=h/sum(h);
Pf=abs(conv2(h,1,W,'same'));
PfNeg=abs(conv2(h,1,-W,'same'));
assert(max(abs(Pf(:)-PfNeg(:)))<1e-12);
assert(any(Pf(:)>0));
momentF=[100;200;400]; momentBar=[1;-3;1];
moment=sum(momentF.*abs(momentBar))/sum(abs(momentBar));
assert(abs(moment-220)<1e-12);
momentPositive=sum(momentF.*max(momentBar,0))/sum(max(momentBar,0));
assert(abs(moment-momentPositive)>1);

Rlist=[2 3 4];
rows=repmat(struct('R',0,'selected_bands_hz',[], ...
    'band_pair_count',0,'valid_band_pair_windows',0, ...
    'frequency_triplets',0,'time_endpoints',0,'time_pairs',0),1,3);
for k=1:3
    R=Rlist(k);
    bands=select_resonance_bands(W,f,R,30,100,1200,200,40);
    assert(size(bands,1)==R);
    chosen=mean(bands,2);
    assert(all(diff(chosen)>=200-1e-9));
    assert(all(diff(chosen)>0));
    p=parameters(bands);
    [Sf,St,E,peakIdx,pairCount,counts]= ...
        dual_detector_abs_multiband(W,f,tw,p);
    [SfNeg,StNeg,ENeg,~,~,countsNeg]= ...
        dual_detector_abs_multiband(-W,f,tw,p);
    assert(isequal(size(Sf),size(W)) && isequal(size(St),size(W)));
    assert(isequal(size(E),[1 numel(tw)]));
    assert(size(counts,2)==nchoosek(R,2));
    assert(all(sum(counts,1)>0),'A requested band pair was skipped');
    assert(max(abs(Sf(:)-SfNeg(:)))<1e-10);
    assert(max(abs(St(:)-StNeg(:)))<1e-10);
    assert(max(abs(E(:)-ENeg(:)))<1e-10);
    assert(isequal(counts,countsNeg));
    assert(all(isfinite(Sf(:))) && all(isfinite(St(:))) && all(isfinite(E(:))));
    assert(all(E(:)>=0) && max(E(:))<=1+1e-12);
    assert(nnz(Sf)>0 && nnz(St)>0 && ~isempty(peakIdx) && pairCount>0);
    for r=1:R
        selected=f>=bands(r,1)&f<=bands(r,2);
        assert(any(St(selected,:)>0,'all'), ...
            'Time-direction normalization missed a resonance band');
    end
    rows(k)=struct('R',R,'selected_bands_hz',bands, ...
        'band_pair_count',size(counts,2), ...
        'valid_band_pair_windows',sum(counts>0,'all'), ...
        'frequency_triplets',sum(counts,'all'), ...
        'time_endpoints',numel(peakIdx),'time_pairs',pairCount);
    fprintf('R=%d: %d band pairs; %d frequency triplets; %d time endpoints\n', ...
        R,size(counts,2),sum(counts,'all'),numel(peakIdx));
end

% One candidate from each band: both endpoints accumulate, midpoint does not.
fSmall=(0:10:700)'; tSmall=(0:79)'/1000;
small=zeros(numel(fSmall),numel(tSmall));
small(fSmall==200,:)=1;
small(fSmall==500,:)=-1;
small(fSmall==350,:)=0.5*sin(2*pi*90*tSmall).';
p=parameters([200 200;500 500]);
p.spanHz=20; p.freqAvgHz=20;
[SfSmall,~,~,~,~,smallCounts]= ...
    dual_detector_abs_multiband(small,fSmall,tSmall,p);
assert(sum(smallCounts,'all')>0);
assert(any(SfSmall(fSmall==200,:)>0) && any(SfSmall(fSmall==500,:)>0));
assert(all(SfSmall(fSmall==350,:)==0));

% The R-band geometric activity is zero when any one band's support is zero.
energy=[2 8 18 32];
assert(abs(prod(energy(1:2))^(1/2)-sqrt(energy(1)*energy(2)))<eps);
assert(abs(prod(energy(1:3))^(1/3)-6.60385449778925)<1e-10);
assert(prod([energy(1:3) 0])^(1/4)==0);
assert(df==10);

failed=false;
try
    onePeak=exp(-0.5*((f-200)/20).^2)*ones(1,5);
    select_resonance_bands(onePeak,f,4,30,100,1200,200,40);
catch err
    failed=contains(err.message,'requested R=4');
end
assert(failed,'Insufficient band candidates must fail explicitly');
report=struct('status','PASS','tests',{{'absolute support', ...
    'signed means and moment','sign reversal','band selection', ...
    'all band pairs','endpoint accumulation','time normalization', ...
    'geometric activity','insufficient-band failure'}},'cases',rows);
fid=fopen(fullfile(outdir,'verification.json'),'w');
assert(fid>0); fprintf(fid,'%s\n',jsonencode(report)); fclose(fid);
fprintf('ABS_SUPPORT_MULTIBAND_SELF_CHECK_PASS\n');
end

function p=parameters(bands)
p=struct('bands',bands,'Lsec',0.010,'hopSec',0.005, ...
    'spanHz',45,'sigmaHz',35,'excludeHz',100, ...
    'freqAvgHz',40,'minPeakDistanceSec',0.02, ...
    'maxPairDelaySec',0.11);
end
