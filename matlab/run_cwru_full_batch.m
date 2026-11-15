function run_cwru_full_batch
% All 12 official 0.007-inch drive-end fault files; labels remain external.
ids=[105 130 144 156 106 131 145 158 107 132 146 159];
for id=ids
    file=fullfile('input','cwru',sprintf('%d.mat',id));
    d=load(file); key=sprintf('X%d',id);
    assert(isfield(d,[key '_DE_time']) && isfield(d,[key '_RPM']));
    assert(numel(d.([key '_DE_time']))>=8193+2047);
    for first=[1 4097 8193]
        main_Paper1('cwru',file,first);
    end
end
end
