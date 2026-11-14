function run_cwru_batch
% Run the five previously validated CWRU fault-signal segments.
ids=[105 118 130];
for k=1:numel(ids)
    file=fullfile('input','cwru',sprintf('%d.mat',ids(k)));
    main_Paper1('cwru',file,1);
end
for startIndex=[4097 8193]
    main_Paper1('cwru',fullfile('input','cwru','130.mat'),startIndex);
end
end
