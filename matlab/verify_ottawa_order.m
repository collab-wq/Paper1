function verify_ottawa_order
% Deterministic encoder and order-spectrum unit checks; no experiment data.
fs=100000; rpmTrue=1200; ppr=1024;
t=(0:fs-1)'/fs;
cycles=t*(rpmTrue/60)*ppr;
encoderSignal=double(mod(cycles,1)<0.3);
encoder=estimate_encoder_phase(encoderSignal,fs,ppr);
assert(abs(median(encoder.rpm)-rpmTrue)<3);
assert(numel(encoder.edge_times_s)>19000);
revs=(0:1/64:20)';
activity=1+sin(2*pi*3.57*revs);
[peak,contrast,delta]=fault_evidence_order(activity, ...
    (0:numel(revs)-1)'/1000,revs,3.57);
assert(abs(peak-3.57)<=delta && contrast>10);
score=evaluate_band_count(2,'BPFO',3.57,peak,contrast,delta,1);
assert(score.valid && score.contrast_utility==1);
fprintf('OTTAWA_ORDER_SELF_CHECK_PASS rpm %.3f peak %.5f order contrast %.2f\n', ...
    median(encoder.rpm),peak,contrast);
end
