function validate_cwru
outdir = fullfile('results','cwru-validation');
if ~exist(outdir,'dir'), mkdir(outdir); end
diary(fullfile(outdir,'validation.log'));
cleanup = onCleanup(@() diary('off'));
ids = [97,105,118,130];
labels = {'Normal_0','IR007_0','B007_0','OR007@6_0'};
fs = [48000,12000,12000,12000];
records = cell(1,numel(ids));
for k=1:numel(ids)
    id=ids(k);
    file=fullfile('input','cwru',sprintf('%d.mat',id));
    info=whos('-file',file);
    vars={info.name};
    if id==97, key='X097'; else, key=sprintf('X%d',id); end
    de=[key '_DE_time']; rpmKey=[key 'RPM'];
    assert(ismember(de,vars) && ismember(rpmKey,vars), ...
        'Missing DE signal or RPM variable in %s',file);
    d=load(file,de,rpmKey);
    x=d.(de); rpm=double(d.(rpmKey));
    assert(isvector(x) && numel(x)>2000 && all(isfinite(x)), ...
        'Invalid DE signal in %s',file);
    assert(isscalar(rpm) && rpm>=1750 && rpm<=1800, ...
        'Unexpected recorded RPM in %s',file);
    records{k}=struct('file',sprintf('%d.mat',id),'condition',labels{k}, ...
        'channel',de,'variables',{vars},'samples',numel(x), ...
        'fs_hz',fs(k),'duration_s',numel(x)/fs(k),'rpm',rpm, ...
        'source',sprintf('https://engineering.case.edu/sites/default/files/%d.mat',id));
    fprintf('%d.mat: %s; %s; samples %d; fs %d Hz; RPM %.0f; variables %s\n', ...
        id,labels{k},de,numel(x),fs(k),rpm,strjoin(vars,', '));
end
records=[records{:}];
fid=fopen(fullfile(outdir,'records.json'),'w');
assert(fid>0,'Cannot write validation JSON');
fprintf(fid,'%s\n',jsonencode(records)); fclose(fid);
end
