# Target and harmonic mechanism diagnostic

This is a retrospective mechanism test on 15 previously NO_VALID_R windows. It is not a revised production accuracy estimate.

## Execution and definitions

Each source window is processed with one WVD call. The unchanged dual-direction detector and mask are rerun for all combinations of 2, 3 or 4 bands among up to eight eligible candidates. If the fixed original search and spacing rules yield fewer than eight candidates, only actual candidates are enumerated. Current top-R combinations are marked `baseline`; all other combinations are post hoc diagnostics. Local peaks use the original search interval, background median and physical resolution. A valid peak must simultaneously satisfy contrast > 1 and error <= resolution. Among valid peaks, the highest J is reported. Two-line evidence requires fundamental plus second or third harmonic; three-line evidence requires all three.

## Sample results

| Dataset | Bearing / condition | Windows | Old valid | New fundamental | Two-line | Three-line | Extended fundamental |
|---|---|---:|---:|---:|---:|---:|---:|
| ottawa | O-A-2 | 2 | 0 | 1 | 1 | 0 | 2 |
| ottawa | O-B-2 | 2 | 0 | 1 | 1 | 1 | 2 |
| ottawa | O-C-2 | 2 | 0 | 2 | 1 | 0 | 2 |
| xjtu | Bearing1_2 | 1 | 0 | 1 | 0 | 0 | 1 |
| xjtu | Bearing1_3 | 1 | 0 | 1 | 1 | 0 | 1 |
| xjtu | Bearing2_1 | 2 | 0 | 0 | 0 | 0 | 2 |
| xjtu | Bearing2_2 | 1 | 0 | 1 | 1 | 0 | 1 |
| xjtu | Bearing3_1 | 2 | 0 | 2 | 2 | 0 | 2 |
| xjtu | Bearing3_4 | 2 | 0 | 2 | 1 | 0 | 2 |

Across 15 windows, the old top-R method validates 0, the all-local-peak search on the same top-R bands validates 11, and 15 have at least one post hoc combination containing rank 5–8 with a valid fundamental.

A post hoc valid combination is evidence that resonance ranking can omit useful bands in these windows. It does not establish an online band-selection rule. Fundamental evidence alone is not sufficient to claim full fault recognition. See the two-line and three-line columns and per-peak CSV.

## Source and reproducibility

Window IDs, segment hashes, source hashes, channels and original result paths are in `DIAGNOSTIC_WINDOWS.csv`. Candidate centers and boundaries, every local peak, and each band combination are preserved in the corresponding CSV. MATLAB logs and per-window plots are in the GitHub Actions Artifact. Ottawa errors are in order; XJTU errors are in Hz. No full-data rerun was performed.
