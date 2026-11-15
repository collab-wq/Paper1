function score=evaluate_band_count(R,hypothesis,expectedHz,peakHz,contrast,fs,N)
% Score an existing linear-power contrast without changing its definition.
delta=fs/N;
score=struct('R',R,'hypothesis',char(hypothesis), ...
    'theoretical_hz',expectedHz,'target_peak_hz',peakHz, ...
    'contrast_linear',contrast,'physical_resolution_hz',delta, ...
    'error_hz',NaN,'location_confidence',NaN, ...
    'contrast_utility',NaN,'J',NaN,'valid',false,'reason','');
if ~all(isfinite([expectedHz peakHz contrast fs N])) || ...
        expectedHz<=0 || fs<=0 || N<=0
    score.reason='NONFINITE_OR_MISSING_PHYSICS'; return;
end
score.error_hz=abs(peakHz-expectedHz);
score.location_confidence=exp(-0.5*(score.error_hz/delta)^2);
if contrast<=1
    score.contrast_utility=0;
    score.reason='CONTRAST_NOT_ABOVE_BACKGROUND'; return;
end
score.contrast_utility=min(1,log(contrast)/log(10));
if score.error_hz>delta
    score.reason='ERROR_EXCEEDS_PHYSICAL_RESOLUTION'; return;
end
score.J=score.contrast_utility*score.location_confidence;
score.valid=isfinite(score.J) && score.J>0;
if score.valid, score.reason='VALID';
else, score.reason='NONFINITE_SCORE'; end
end
