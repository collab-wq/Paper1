function [rows,representative,status]=diagnostic_local_peaks(axis,power,expected,delta,unit,backgroundMode)
% Diagnostic-only search. The original background and J definitions remain fixed.
axis=axis(:); power=power(:);
search=axis>=.8*expected & axis<=1.2*expected;
if strcmp(unit,'order'), background=axis>=.5 & axis<=12 & ~search;
else, background=axis>=50 & axis<=200 & ~search; end
assert(any(search) && any(background));
denom=median(power(background))+eps;
indices=find(search);
% Strict interior maxima, plus search-interval endpoints if they are maxima.
loc=[];
for i=1:numel(indices)
    k=indices(i);
    if k>1 && k<numel(power) && power(k)>=power(k-1) && power(k)>power(k+1)
        loc(end+1)=k; %#ok<AGROW>
    end
end
rows=struct('position',{},'power',{},'contrast',{},'error',{},'resolution',{},'Qe',{},'Qc',{},'J',{},'valid',{});
for i=1:numel(loc)
    k=loc(i); contrast=power(k)/denom; error=abs(axis(k)-expected);
    Qe=exp(-.5*(error/delta)^2); Qc=0;
    if contrast>1, Qc=min(1,log(contrast)/log(10)); end
    valid=contrast>1 && error<=delta && isfinite(Qe*Qc) && Qe*Qc>0;
    rows(i)=struct('position',axis(k),'power',power(k),'contrast',contrast, ...
        'error',error,'resolution',delta,'Qe',Qe,'Qc',Qc,'J',Qe*Qc,'valid',valid); %#ok<AGROW>
end
good=find([rows.valid]); representative=[];
if isempty(rows), status='SEARCH_NO_LOCAL_PEAK';
elseif ~any([rows.error]<=delta), status='PEAK_LOCATION_INVALID';
elseif isempty(good), status='PEAK_CONTRAST_INVALID';
else
    status='VALID';
    [~,i]=max([rows(good).J]); representative=rows(good(i));
end
assert(strcmp(backgroundMode,'original'));
end
