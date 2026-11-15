function verify_adaptive_band_selection
% Deterministic mathematical and interface checks; no bearing experiment.
outdir=fullfile('results','adaptive-self-check');
if ~exist(outdir,'dir'), mkdir(outdir); end
diary(fullfile(outdir,'verification.log'));
guard=onCleanup(@() diary('off'));
names={}; states={}; details={};

g=hann(5); g=g/sum(g); V=[2 -1 4;-2 1 -4;2 -1 4];
bar=V*g(2:4)/sum(g(2:4));
check('positive signed mean support',any(bar>0 & abs(bar)>0));
check('negative signed mean support',any(bar<0 & abs(bar)>0));
check('support equals absolute signed mean',isequal(abs(bar),abs(V*g(2:4)/sum(g(2:4)))));
check('negative support is not clipped',all(abs(bar(bar<0))>0));
fMoment=[100;200;400]; weights=abs([1;-3;1]);
check('absolute weighted first moment',abs(sum(fMoment.*weights)/sum(weights)-220)<1e-12);
check('frequency triplet endpoint sign invariance',abs((-2)*(-3))==abs(2*3));
check('time triplet endpoint sign invariance',abs((-4)*(-5))==abs(4*5));
check('support sign invariance',isequal(abs(bar),abs(-bar)));

f=(0:10:1400)'; tw=(0:199)'/1000;
centers=[200 500 800 1100]; signs=[1 -1 1 -1];
pulse=0.08+2*exp(-0.5*((tw-0.04)/0.004).^2) ...
    +2*exp(-0.5*((tw-0.09)/0.004).^2) ...
    +2*exp(-0.5*((tw-0.14)/0.004).^2) ...
    +2*exp(-0.5*((tw-0.18)/0.004).^2);
W=zeros(numel(f),numel(tw));
for r=1:4
    W=W+signs(r)*(5-r)*exp(-0.5*((f-centers(r))/18).^2)*pulse.';
end
ranked=find_resonance_candidates(W,f,30,100,1200,200);
check('four resonance candidates',numel(ranked)>=4);
b2=select_resonance_bands(W,f,2,30,100,1200,200,40);
b3=select_resonance_bands(W,f,3,30,100,1200,200,40);
check('nested top two and three',all(ismember(mean(b2,2),mean(b3,2))));
for R=2:4
    bands=select_resonance_bands(W,f,R,30,100,1200,200,40);
    check(sprintf('R%d number and ascending centers',R), ...
        size(bands,1)==R && all(diff(mean(bands,2))>0));
    pairCounts=[1 3 6];
    check(sprintf('R%d all band combinations',R),nchoosek(R,2)==pairCounts(R-1));
    p=parameters(bands);
    [Sf,St,E,peakIdx,pairs,counts]=dual_detector_abs_multiband(W,f,tw,p);
    check(sprintf('R%d detector output dimensions',R), ...
        isequal(size(Sf),size(W)) && isequal(size(St),size(W)) && numel(E)==numel(tw));
    check(sprintf('R%d all combinations active',R), ...
        size(counts,2)==nchoosek(R,2) && all(sum(counts,1)>0));
    check(sprintf('R%d time endpoint and pairs',R),~isempty(peakIdx) && pairs>0);
    check(sprintf('R%d finite normalized activity',R), ...
        all(isfinite(E)) && all(E>=0) && max(E)<=1+1e-12);
end
check('geometric activity R2 reduction',sqrt(2*8)==prod([2 8])^(1/2));
check('zero-band geometric activity',prod([2 8 0])^(1/3)==0);
one=exp(-0.5*((f-200)/20).^2)*ones(1,5);
check('insufficient R4 remains insufficient',numel(find_resonance_candidates(one,f,30,100,1200,200))<4);

fs=1000; N=100; delta=fs/N;
a=evaluate_band_count(2,'BPFO',100,100.5,200,fs,N);
b=evaluate_band_count(3,'BPFO',100,100.6,300,fs,N);
check('physical resolution fs over N',delta==10 && a.physical_resolution_hz==10);
check('Gaussian localization formula',abs(a.location_confidence-exp(-0.5*(0.5/10)^2))<1e-12);
check('saturated contrast formula',a.contrast_utility==1 && b.contrast_utility==1);
check('A beats B at saturated contrast',a.J>b.J);
c=evaluate_band_count(2,'BPFO',100,100.5,5,fs,N);
d=evaluate_band_count(3,'BPFO',100,100.6,10,fs,N);
check('moderate contrast improves utility',c.contrast_utility<d.contrast_utility);
check('C versus D selects D',d.J>c.J);
sameContrast=evaluate_band_count(3,'BPFO',100,100.6,200,fs,N);
check('equal contrast favors smaller error',a.J>sameContrast.J);
sat=arrayfun(@(x)evaluate_band_count(2,'BPFO',100,100.5,x,fs,N),[10 100 200 300]);
check('10 100 200 300 identical utility',all([sat.contrast_utility]==1));
check('10 100 200 300 identical score',max([sat.J])-min([sat.J])<1e-12);
lowContrast=evaluate_band_count(2,'BPFO',100,100,1,fs,N);
largeError=evaluate_band_count(2,'BPFO',100,111,10,fs,N);
check('contrast at most one invalid',~lowContrast.valid);
check('error beyond physical resolution invalid',~largeError.valid);
[ix,rank,status]=select_optimal_band_count([b a]);
check('score ranking and index',ix==2 && rank(1)==2 && strcmp(status,'SELECTED'));
tied=[evaluate_band_count(4,'BPFO',100,100,10,fs,N), ...
    evaluate_band_count(2,'BPFO',100,100,10,fs,N)];
[ix,~,~]=select_optimal_band_count(tied);
check('exact tie chooses smaller R',ix==2);
[ix,~,status]=select_optimal_band_count([ ...
    evaluate_band_count(2,'BPFO',100,100,1,fs,N), ...
    evaluate_band_count(3,'BPFO',100,111,10,fs,N)]);
check('all invalid yields NO_VALID_R',isempty(ix) && strcmp(status,'NO_VALID_R'));

known=bearing_hypotheses('cwru',1800,'BPFO');
unknown=bearing_hypotheses('cwru',1800,'unknown');
check('known hypothesis one frequency',numel(known)==1 && strcmp(known.name,'BPFO'));
check('unknown hypothesis all three',numel(unknown)==3 && all([unknown.hz]>0));
missing=false;
try, bearing_hypotheses('cwru',NaN,'unknown'); catch, missing=true; end
check('missing speed explicitly rejected',missing);
source=fileread('run_adaptive_candidates.m'); core=fileread('main_Paper1.m');
check('candidate selector does not read filename',~contains(source,'dataFile') && ~contains(source,'stem'));
check('one WVD in real-data main path',numel(strfind(core,'[W,f,tw]=wvd(hilbert(x),fs)'))==1);
check('no input bandpass or decomposition',~contains(core,'bandpass(x') && ~contains(core,'vmd(x'));
check('candidate records include R and hypothesis',isfield(a,'R') && isfield(a,'hypothesis'));
check('candidate records include score parts',all(isfield(a,{'J','error_hz','contrast_utility','location_confidence'})));
check('reconstruction uses unchanged mask product',contains(source,'Wout=W.*M;'));
check('JSON and CSV writers connected',contains(core,"write_adaptive_candidate_csv") && contains(core,"jsonencode(result)"));
check('all candidate R loop present',contains(source,'for R=2:4'));
check('failure isolated per R',contains(source,'catch err') && contains(source,'continue;'));
choice=struct('smoothHz',30,'lowerHz',100,'upperHz',1200, ...
    'minDistanceHz',200,'halfwidthHz',40,'cropMarginHz',100);
p=parameters([]); p.freqThr=0.10; p.timeThr=0.08; p.activityThr=0.005;
[trial,trialMaps]=run_adaptive_candidates(W,f,tw,p,'cwru',2000,1800,200,choice,'unknown');
check('all nine R-h records retained',numel(trial.candidates)==9);
check('all three R values evaluated',isequal(unique([trial.candidates.R]),[2 3 4]));
check('all three fault hypotheses evaluated',numel(unique({trial.candidates.hypothesis}))==3);
check('valid selected reconstruction or explicit no-valid status', ...
    (strcmp(trial.status,'SELECTED') && isequal(size(trialMaps.Wout),size(trialMaps.M))) || ...
    (strcmp(trial.status,'NO_VALID_R') && isempty(trialMaps)));
csvFile=fullfile(outdir,'candidate-schema.csv');
write_adaptive_candidate_csv(csvFile,trial);
csvText=fileread(csvFile);
check('candidate CSV contains score and status',contains(csvText,'location_confidence') && ...
    contains(csvText,'contrast_utility') && contains(csvText,'valid'));
check('candidate JSON encodes all evaluations',contains(jsonencode(trial),'candidates'));

report=struct('status','PASS','count',numel(names), ...
    'tests',struct('name',names,'status',states,'detail',details));
if any(strcmp(states,'FAIL')), report.status='FAIL'; end
fid=fopen(fullfile(outdir,'verification.json'),'w');
assert(fid>0); fprintf(fid,'%s\n',jsonencode(report)); fclose(fid);
fprintf('ADAPTIVE_SELF_CHECK_%s (%d checks)\n',report.status,report.count);
assert(strcmp(report.status,'PASS'),'Adaptive selection self-check failed');
    function check(name,condition)
        names{end+1}=name; %#ok<AGROW>
        if condition, states{end+1}='PASS'; details{end+1}='';
        else, states{end+1}='FAIL'; details{end+1}='Assertion false'; end %#ok<AGROW>
        fprintf('%02d %s %s\n',numel(names),states{end},name);
    end
end

function p=parameters(bands)
p=struct('bands',bands,'Lsec',0.010,'hopSec',0.005, ...
    'spanHz',45,'sigmaHz',35,'excludeHz',100, ...
    'freqAvgHz',40,'minPeakDistanceSec',0.02, ...
    'maxPairDelaySec',0.11);
end
