function run_xjtu_lifetime_batch(bearing)
% Every numbered CSV; two windows belong to one minute-snapshot.
groups=containers.Map({'Bearing1_2','Bearing1_3','Bearing2_1', ...
    'Bearing2_2','Bearing3_1','Bearing3_4'}, ...
    {'35Hz12kN','35Hz12kN','37.5Hz11kN', ...
    '37.5Hz11kN','40Hz10kN','40Hz10kN'});
assert(isKey(groups,bearing),'Unknown XJTU bearing');
[targets,faultType]=bearing_target_metadata('xjtu',bearing);
target=targets{1};
folder=fullfile('input','xjtu-sy',groups(bearing),bearing);
files=dir(fullfile(folder,'*.csv'));
indices=nan(1,numel(files));
for k=1:numel(files)
    [~,stem]=fileparts(files(k).name); indices(k)=str2double(stem);
end
assert(~isempty(files) && all(isfinite(indices)) && ...
    numel(unique(indices))==numel(indices));
[indices,order]=sort(indices); files=files(order);
fullCounts=containers.Map({'Bearing1_2','Bearing1_3','Bearing2_1', ...
    'Bearing2_2','Bearing3_1','Bearing3_4'}, ...
    {161,158,491,161,2538,1515});
positions=unique(max(1,round([.1 .5 .9]*fullCounts(bearing))));
for k=1:numel(files)
    file=fullfile(folder,files(k).name);
    for first=[4097 16385]
        try
            main_Paper1('xjtu',file,first,'auto',target, ...
                ismember(indices(k),positions),faultType);
        catch err
            record_segment_failure('xjtu',file,first,err,target);
        end
    end
    fprintf('XJTU %s snapshot %d/%d (file %d.csv) complete\n', ...
        bearing,k,numel(files),indices(k));
end
end
