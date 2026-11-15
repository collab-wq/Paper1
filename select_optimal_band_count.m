function [bestIndex,rankedIndices,status]=select_optimal_band_count(candidates)
% Rank valid (R, hypothesis) candidates; smaller R wins exact score ties.
if isempty(candidates)
    bestIndex=[]; rankedIndices=[]; status='NO_VALID_R'; return;
end
valid=find([candidates.valid]);
if isempty(valid)
    bestIndex=[]; rankedIndices=[]; status='NO_VALID_R'; return;
end
scores=[candidates(valid).J]';
bandCounts=[candidates(valid).R]';
names=string({candidates(valid).hypothesis})';
ordering=table(-scores,bandCounts,names, ...
    'VariableNames',{'negative_score','R','hypothesis'});
[~,order]=sortrows(ordering,{'negative_score','R','hypothesis'});
rankedIndices=valid(order);
bestIndex=rankedIndices(1);
status='SELECTED';
end
