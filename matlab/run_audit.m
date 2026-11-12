function run_audit
% Fixed representative/full repeat suite from the prior executed workflows.
main_Paper1('synthetic');
ids=[105 118 130];
for k=1:numel(ids)
    file=fullfile('input','cwru',sprintf('%d.mat',ids(k)));
    main_Paper1('cwru',file,1);
end
for startIndex=[4097 8193]
    main_Paper1('cwru',fullfile('input','cwru','130.mat'),startIndex);
end
run_paderborn_batch;
run_xjtu_batch;
end
