function run_multiband_validation(dataset,R)
% Run the fixed 35 real-data segments at one R; retain explicit failures.
assert(ismember(R,[2 3 4]));
dataset=char(dataset);
files={}; starts=[];
switch dataset
    case 'cwru'
        ids=[105 118 130 130 130];
        starts=[1 1 1 4097 8193];
        for k=1:numel(ids)
            files{end+1}=fullfile('input','cwru',sprintf('%d.mat',ids(k))); %#ok<AGROW>
        end
    case 'paderborn'
        ids={'K001','KA04','KI04'};
        for k=1:numel(ids)
            for rec=1:3
                file=fullfile('input','paderborn',ids{k}, ...
                    sprintf('N15_M07_F10_%s_%d.mat',ids{k},rec));
                for first=[64001 128001]
                    files{end+1}=file; starts(end+1)=first; %#ok<AGROW>
                end
            end
        end
    case 'xjtu'
        for index=[1 2 69 82 109 123]
            file=fullfile('input','xjtu-sy','35Hz12kN','Bearing1_1', ...
                sprintf('%d.csv',index));
            for first=[4097 16385]
                files{end+1}=file; starts(end+1)=first; %#ok<AGROW>
            end
        end
    otherwise
        error('Unknown real dataset %s',dataset);
end
N=numel(starts); status=strings(N,1); detail=strings(N,1);
for k=1:N
    fprintf('VALIDATION_START dataset=%s R=%d case=%d/%d file=%s start=%d\n', ...
        dataset,R,k,N,files{k},starts(k));
    try
        main_Paper1(dataset,files{k},starts(k),R);
        status(k)="PASS";
    catch err
        status(k)="FAIL";
        detail(k)=string(regexprep(err.message,'[\r\n]+',' '));
        fprintf(2,'VALIDATION_FAILURE dataset=%s R=%d file=%s start=%d: %s\n', ...
            dataset,R,files{k},starts(k),detail(k));
    end
end
outdir=fullfile('results','absolute-support-multiband',dataset, ...
    sprintf('R%d',R));
if ~exist(outdir,'dir'), mkdir(outdir); end
statusTable=table(repmat(string(dataset),N,1),strings(N,1),starts(:), ...
    repmat(R,N,1),status,detail, ...
    'VariableNames',{'dataset','file','start_sample','R','status','detail'});
for k=1:N, statusTable.file(k)=string(files{k}); end
writetable(statusTable,fullfile(outdir,'validation_status.csv'));
fprintf('VALIDATION_COMPLETE dataset=%s R=%d success=%d failure=%d\n', ...
    dataset,R,nnz(status=="PASS"),nnz(status=="FAIL"));
end
