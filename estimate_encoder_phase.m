function encoder=estimate_encoder_phase(channel,fs,pulsesPerRev)
% Recover rising-edge shaft phase from the recorded encoder channel.
channel=double(channel(:));
assert(all(isfinite(channel)) && fs>0 && pulsesPerRev>0);
ordered=sort(channel);
low=ordered(max(1,round(0.05*numel(ordered))));
high=ordered(min(numel(ordered),round(0.95*numel(ordered))));
assert(high-low>0,'Encoder channel has no pulse amplitude');
threshold=(low+high)/2;
edge=find(channel(1:end-1)<threshold & channel(2:end)>=threshold)+1;
assert(numel(edge)>pulsesPerRev,'Too few encoder edges');
edgeTimes=(edge-1)/fs;
interval=diff(edgeTimes);
assert(all(interval>0),'Encoder edge ordering invalid');
% A full revolution difference avoids noisy sample-to-sample pulse periods.
revolutionSpan=edgeTimes(1+pulsesPerRev:end)-edgeTimes(1:end-pulsesPerRev);
rpm=60./revolutionSpan;
assert(all(isfinite(rpm)) && all(rpm>100) && all(rpm<10000), ...
    'Encoder-derived RPM is outside plausible range');
encoder=struct('edge_times_s',edgeTimes,'edge_revolutions', ...
    (0:numel(edge)-1)'/pulsesPerRev,'rpm_times_s', ...
    (edgeTimes(1+pulsesPerRev:end)+edgeTimes(1:end-pulsesPerRev))/2, ...
    'rpm',rpm,'pulses_per_revolution',pulsesPerRev, ...
    'threshold',threshold,'revolutions_total',(numel(edge)-1)/pulsesPerRev);
end
