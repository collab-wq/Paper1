function verify_matlab_cloud
% Minimal executable check of the hosted MATLAB and Signal Processing Toolbox.
outdir = fullfile('results','matlab-verification');
if ~exist(outdir,'dir'), mkdir(outdir); end
diary(fullfile(outdir,'verification.log'));
cleanup = onCleanup(@() diary('off'));
fprintf('MATLAB version: %s\n',version);
fprintf('Platform: %s\n',computer);
fprintf('hilbert: %s\n',which('hilbert'));
fprintf('wvd: %s\n',which('wvd'));
assert(exist('hilbert','file')~=0,'hilbert unavailable');
assert(exist('wvd','file')~=0,'wvd unavailable');
fs = 4000;
t = (0:255)'/fs;
x = cos(2*pi*650*t)+0.5*cos(2*pi*980*t);
z = hilbert(x);
[W,f,tw] = wvd(z,fs);
assert(isequal(size(W),[numel(f),numel(tw)]));
assert(all(isfinite(W(:))));
assert(numel(f)>0 && numel(tw)>0);
result = struct('matlab_version',version,'platform',computer, ...
    'hilbert_path',which('hilbert'),'wvd_path',which('wvd'), ...
    'wvd_size',size(W),'frequency_range_hz',[min(f),max(f)], ...
    'time_range_s',[min(tw),max(tw)],'max_abs_wvd',max(abs(W(:))), ...
    'signal_processing_toolbox',true,'passed',true);
fid = fopen(fullfile(outdir,'result.json'),'w');
assert(fid>0,'Cannot create result.json');
fprintf(fid,'%s\n',jsonencode(result));
fclose(fid);
save(fullfile(outdir,'result.mat'),'result','f','tw');
disp(result);
end
