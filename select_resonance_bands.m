function bands=select_resonance_bands(W,f,R,smoothHz,lowerHz,upperHz,minDistanceHz,halfwidthHz)
% Data-driven amplitude profile. Detection support is separately |local mean|.
rankedCenters=find_resonance_candidates(W,f,smoothHz, ...
    lowerHz,upperHz,minDistanceHz);
assert(numel(rankedCenters)>=R, ...
    'Only %d distinct WVD resonance bands found; requested R=%d', ...
    numel(rankedCenters),R);
centers=sort(rankedCenters(1:R));
bands=[centers(:)-halfwidthHz,centers(:)+halfwidthHz];
end
