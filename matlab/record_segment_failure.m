function record_segment_failure(dataset,file,startIndex,err,targetHypothesis)
if nargin<5, targetHypothesis=''; end
outdir=fullfile('results','failures');
if ~exist(outdir,'dir'), mkdir(outdir); end
[~,stem]=fileparts(file);
[parent,~]=fileparts(file); [~,bearing]=fileparts(parent);
name=sprintf('%s-%s-%s-start%d-%s.json',dataset,bearing,stem,startIndex,targetHypothesis);
record=struct('dataset',dataset,'file',file,'start_sample',startIndex, ...
    'target_hypothesis',targetHypothesis,'status','FAILED', ...
    'reason',err.message,'identifier',err.identifier);
fid=fopen(fullfile(outdir,name),'w'); assert(fid>0);
fprintf(fid,'%s\n',jsonencode(record)); fclose(fid);
fprintf(2,'FAILED %s %s start %d: %s\n',dataset,file,startIndex,err.message);
end
