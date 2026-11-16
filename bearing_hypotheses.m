function hypotheses=bearing_hypotheses(mode,rpm,requested)
% Physical candidates only. File names and true fault labels are not inputs.
assert(isscalar(rpm) && isfinite(rpm) && rpm>0, ...
    'Measured or nominal rotation speed is required');
shaftHz=rpm/60;
switch char(mode)
    case 'cwru'
        % Published drive-end SKF 6205 factors used in the historical record.
        names={'BPFO','BPFI'};
        factors=[3.5848 5.4152];
        frequencies=factors*shaftHz;
        source='CWRU drive-end published factors and MAT RPM';
    case 'paderborn'
        balls=8; ballDiameter=6.75; pitchDiameter=28.55;
        ratio=ballDiameter/pitchDiameter;
        names={'BPFO','BPFI'};
        frequencies=[balls/2*(1-ratio),balls/2*(1+ratio)]*shaftHz;
        source='nominal 6203 geometry and MAT speed mean';
    case 'xjtu'
        balls=8; ballDiameter=7.92; pitchDiameter=34.55;
        ratio=ballDiameter/pitchDiameter;
        names={'BPFO','BPFI'};
        frequencies=[balls/2*(1-ratio),balls/2*(1+ratio)]*shaftHz;
        source='nominal LDK UER204 geometry and condition-specific nominal RPM';
    otherwise
        error('No bearing geometry or fault factors for mode %s',mode);
end
assert(nargin>=3 && ~isempty(requested) && ...
    any(strcmpi(char(requested),{'BPFO','BPFI'})), ...
    'Explicit BPFO or BPFI target is required');
chosen=find(strcmpi(names,char(requested)));
hypotheses=repmat(struct('name','','hz',NaN,'source',''),1,numel(chosen));
for k=1:numel(chosen)
    i=chosen(k);
    hypotheses(k)=struct('name',names{i},'hz',frequencies(i),'source',source);
end
end
