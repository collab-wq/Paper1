function [bestIndex,rankedIndices,status]=select_optimal_band_count(candidates)
% Rank R only for one explicitly supplied target hypothesis.
if isempty(candidates)
    bestIndex=[]; rankedIndices=[]; status='NO_VALID_R'; return;
end
names=string({candidates.hypothesis});
assert(numel(unique(names))==1, ...
    'Mixed fault hypotheses cannot be ranked together');
assert(numel(candidates)==3 && isequal(sort([candidates.R]),[2 3 4]), ...
    'Expected exactly one candidate for each R=2,3,4');
valid=find([candidates.valid]);
if isempty(valid)
    bestIndex=[]; rankedIndices=[]; status='NO_VALID_R'; return;
end
scores=[candidates(valid).J]';
bandCounts=[candidates(valid).R]';
ordering=table(-scores,bandCounts, ...
    'VariableNames',{'negative_score','R'});
[~,order]=sortrows(ordering,{'negative_score','R'});
rankedIndices=valid(order);
bestIndex=rankedIndices(1);
status='SELECTED';
end
