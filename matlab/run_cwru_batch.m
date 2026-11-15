function run_cwru_batch(numBands)
% Run the five previously validated CWRU fault-signal segments.
if nargin<1, numBands=2; end
ids=[105 118 130];
for k=1:numel(ids)
    file=fullfile('input','cwru',sprintf('%d.mat',ids(k)));
    main_Paper1('cwru',file,1,numBands);
end
for startIndex=[4097 8193]
    main_Paper1('cwru',fullfile('input','cwru','130.mat'),startIndex,numBands);
end
end
