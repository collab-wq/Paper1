function verify_target_informed_selection
% Deterministic checks for one-target R ranking; no bearing data required.
outdir=fullfile('results','target-informed-self-check');
if ~exist(outdir,'dir'), mkdir(outdir); end
diary(fullfile(outdir,'verification.log'));
guard=onCleanup(@() diary('off'));
names={}; passed=[];
fs=12000; N=2048; delta=fs/N;
a=evaluate_band_count(2,'BPFO',100,100.2,200,fs,N);
b=evaluate_band_count(3,'BPFO',100,101.0,300,fs,N);
c=evaluate_band_count(4,'BPFO',100,100.4,10,fs,N);
verify('same target for all R',numel(unique({a.hypothesis,b.hypothesis,c.hypothesis}))==1);
verify('physical frequency resolution',abs(a.physical_resolution_hz-delta)<1e-12);
verify('location error changes J',a.J>b.J && abs(b.error_hz-1)<1e-12);
verify('contrast saturation',a.contrast_utility==1 && b.contrast_utility==1);
sat200=evaluate_band_count(2,'BPFO',100,100.2,200,fs,N);
sat300=evaluate_band_count(2,'BPFO',100,100.2,300,fs,N);
verify('200 versus 300 has no extra benefit', ...
    sat200.J==sat300.J);
one=[a b c];
[ix,rank,status]=select_optimal_band_count(one);
verify('three R choose target-only J maximum',strcmp(status,'SELECTED') && ...
    ix==1 && numel(rank)==3);
other=evaluate_band_count(3,'BPFI',150,150,300,fs,N);
mixedRejected=false;
try, select_optimal_band_count([a other c]);
catch, mixedRejected=true; end
verify('other fault strong peak cannot enter target ranking',mixedRejected);
[ix,~,status]=select_optimal_band_count([ ...
    evaluate_band_count(2,'BPFO',100,100,1,fs,N), ...
    evaluate_band_count(3,'BPFO',100,110,10,fs,N), ...
    evaluate_band_count(4,'BPFO',100,110,10,fs,N)]);
verify('no valid R',isempty(ix) && strcmp(status,'NO_VALID_R'));
tied=arrayfun(@(R)evaluate_band_count(R,'BPFO',100,100,10,fs,N),[4 3 2]);
[ix,~,~]=select_optimal_band_count(tied);
verify('exact tie favors smaller R',ix==3);
wrongCount=false;
try, select_optimal_band_count([a b]);
catch, wrongCount=true; end
verify('missing R rejected',wrongCount);

dt=0.001; t=(0:1023)*dt;
activity=2+cos(2*pi*100*t)+0.3*cos(2*pi*150*t);
[peak,contrast]=fault_evidence(activity,dt,100);
[peakOther,~]=fault_evidence(activity+10*cos(2*pi*150*t),dt,100);
verify('local measured peak near target',peak>80 && peak<120 && contrast>1);
verify('unrelated strong peak does not move target peak',abs(peak-peakOther)<1e-12);
[p2,c2]=fault_evidence(activity,dt,100);
[p3,c3]=fault_evidence(activity+10*cos(2*pi*150*t),dt,100);
[p4,c4]=fault_evidence(2+cos(2*pi*104*t),dt,100);
targetScores=[evaluate_band_count(2,'BPFO',100,p2,c2,1000,numel(t)), ...
    evaluate_band_count(3,'BPFO',100,p3,c3,1000,numel(t)), ...
    evaluate_band_count(4,'BPFO',100,p4,c4,1000,numel(t))];
[pickBefore,~,~]=select_optimal_band_count(targetScores);
targetScores(2)=evaluate_band_count(3,'BPFO',100,p2,c2,1000,numel(t));
[pickAfter,~,~]=select_optimal_band_count(targetScores);
verify('strong unrelated peak does not change R decision',pickBefore==pickAfter);
[moved,~]=fault_evidence(2+cos(2*pi*107*t),dt,100);
verify('target-window peak movement measured',abs(moved-100)>abs(peak-100));

revs=(0:1023)'/64; times=(0:1023)'/1024;
orderActivity=1+cos(2*pi*3.57*revs);
[~,~,deltaOrder]=fault_evidence_order(orderActivity,times,revs,3.57);
verify('Ottawa resolution uses revolutions', ...
    abs(deltaOrder-1/(revs(end)-revs(1)))<1e-12);
verify('Ottawa resolution differs from fs over N',abs(deltaOrder-delta)>1);

f=(0:10:1400)'; tw=(0:199)'/1000;
centers=[200 500 800 1100]; W=zeros(numel(f),numel(tw));
for r=1:4
    W=W+(5-r)*exp(-0.5*((f-centers(r))/18).^2) ...
        *(1+cos(2*pi*40*tw)).';
end
p=struct('bands',[],'Lsec',.01,'hopSec',.005,'spanHz',45, ...
    'sigmaHz',35,'excludeHz',100,'freqAvgHz',40, ...
    'minPeakDistanceSec',.02,'maxPairDelaySec',.11, ...
    'freqThr',.1,'timeThr',.08,'activityThr',.005);
choice=struct('smoothHz',30,'lowerHz',100,'upperHz',1200, ...
    'minDistanceHz',200,'halfwidthHz',40,'cropMarginHz',100);
[s1,~]=run_adaptive_candidates(W,f,tw,p,'cwru',2000,1800,200,choice,'BPFO');
[s2,~]=run_adaptive_candidates(W,f,tw,p,'cwru',2000,1800,200,choice,'BPFI');
verify('three BPFO candidate records',numel(s1.candidates)==3 && ...
    all(strcmp({s1.candidates.hypothesis},'BPFO')));
verify('three BPFI candidate records',numel(s2.candidates)==3 && ...
    all(strcmp({s2.candidates.hypothesis},'BPFI')));
verify('target does not alter detector pair counts', ...
    isequaln([s1.candidates.frequency_triplet_count], ...
    [s2.candidates.frequency_triplet_count]));
verify('target does not alter selected bands per R', ...
    all(arrayfun(@(k)isequal(s1.candidates(k).bands_hz, ...
    s2.candidates(k).bands_hz),1:3)));
unknownRejected=false;
try, run_adaptive_candidates(W,f,tw,p,'cwru',2000,1800,200,choice,'unknown');
catch, unknownRejected=true; end
verify('unknown target rejected',unknownRejected);

matlabMain=fileread('main_Paper1.m');
verify('single WVD call unchanged',numel(strfind(matlabMain, ...
    '[W,f,tw]=wvd(hilbert(x),fs)'))==1);
verify('fusion reconstruction unchanged',contains(fileread('run_adaptive_candidates.m'), ...
    'Wout=W.*M;') && contains(fileread('run_adaptive_order_candidates.m'), ...
    'Wout=W.*M;'));
verify('CWRU target map',all(arrayfun(@(id)strcmp( ...
    bearing_target_metadata('cwru',id),'BPFI'),[105 106 107])) && ...
    all(arrayfun(@(id)strcmp(bearing_target_metadata('cwru',id),'BPFO'), ...
    [130 131 132 144 145 146 156 158 159])));
verify('Paderborn target map',isequal(bearing_target_metadata('paderborn','KB24'), ...
    {'BPFO','BPFI'}) && all(cellfun(@(id)strcmp( ...
    bearing_target_metadata('paderborn',id),'BPFO'),{'KA04','KA16'})) && ...
    all(cellfun(@(id)strcmp(bearing_target_metadata('paderborn',id),'BPFI'), ...
    {'KI21','KI17','KI04'})));
verify('Ottawa target map',all(cellfun(@(id)strcmp( ...
    bearing_target_metadata('ottawa',id),'BPFI'), ...
    {'I-A-2','I-B-2','I-C-2'})) && all(cellfun(@(id)strcmp( ...
    bearing_target_metadata('ottawa',id),'BPFO'), ...
    {'O-A-2','O-B-2','O-C-2'})));
verify('XJTU target map',all(cellfun(@(id)strcmp( ...
    bearing_target_metadata('xjtu',id),'BPFO'), ...
    {'Bearing1_2','Bearing1_3','Bearing2_2','Bearing3_1'})) && ...
    all(cellfun(@(id)strcmp(bearing_target_metadata('xjtu',id),'BPFI'), ...
    {'Bearing2_1','Bearing3_4'})));
verify('all four batches pass explicit targets', ...
    contains(fileread('matlab/run_cwru_full_batch.m'),"'auto',target") && ...
    contains(fileread('matlab/run_paderborn_full_batch.m'),"'auto',target") && ...
    contains(fileread('matlab/run_ottawa_batch.m'),"'auto',target") && ...
    contains(fileread('matlab/run_xjtu_lifetime_batch.m'),"'auto',target"));

result=struct('status','PASS','count',numel(names),'names',{names},'passed',passed);
if ~all(passed), result.status='FAIL'; end
fid=fopen(fullfile(outdir,'verification.json'),'w'); assert(fid>0);
fprintf(fid,'%s\n',jsonencode(result)); fclose(fid);
fprintf('TARGET_INFORMED_SELF_CHECK_%s (%d checks)\n',result.status,result.count);
assert(all(passed),'Target-informed selection self-check failed');
    function verify(name,condition)
        names{end+1}=name; passed(end+1)=logical(condition); %#ok<AGROW>
        fprintf('%s: %s\n',name,char(string(condition)));
    end
end
