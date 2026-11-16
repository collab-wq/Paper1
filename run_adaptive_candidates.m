function [summary,selectedMaps]=run_adaptive_candidates(Wfull,ffull,tw,p,mode,fs,rpm,N,choice,requestedHypothesis)
% Evaluate R=2,3,4 for one target supplied by experiment metadata.
hypotheses=bearing_hypotheses(mode,rpm,requestedHypothesis);
assert(numel(hypotheses)==1 && ismember(hypotheses.name,{'BPFO','BPFI'}), ...
    'Adaptive R selection requires one BPFO or BPFI target');
rankedCenters=find_resonance_candidates(Wfull,ffull,choice.smoothHz, ...
    choice.lowerHz,choice.upperHz,choice.minDistanceHz);
candidates=struct([]);
selectedMaps=[];
for R=2:4
    if numel(rankedCenters)<R
        for h=1:numel(hypotheses)
            item=blank_record(R,hypotheses(h),fs,N);
            item.reason=sprintf('INSUFFICIENT_BANDS_%d_FOUND',numel(rankedCenters));
            item.available_band_count=numel(rankedCenters);
            candidates=append_record(candidates,item);
        end
        continue;
    end
    centers=sort(rankedCenters(1:R));
    bands=[centers-choice.halfwidthHz,centers+choice.halfwidthHz];
    try
        [records,~]=run_one_band_count(Wfull,ffull,tw,p,mode,fs,N, ...
            bands,choice,hypotheses);
        for h=1:numel(records)
            candidates=append_record(candidates,records(h));
        end
    catch err
        for h=1:numel(hypotheses)
            item=blank_record(R,hypotheses(h),fs,N);
            item.bands_hz=bands;
            item.reason=['R_EXECUTION_FAILED: ' regexprep(err.message,'[\r\n]+',' ')];
            candidates=append_record(candidates,item);
        end
    end
end
[bestIndex,rankedIndices,status]=select_optimal_band_count(candidates);
summary=struct('status',status,'mode',char(mode), ...
    'hypothesis_mode',char(requestedHypothesis), ...
    'target_fault_type',char(requestedHypothesis), ...
    'target_hypothesis',hypotheses.name,'fs_hz',fs, ...
    'signal_samples',N,'observation_s',N/fs, ...
    'physical_resolution_hz',fs/N, ...
    'available_resonance_peaks_hz',rankedCenters, ...
    'hypotheses',hypotheses,'candidates',candidates, ...
    'ranked_candidate_indices',rankedIndices, ...
    'selected_R',[],'selected_hypothesis','', ...
    'selected_score',NaN);
if isempty(bestIndex), return; end
chosen=candidates(bestIndex);
summary.selected_R=chosen.R;
summary.selected_hypothesis=chosen.hypothesis;
summary.selected_score=chosen.J;
summary.selected_candidate_index=bestIndex;
% Retain full arrays only for the winner. This recomputes its detector,
% never its WVD, and avoids retaining three large WVD result sets.
[recomputed,selectedMaps]=run_one_band_count(Wfull,ffull,tw,p,mode,fs,N, ...
    chosen.bands_hz,choice,hypotheses);
matched=recomputed(strcmp({recomputed.hypothesis},chosen.hypothesis));
assert(numel(matched)==1 && abs(matched.J-chosen.J)<=1e-10, ...
    'Selected candidate changed during reconstruction');
end

function [records,maps]=run_one_band_count(Wfull,ffull,tw,p,mode,fs,N,bands,choice,hypotheses)
p.bands=bands; R=size(bands,1);
if strcmp(mode,'paderborn') || strcmp(mode,'xjtu')
    keep=ffull>=max(0,min(bands(:,1))-choice.cropMarginHz) & ...
        ffull<=min(fs/2,max(bands(:,2))+choice.cropMarginHz);
    W=Wfull(keep,:); f=ffull(keep);
else
    W=Wfull; f=ffull;
end
df=median(diff(f)); dt=median(diff(tw));
[Sf,St,Etime,peakIdx,timePairs,frequencyPairs]= ...
    dual_detector_abs_multiband(W,f,tw,p);
Mf=(Sf>p.freqThr) & (Etime>p.activityThr);
Mt=St>p.timeThr;
fusion=sqrt(max(Sf,0).*max(St,0));
fusionThreshold=sqrt(p.freqThr*p.timeThr);
M=(fusion>fusionThreshold) & (Etime>p.activityThr);
Wout=W.*M;
selected=band_union(f,bands);
rawActivity=sum(max(W(selected,:),0),1)*df;
fusedActivity=sum(max(Wout(selected,:),0),1)*df;
[rawDominant,rawDominantContrast]=dominant_periodicity(rawActivity,dt);
[fusedDominant,fusedDominantContrast]=dominant_periodicity(fusedActivity,dt);
records=repmat(blank_record(R,hypotheses(1),fs,N),1,numel(hypotheses));
for h=1:numel(hypotheses)
    hypothesis=hypotheses(h);
    [rawPeak,rawContrast]=fault_evidence(rawActivity,dt,hypothesis.hz);
    [fusedPeak,fusedContrast]=fault_evidence(fusedActivity,dt,hypothesis.hz);
    record=evaluate_band_count(R,hypothesis.name,hypothesis.hz, ...
        fusedPeak,fusedContrast,fs,N);
    record=complete_record(record,bands,frequencyPairs,peakIdx,timePairs, ...
        M,rawPeak,rawContrast,rawDominant,rawDominantContrast, ...
        fusedDominant,fusedDominantContrast);
    records(h)=record;
end
maps=struct('W',W,'f',f,'Sf',Sf,'St',St,'Mf',Mf,'Mt',Mt, ...
    'M',M,'Wout',Wout,'fusion',fusion,'Etime',Etime, ...
    'raw_activity',rawActivity,'fused_activity',fusedActivity, ...
    'time_endpoints',tw(peakIdx),'time_pairs',timePairs, ...
    'frequency_pair_counts',frequencyPairs);
end

function item=blank_record(R,hypothesis,fs,N)
item=evaluate_band_count(R,hypothesis.name,hypothesis.hz,NaN,NaN,fs,N);
item.available_band_count=NaN;
item.bands_hz=[];
item.valid_band_pair_windows=NaN;
item.frequency_triplet_count=NaN;
item.time_endpoint_count=NaN;
item.time_pair_count=NaN;
item.raw_target_peak_hz=NaN;
item.raw_target_contrast=NaN;
item.unlabelled_raw_peak_hz=NaN;
item.unlabelled_raw_contrast=NaN;
item.unlabelled_fused_peak_hz=NaN;
item.unlabelled_fused_contrast=NaN;
item.retained_pixel_fraction=NaN;
end

function item=complete_record(item,bands,frequencyPairs,peakIdx,timePairs, ...
    M,rawPeak,rawContrast,rawDominant,rawDominantContrast, ...
    fusedDominant,fusedDominantContrast)
item.available_band_count=size(bands,1);
item.bands_hz=bands;
item.valid_band_pair_windows=sum(frequencyPairs>0,'all');
item.frequency_triplet_count=sum(frequencyPairs,'all');
item.time_endpoint_count=numel(peakIdx);
item.time_pair_count=timePairs;
item.raw_target_peak_hz=rawPeak;
item.raw_target_contrast=rawContrast;
item.unlabelled_raw_peak_hz=rawDominant;
item.unlabelled_raw_contrast=rawDominantContrast;
item.unlabelled_fused_peak_hz=fusedDominant;
item.unlabelled_fused_contrast=fusedDominantContrast;
item.retained_pixel_fraction=nnz(M)/numel(M);
end

function records=append_record(records,item)
if isempty(records), records=item;
else, records(end+1)=item; end
end
