function [freq,power]=periodogram_curve(activity,dt)
y=activity(:)'-mean(activity);
nfft=2^nextpow2(16*numel(y));
power=abs(fft(y,nfft)).^2;
freq=(0:nfft-1)/(nfft*dt);
end
