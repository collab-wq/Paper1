function inspect_paderborn
outdir=fullfile('results','paderborn-inspection');
if ~exist(outdir,'dir'), mkdir(outdir); end
diary(fullfile(outdir,'inspection.log'));
cleanup=onCleanup(@() diary('off'));
bearings={'K001','KA04','KI04'};
for k=1:numel(bearings)
    id=bearings{k};
    file=fullfile('input','paderborn',id,sprintf('N15_M07_F10_%s_1.mat',id));
    fprintf('\nFILE %s\n',file);
    info=whos('-file',file);
    for j=1:numel(info)
        fprintf('ROOT %s class=%s size=%s\n',info(j).name,info(j).class,mat2str(info(j).size));
    end
    d=load(file); names=fieldnames(d);
    for j=1:numel(names)
        value=d.(names{j});
        fprintf('VARIABLE %s class=%s size=%s\n',names{j},class(value),mat2str(size(value)));
        if isstruct(value)
            fn=fieldnames(value);
            fprintf('FIELDS %s: %s\n',names{j},strjoin(fn,', '));
            for q=1:min(numel(value),8)
                fprintf(' STRUCT ELEMENT %d\n',q);
                for z=1:numel(fn)
                    item=value(q).(fn{z});
                    fprintf('  %s class=%s size=%s\n',fn{z},class(item),mat2str(size(item)));
                    if isstruct(item)
                        fprintf('  NESTED %s: %s\n',fn{z},strjoin(fieldnames(item),', '));
                    end
                end
            end
            for q=1:numel(value.X)
                item=value.X(q);
                fprintf('X_CHANNEL %d name=%s unit=%s raster=%s data_size=%s\n', ...
                    q,string(item.Name),string(item.Unit),string(item.Raster),mat2str(size(item.Data)));
                if isnumeric(item.Data) && numel(item.Data)>1
                    fprintf(' X_RANGE %.9g %.9g\n',double(item.Data(1)),double(item.Data(end)));
                end
            end
            for q=1:numel(value.Y)
                item=value.Y(q);
                fprintf('Y_CHANNEL %d name=%s unit=%s raster=%s xindex=%s downsampling=%s data_size=%s\n', ...
                    q,string(item.Name),string(item.Unit),string(item.Raster), ...
                    mat2str(item.XIndex),mat2str(item.DownSampling),mat2str(size(item.Data)));
                if isnumeric(item.Data) && ~isempty(item.Data)
                    v=double(item.Data(:));
                    fprintf(' Y_STATS mean=%.9g std=%.9g min=%.9g max=%.9g\n', ...
                        mean(v),std(v),min(v),max(v));
                end
            end
            disp(value.Description)
        end
    end
end
try
    [probe,probeF,probeT]=wvd(hilbert(randn(512,1)),64000,'NumFrequencyPoints',256);
    fprintf('WVD_GRID_PROBE %s freq=%d time=%d\n',mat2str(size(probe)),numel(probeF),numel(probeT));
catch ME
    fprintf('WVD_GRID_PROBE_ERROR %s\n',ME.message);
end
end
