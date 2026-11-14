function bands=select_resonance_bands(W,f,R,smoothHz,lowerHz,upperHz,minDistanceHz,halfwidthHz)
% Data-driven amplitude profile. Detection support is separately |local mean|.
df=median(diff(f));
profile=movmean(mean(abs(W),2),max(3,round(smoothHz/df)));
eligible=f>=lowerHz & f<=upperHz;
[pk,loc]=findpeaks(profile(eligible),f(eligible), ...
    'MinPeakDistance',minDistanceHz);
[~,rank]=sort(pk,'descend');
assert(numel(rank)>=R, ...
    'Only %d distinct WVD resonance bands found; requested R=%d', ...
    numel(rank),R);
centers=sort(loc(rank(1:R)));
bands=[centers(:)-halfwidthHz,centers(:)+halfwidthHz];
end
