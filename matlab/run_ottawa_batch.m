function run_ottawa_batch(recordName)
% Full ten-second records; each WVD window uses encoder phase for order evidence.
if nargin<1, names={'I-A-2','I-B-2','I-C-2','O-A-2','O-B-2','O-C-2'};
else, names={char(recordName)}; end
for i=1:numel(names)
    if startsWith(names{i},'I-'), target='BPFI';
    elseif startsWith(names{i},'O-'), target='BPFO';
    else, error('Unmapped Ottawa record'); end
    file=fullfile('input','ottawa',[names{i} '.mat']);
    info=whos('-file',file,'Channel_1');
    assert(numel(info)==1 && prod(info.size)==2000000);
    lengthRaw=65536; hop=32768;
    starts=unique([1:hop:(2000000-lengthRaw+1),2000000-lengthRaw+1]);
    representatives=unique(max(1,min(numel(starts),round([.05 .5 .95]*numel(starts)))));
    for k=1:numel(starts)
        try
            main_Paper1('ottawa',file,starts(k),'auto',target, ...
                ismember(k,representatives));
        catch err
            record_segment_failure('ottawa',file,starts(k),err,target);
        end
        fprintf('Ottawa %s window %d/%d complete\n', ...
            names{i},k,numel(starts));
    end
end
end
