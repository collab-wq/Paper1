function run_paderborn_full_batch
% Official N15_M07_F10 measurements; target metadata enters evaluation only.
ids={'KA04','KA16','KB24','KI21','KI17','KI04'};
for b=1:numel(ids)
    for rec=1:3
        file=fullfile('input','paderborn',ids{b}, ...
            sprintf('N15_M07_F10_%s_%d.mat',ids{b},rec));
        assert(isfile(file),'Missing Paderborn record %s',file);
        for first=[64001 128001]
            [targets,faultType]=bearing_target_metadata('paderborn',ids{b});
            for h=1:numel(targets)
                target=targets{h};
                try
                    main_Paper1('paderborn',file,first,'auto',target,true,faultType);
                catch err
                    record_segment_failure('paderborn',file,first,err,target);
                end
            end
        end
    end
end
end
