function run_xjtu_batch
% Bearing1_1: two independently recorded snapshots in each life stage.
indices=[1 2 69 82 109 123];
stages={'early','early','middle','middle','late','late'};
outdir=fullfile('results','xjtu');
if ~exist(outdir,'dir'), mkdir(outdir); end
fid=fopen(fullfile(outdir,'life_summary.csv'),'w');
assert(fid>0);
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,['snapshot,stage,start_sample,bpfo_hz,raw_peak_hz,' ...
    'fused_peak_hz,raw_contrast,fused_contrast,retained_fraction,' ...
    'eligible_pairs,median_candidate_spacing_ms\n']);
for k=1:numel(indices)
    index=indices(k);
    file=fullfile('input','xjtu-sy','35Hz12kN','Bearing1_1', ...
        sprintf('%d.csv',index));
    for startIndex=[4097 16385]
        r=main_Paper1('xjtu',file,startIndex);
        fprintf(fid,'%d,%s,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.8f,%d,%.6f\n', ...
            index,stages{k},startIndex,r.bpfo_hz,r.raw_bpfo_peak_hz, ...
            r.fused_bpfo_peak_hz,r.raw_bpfo_contrast, ...
            r.fused_bpfo_contrast,r.retained_pixel_fraction, ...
            r.eligible_time_pairs,r.median_candidate_spacing_ms);
    end
end
end
