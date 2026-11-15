function rankedCenters=find_resonance_candidates(W,f,smoothHz,lowerHz,upperHz,minDistanceHz)
% Rank all eligible resonance peaks once by the original WVD amplitude.
df=median(diff(f));
profile=movmean(mean(abs(W),2),max(3,round(smoothHz/df)));
eligible=f>=lowerHz & f<=upperHz;
[height,locations]=findpeaks(profile(eligible),f(eligible), ...
    'MinPeakDistance',minDistanceHz);
[~,order]=sort(height,'descend');
rankedCenters=locations(order);
rankedCenters=rankedCenters(:);
end
