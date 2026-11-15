function hypotheses=bearing_hypotheses(mode,rpm,requested)
% Physical candidates only. File names and true fault labels are not inputs.
assert(isscalar(rpm) && isfinite(rpm) && rpm>0, ...
    'Measured or nominal rotation speed is required');
shaftHz=rpm/60;
switch char(mode)
    case 'cwru'
        % Published drive-end SKF 6205 factors used in the historical record.
        names={'BPFO','BPFI','BSF'};
        factors=[3.5848 5.4152 4.7135];
        frequencies=factors*shaftHz;
        source='CWRU drive-end published factors and MAT RPM';
    case 'paderborn'
        balls=8; ballDiameter=6.75; pitchDiameter=28.55;
        ratio=ballDiameter/pitchDiameter;
        names={'BPFO','BPFI','BSF'};
        frequencies=[balls/2*(1-ratio),balls/2*(1+ratio), ...
            1/(2*ratio)*(1-ratio^2)]*shaftHz;
        source='nominal 6203 geometry and MAT speed mean';
    case 'xjtu'
        balls=8; ballDiameter=7.92; pitchDiameter=34.55;
        ratio=ballDiameter/pitchDiameter;
        names={'BPFO','BPFI','BSF'};
        frequencies=[balls/2*(1-ratio),balls/2*(1+ratio), ...
            1/(2*ratio)*(1-ratio^2)]*shaftHz;
        source='nominal LDK UER204 geometry and condition-specific nominal RPM';
    otherwise
        error('No bearing geometry or fault factors for mode %s',mode);
end
if nargin<3 || isempty(requested) || strcmpi(char(requested),'unknown')
    chosen=1:numel(names);
else
    chosen=find(strcmpi(names,char(requested)));
    assert(isscalar(chosen),'Unsupported fault hypothesis %s',char(requested));
end
hypotheses=repmat(struct('name','','hz',NaN,'source',''),1,numel(chosen));
for k=1:numel(chosen)
    i=chosen(k);
    hypotheses(k)=struct('name',names{i},'hz',frequencies(i),'source',source);
end
end
