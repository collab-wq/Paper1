function targets=bearing_target_metadata(dataset,record)
% Audited experiment metadata. Only batch organizers call this function.
switch char(dataset)
    case 'cwru'
        ids=[105 106 107 130 131 132 144 145 146 156 158 159];
        assert(isnumeric(record) && isscalar(record) && ismember(record,ids), ...
            'Unmapped CWRU fault record');
        if ismember(record,[105 106 107]), targets={'BPFI'};
        else, targets={'BPFO'}; end
    case 'paderborn'
        key=char(record);
        if any(strcmp(key,{'KA04','KA16'})), targets={'BPFO'};
        elseif any(strcmp(key,{'KI21','KI17','KI04'})), targets={'BPFI'};
        elseif strcmp(key,'KB24'), targets={'BPFO','BPFI'};
        else, error('Unmapped Paderborn fault record'); end
    case 'ottawa'
        key=char(record);
        if any(strcmp(key,{'I-A-2','I-B-2','I-C-2'})), targets={'BPFI'};
        elseif any(strcmp(key,{'O-A-2','O-B-2','O-C-2'})), targets={'BPFO'};
        else, error('Unmapped Ottawa fault record'); end
    case 'xjtu'
        key=char(record);
        if any(strcmp(key,{'Bearing1_2','Bearing1_3','Bearing2_2','Bearing3_1'})), targets={'BPFO'};
        elseif any(strcmp(key,{'Bearing2_1','Bearing3_4'})), targets={'BPFI'};
        else, error('Unmapped XJTU-SY fault record'); end
    otherwise
        error('Unmapped dataset');
end
end
