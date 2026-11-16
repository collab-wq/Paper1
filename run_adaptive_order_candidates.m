function [summary,winner]=run_adaptive_order_candidates(W,f,tw,p,fs,phaseRev,choice,N,targetHypothesis)
% Ottawa: same detector/mask, but evaluate activity in shaft-order coordinates.
assert(numel(tw)==numel(phaseRev));
assert(ismember(char(targetHypothesis),{'BPFO','BPFI'}), ...
    'Ottawa adaptive R selection requires one BPFO or BPFI target');
ranked=find_resonance_candidates(W,f,choice.smoothHz, ...
    choice.lowerHz,choice.upperHz,choice.minDistanceHz);
hypotheses=struct('name',char(targetHypothesis),'order',NaN);
if strcmp(hypotheses.name,'BPFO'), hypotheses.order=3.57;
else, hypotheses.order=5.43; end
candidates=struct([]); winner=[]; cache=cell(1,3);
for R=2:4
    if numel(ranked)<R
        c=empty_score(R,hypotheses);
        c.reason='INSUFFICIENT_BANDS';
        candidates=append(candidates,c);
        continue;
    end
    centers=sort(ranked(1:R));
    bands=[centers-choice.halfwidthHz centers+choice.halfwidthHz];
    try
        [maps,scoreRows]=one_count(W,f,tw,p,fs,phaseRev,bands,hypotheses);
        cache{R-1}=maps;
        candidates=append(candidates,scoreRows);
    catch err
        c=empty_score(R,hypotheses);
        c.bands_hz=bands;
        c.reason=['R_EXECUTION_FAILED: ' regexprep(err.message,'[\r\n]+',' ')];
        candidates=append(candidates,c);
    end
end
[best,rank,status]=select_optimal_band_count(candidates);
summary=struct('status',status,'mode','ottawa','evidence_unit','order', ...
    'target_fault_type',char(targetHypothesis), ...
    'target_hypothesis',char(targetHypothesis), ...
    'fs_hz',fs,'signal_samples',N,'observation_s',N/fs, ...
    'available_resonance_peaks_hz',ranked, ...
    'candidates',candidates,'ranked_candidate_indices',rank, ...
    'selected_R',[],'selected_hypothesis','','selected_candidate_index',[]);
if ~isempty(best)
    summary.selected_R=candidates(best).R;
    summary.selected_hypothesis=candidates(best).hypothesis;
    summary.selected_candidate_index=best;
    winner=cache{summary.selected_R-1};
end
end

function [maps,rows]=one_count(Wfull,ffull,tw,p,fs,phaseRev,bands,hypotheses)
p.bands=bands;
keep=ffull>=max(0,min(bands(:,1))-600) & ...
    ffull<=min(fs/2,max(bands(:,2))+600);
W=Wfull(keep,:); f=ffull(keep);
[Sf,St,Etime,peakIdx,pairCount,frequencyPairs]= ...
    dual_detector_abs_multiband(W,f,tw,p);
Mf=(Sf>p.freqThr) & (Etime>p.activityThr);
Mt=St>p.timeThr;
fusion=sqrt(max(Sf,0).*max(St,0));
M=(fusion>sqrt(p.freqThr*p.timeThr)) & (Etime>p.activityThr);
Wout=W.*M;
selected=band_union(f,bands); df=median(diff(f));
raw=sum(max(W(selected,:),0),1)*df;
fused=sum(max(Wout(selected,:),0),1)*df;
rows=empty_score(size(bands,1),hypotheses);
    [rawPeak,rawContrast]=fault_evidence_order(raw,tw,phaseRev,hypotheses.order);
    [peak,contrast,delta]=fault_evidence_order(fused,tw,phaseRev,hypotheses.order);
    score=evaluate_band_count(size(bands,1),hypotheses.name, ...
        hypotheses.order,peak,contrast,delta,1);
    item=empty_score(size(bands,1),hypotheses);
    item.target_peak_order=peak;
    item.raw_target_peak_order=rawPeak;
    item.raw_target_contrast=rawContrast;
    item.contrast_linear=contrast;
    item.physical_resolution_order=delta;
    item.error_order=score.error_hz;
    item.location_confidence=score.location_confidence;
    item.contrast_utility=score.contrast_utility;
    item.J=score.J; item.valid=score.valid; item.reason=score.reason;
    item.bands_hz=bands;
    item.valid_band_pair_windows=sum(frequencyPairs>0,'all');
    item.frequency_triplet_count=sum(frequencyPairs,'all');
    item.time_endpoint_count=numel(peakIdx);
    item.time_pair_count=pairCount;
    item.retained_pixel_fraction=nnz(M)/numel(M);
    rows=item;
maps=struct('W',W,'f',f,'Sf',Sf,'St',St,'Mf',Mf,'Mt',Mt,'M',M, ...
    'Wout',Wout,'fusion',fusion,'Etime',Etime,'raw_activity',raw, ...
    'fused_activity',fused,'bands_hz',bands);
end

function item=empty_score(R,h)
item=struct('R',R,'hypothesis',h.name,'theoretical_order',h.order, ...
    'target_peak_order',NaN,'raw_target_peak_order',NaN, ...
    'raw_target_contrast',NaN,'contrast_linear',NaN, ...
    'physical_resolution_order',NaN,'error_order',NaN, ...
    'location_confidence',NaN,'contrast_utility',NaN,'J',NaN, ...
    'valid',false,'reason','','bands_hz',[], ...
    'valid_band_pair_windows',NaN,'frequency_triplet_count',NaN, ...
    'time_endpoint_count',NaN,'time_pair_count',NaN, ...
    'retained_pixel_fraction',NaN);
end

function list=append(list,item)
if isempty(list), list=item; else, list(end+1)=item; end
end
