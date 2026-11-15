function [peak,contrast,resolution,order,power]=fault_evidence_order(activity,timeSeconds,shaftRevolutions,expectedOrder)
% Only the WVD activity is mapped to angle; input vibration stays time-domain.
activity=double(activity(:)); timeSeconds=double(timeSeconds(:));
shaftRevolutions=double(shaftRevolutions(:));
assert(numel(activity)==numel(timeSeconds) && ...
    numel(activity)==numel(shaftRevolutions));
assert(all(diff(shaftRevolutions)>0),'Shaft phase must increase');
revolutions=shaftRevolutions(end)-shaftRevolutions(1);
resolution=1/revolutions;
step=1/64;
regular=(shaftRevolutions(1):step:shaftRevolutions(end))';
assert(numel(regular)>64,'Order window has fewer than one revolution');
angleActivity=interp1(shaftRevolutions,activity,regular,'linear');
y=angleActivity-mean(angleActivity);
nfft=2^nextpow2(16*numel(y));
power=abs(fft(y,nfft)).^2;
order=(0:nfft-1)'/(nfft*step);
search=order>=0.8*expectedOrder & order<=1.2*expectedOrder;
background=order>=0.5 & order<=12 & ~search;
assert(any(search) && any(background),'Order target or background empty');
[candidatePower,which]=max(power(search));
target=order(search); peak=target(which);
contrast=candidatePower/(median(power(background))+eps);
end
