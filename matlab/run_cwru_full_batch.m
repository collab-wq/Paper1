function run_cwru_full_batch
% Targets are explicit experiment metadata, independent of detection.
ids=[105 130 144 156 106 131 145 158 107 132 146 159];
for id=ids
    if ismember(id,[105 106 107]), target='BPFI';
    else, target='BPFO'; end
    file=fullfile('input','cwru',sprintf('%d.mat',id));
    d=load(file); key=sprintf('X%d',id);
    assert(isfield(d,[key '_DE_time']) && isfield(d,[key 'RPM']));
    assert(numel(d.([key '_DE_time']))>=8193+2047);
    for first=[1 4097 8193]
        try
            main_Paper1('cwru',file,first,'auto',target);
        catch err
            record_segment_failure('cwru',file,first,err,target);
        end
    end
end
end
