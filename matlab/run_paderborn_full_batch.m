function run_paderborn_full_batch
% Official N15_M07_F10 measurements; no damage label enters main_Paper1.
ids={'KA04','KA16','KB24','KI21','KI17','KI04'};
for b=1:numel(ids)
    for rec=1:3
        file=fullfile('input','paderborn',ids{b}, ...
            sprintf('N15_M07_F10_%s_%d.mat',ids{b},rec));
        assert(isfile(file),'Missing Paderborn record %s',file);
        for first=[64001 128001]
            try
                main_Paper1('paderborn',file,first);
            catch err
                record_segment_failure('paderborn',file,first,err);
            end
        end
    end
end
end
