function run_target_harmonic_diagnostic(windowID)
% Mechanism diagnostic; does not alter the production detector or selector.
addpath(pwd);
catalog=readtable('DIAGNOSTIC_WINDOWS.csv','TextType','string');
item=catalog(catalog.window_id==string(windowID),:);
assert(height(item)==1 && item.old_status=="NO_VALID_R");
mode=char(item.dataset); file=char(item.source_file); start=round(item.start_sample);
out=fullfile('results','target-harmonic-diagnostics',char(item.window_id));
if ~exist(out,'dir'), mkdir(out); end
diary(fullfile(out,'experiment.log')); clean=onCleanup(@() diary('off'));
if strcmp(mode,'xjtu')
    data=readmatrix(file); assert(size(data,1)==32768 && size(data,2)==2);
    x=double(data(start:start+4095,1)); fs=25600;
    p=struct('bands',[],'Lsec',.007,'hopSec',.0015,'spanHz',120, ...
        'sigmaHz',100,'excludeHz',350,'freqAvgHz',200,'freqThr',.10, ...
        'timeThr',.08,'activityThr',.005,'maxPairDelaySec',.12, ...
        'minPeakDistanceSec',.004);
    choice=struct('smoothHz',150,'lowerHz',1200,'upperHz',10000, ...
        'minDistanceHz',1000,'halfwidthHz',250,'cropMarginHz',600);
    phase=[];
else
    d=load(file,'Channel_1','Channel_2');fs0=200000;rawN=65536;
    assert(numel(d.Channel_1)>=start+rawN-1);
    encoder=estimate_encoder_phase(double(d.Channel_2(:)),fs0,1024);
    x=resample(double(d.Channel_1(start:start+rawN-1)),2,25);fs=16000;
    p=struct('bands',[],'Lsec',.006,'hopSec',.001,'spanHz',180, ...
        'sigmaHz',100,'excludeHz',400,'freqAvgHz',200,'freqThr',.10, ...
        'timeThr',.08,'activityThr',.005,'maxPairDelaySec',.08, ...
        'minPeakDistanceSec',.004);
    choice=struct('smoothHz',100,'lowerHz',1000,'upperHz',min(7500,.9*fs/2), ...
        'minDistanceHz',500,'halfwidthHz',200,'cropMarginHz',600);
end
assert(strcmp(char(item.target),'BPFO') || strcmp(char(item.target),'BPFI'));
theory=item.theoretical_target; unit=char(item.target_unit);
[W,f,t]=wvd(hilbert(x),fs); W=real(W);f=f(:);t=t(:);
if strcmp(mode,'ottawa')
    first=(start-1)/200000;
    phase=interp1(encoder.edge_times_s,encoder.edge_revolutions,t+first,'linear','extrap');
    assert(all(diff(phase)>0)); delta=1/(phase(end)-phase(1));
else, delta=fs/numel(x); end
df=median(diff(f)); profile=mean(abs(W),2);
smoothed=movmean(profile,max(3,round(choice.smoothHz/df)));
ranked=find_resonance_candidates(W,f,choice.smoothHz,choice.lowerHz, ...
    choice.upperHz,choice.minDistanceHz);
assert(numel(ranked)>=8,'Fewer than eight eligible resonance candidates');
ranked=ranked(1:8); assert(all(diff(ranked)~=0));
peakRows=table();comboRows=table();candidateRows=table();
for r=1:8
    center=ranked(r);
    candidateRows=[candidateRows;table(string(item.window_id),r,center, ...
        center-choice.halfwidthHz,center+choice.halfwidthHz, ...
        interp1(f,profile,center),interp1(f,smoothed,center), ...
        'VariableNames',{'window_id','rank','center_hz','lower_hz','upper_hz','raw_activity','smoothed_activity'})]; %#ok<AGROW>
end
plot_resonances(f,profile,smoothed,ranked,choice,item,out);
for R=2:4
    combinations=nchoosek(1:8,R);
    for ci=1:size(combinations,1)
        ranks=combinations(ci,:); centers=sort(ranked(ranks));
        bands=[centers-choice.halfwidthHz,centers+choice.halfwidthHz];
        p.bands=bands;
        keep=f>=max(0,min(bands(:,1))-choice.cropMarginHz) & ...
            f<=min(fs/2,max(bands(:,2))+choice.cropMarginHz);
        ff=f(keep); ww=W(keep,:);
        [Sf,St,Etime]=dual_detector_abs_multiband(ww,ff,t,p);
        fusion=sqrt(max(Sf,0).*max(St,0));
        M=(fusion>sqrt(p.freqThr*p.timeThr)) & (Etime>p.activityThr);
        Wout=ww.*M; selected=band_union(ff,bands);
        raw=sum(max(ww(selected,:),0),1)*median(diff(ff));
        fused=sum(max(Wout(selected,:),0),1)*median(diff(ff));
        if strcmp(mode,'ottawa')
            [~,~,~,axis,rawPower]=fault_evidence_order(raw,t,phase,theory);
            [~,~,~,~,power]=fault_evidence_order(fused,t,phase,theory);
        else
            [axis,rawPower]=periodogram_curve(raw,median(diff(t)));
            [~,power]=periodogram_curve(fused,median(diff(t)));
        end
        axis=axis(:);power=power(:);rawPower=rawPower(:);
        hv=false(1,3); reps=cell(1,3); oldValid=false;oldJ=NaN;
        for h=1:3
            expected=h*theory;
            [peaks,rep,status]=diagnostic_local_peaks(axis,power,expected,delta,unit,'original');
            hv(h)=strcmp(status,'VALID'); reps{h}=rep;
            for k=1:numel(peaks)
                v=peaks(k);
                peakRows=[peakRows;table(string(item.window_id),R,string(mat2str(ranks)), ...
                    h,expected,v.position,v.power,v.contrast,v.error,delta,v.Qe,v.Qc,v.J,v.valid, ...
                    'VariableNames',{'window_id','R','ranks','harmonic','theory','peak','power','contrast','error','resolution','Qe','Qc','J','valid'})]; %#ok<AGROW>
            end
            if h==1
                search=axis>=.8*expected & axis<=1.2*expected;
                background=background_mask(axis,search,unit);
                [oldPower,i]=max(power(search));places=axis(search);oldPeak=places(i);
                oldContrast=oldPower/(median(power(background))+eps);
                if strcmp(mode,'ottawa'), score=evaluate_band_count(R,char(item.target),expected,oldPeak,oldContrast,delta,1);
                else, score=evaluate_band_count(R,char(item.target),expected,oldPeak,oldContrast,fs,numel(x)); end
                oldValid=score.valid;oldJ=score.J;
            end
        end
        baseline=isequal(ranks,1:R);fund=hv(1);two=fund&&(hv(2)||hv(3));three=all(hv);
        repPeak=NaN;repContrast=NaN;repJ=NaN;repError=NaN;
        if fund
            repPeak=reps{1}.position;repContrast=reps{1}.contrast;
            repJ=reps{1}.J;repError=reps{1}.error;
        end
        comboRows=[comboRows;table(string(item.window_id),R,string(mat2str(ranks)), ...
            baseline,oldValid,oldJ,hv(1),hv(2),hv(3),two,three, ...
            repPeak,repContrast,repError,repJ, ...
            'VariableNames',{'window_id','R','ranks','baseline','old_valid','old_J', ...
            'fundamental_valid','second_harmonic_valid','third_harmonic_valid', ...
            'two_line_valid','three_line_valid','selected_peak','selected_contrast','selected_error','selected_J'})]; %#ok<AGROW>
        if baseline
            plot_spectra(axis,rawPower,power,theory,delta,unit,R,ranks,item,out);
        end
    end
end
writetable(candidateRows,fullfile(out,'RESONANCE_CANDIDATES_TOP8.csv'));
writetable(peakRows,fullfile(out,'TARGET_HARMONIC_PEAKS.csv'));
writetable(comboRows,fullfile(out,'BAND_COMBINATION_DIAGNOSTICS.csv'));
summary=struct('window_id',char(item.window_id),'WVD_calls',1, ...
    'combinations',height(comboRows),'baseline_old_valid',any(comboRows.old_valid(comboRows.baseline)), ...
    'baseline_new_valid',any(comboRows.fundamental_valid(comboRows.baseline)), ...
    'extended_any_valid',any(comboRows.fundamental_valid), ...
    'extended_with_rank_5_to_8_valid',any(comboRows.fundamental_valid & contains(comboRows.ranks,{'5','6','7','8'})));
fid=fopen(fullfile(out,'summary.json'),'w');fprintf(fid,'%s\n',jsonencode(summary));fclose(fid);
fprintf('DIAGNOSTIC_PASS %s %d combinations\n',item.window_id,height(comboRows));
end

function b=background_mask(axis,search,unit)
if strcmp(unit,'order'),b=axis>=.5 & axis<=12 & ~search;
else,b=axis>=50 & axis<=200 & ~search;end
end

function plot_resonances(f,raw,smooth,ranked,choice,item,out)
fig=figure('Visible','off','Units','inches','Position',[0 0 13 6]);
plot(f,raw,'Color',[.5 .5 .5]);hold on;plot(f,smooth,'b','LineWidth',1.2);
for i=1:8
    xline(ranked(i),'r--',sprintf('%d',i));
    xline(ranked(i)-choice.halfwidthHz,':','Color',[.6 .6 .6]);
    xline(ranked(i)+choice.halfwidthHz,':','Color',[.6 .6 .6]);
end
xlim([choice.lowerHz choice.upperHz]);xlabel('WVD frequency (Hz)');ylabel('Mean |WVD|');
title(sprintf('%s resonance candidates: ranks 1-4 current, 5-8 diagnostic',item.window_id));
legend({'Raw activity','Smoothed activity'},'Location','best');grid on;
exportgraphics(fig,fullfile(out,'resonance-top8.png'),'Resolution',300);
exportgraphics(fig,fullfile(out,'resonance-top8.pdf'),'ContentType','vector');close(fig);
end

function plot_spectra(axis,raw,power,theory,delta,unit,R,ranks,item,out)
fig=figure('Visible','off','Units','inches','Position',[0 0 13 6]);
upper=min(max(axis),3.5*theory);shown=axis>=0 & axis<=upper;
plot(axis(shown),raw(shown),'Color',[.4 .4 .4]);hold on;
plot(axis(shown),power(shown),'Color',[0 .35 .7]);
for h=1:3
    expected=h*theory;
    if expected>max(axis),continue;end
    xline(expected,'r--',sprintf('%d×%s',h,item.target));
    [peaks,~,~]=diagnostic_local_peaks(axis,power,expected,delta,unit,'original');
    for k=1:numel(peaks)
        marker='x';if peaks(k).valid,marker='o';end
        plot(peaks(k).position,peaks(k).power,marker,'Color',[.1 .5 .15]);
    end
end
xlim([0 upper]);xlabel(['Repetition ' unit]);ylabel('Periodicity power (linear)');
title(sprintf('%s R=%d ranks=%s; circles valid, crosses invalid',item.window_id,R,mat2str(ranks)));
legend({'Original','Fused'},'Location','best');grid on;
exportgraphics(fig,fullfile(out,sprintf('spectrum-R%d.png',R)),'Resolution',300);
exportgraphics(fig,fullfile(out,sprintf('spectrum-R%d.pdf',R)),'ContentType','vector');close(fig);
end
