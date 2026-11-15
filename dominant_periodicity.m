function [peak,contrast]=dominant_periodicity(activity,dt)
[freq,power]=periodogram_curve(activity,dt);
band=freq>=50&freq<=200;
values=power(band); candidates=freq(band);
[height,k]=max(values); peak=candidates(k);
contrast=height/(median(values)+eps);
end
