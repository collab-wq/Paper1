function run_adaptive_validation(dataset)
% Manual future validation only. Every call uses the shared adaptive core.
switch char(dataset)
    case 'cwru'
        for id=[105 130]
            target=bearing_target_metadata('cwru',id);
            main_Paper1('cwru',fullfile('input','cwru',sprintf('%d.mat',id)), ...
                1,'auto',target{1});
        end
        for startIndex=[4097 8193]
            main_Paper1('cwru',fullfile('input','cwru','130.mat'), ...
                startIndex,'auto','BPFO');
        end
    case 'paderborn'
        ids={'KA04','KI04'};
        for k=1:numel(ids)
            for rec=1:3
                file=fullfile('input','paderborn',ids{k}, ...
                    sprintf('N15_M07_F10_%s_%d.mat',ids{k},rec));
                for startIndex=[64001 128001]
                    target=bearing_target_metadata('paderborn',ids{k});
                    main_Paper1('paderborn',file,startIndex,'auto',target{1});
                end
            end
        end
    case 'xjtu'
        for index=[1 2 69 82 109 123]
            file=fullfile('input','xjtu-sy','35Hz12kN','Bearing1_2', ...
                sprintf('%d.csv',index));
            for startIndex=[4097 16385]
                main_Paper1('xjtu',file,startIndex,'auto','BPFO');
            end
        end
    otherwise
        error('Unsupported dataset %s',char(dataset));
end
end
