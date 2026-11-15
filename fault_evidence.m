function [peak,contrast]=fault_evidence(activity,dt,expected)
y=activity(:)'-mean(activity);
nfft=2^nextpow2(16*numel(y)); Y=abs(fft(y,nfft)).^2;
freq=(0:nfft-1)/(nfft*dt);
search=freq>=0.8*expected&freq<=1.2*expected;
background=freq>=50&freq<=200&~search;
[power,k]=max(Y(search)); candidates=freq(search);
peak=candidates(k); contrast=power/(median(Y(background))+eps);
end
