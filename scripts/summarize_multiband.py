#!/usr/bin/env python3
"""Collect MATLAB outputs without changing the previously audited metrics."""
import argparse
import csv
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    roots = list(args.root.rglob("validation_status.csv"))
    assert len(roots) == 9, f"Expected 9 dataset/R status files, got {len(roots)}"
    rows = []
    seen = set()
    for status_file in roots:
        for status in csv.DictReader(status_file.open(newline="")):
            dataset = status["dataset"]
            source = Path(status["file"])
            start = int(status["start_sample"])
            R = int(status["R"])
            key = (dataset, source.name, start, R)
            assert key not in seen, f"Repeated segment {key}"
            seen.add(key)
            if dataset == "cwru":
                stem = source.stem
                segment = f"cwru-{stem}" + (f"-start{start}" if start != 1 else "")
            elif dataset == "paderborn":
                segment = f"paderborn/{source.stem}-start{start}"
            else:
                segment = f"xjtu/Bearing1_1-{source.stem}-start{start}"
            result_file = args.root / segment / f"R{R}" / "result.json"
            row = dict(dataset=dataset, file=source.name, start_sample=start, R=R,
                       status=status["status"], failure_reason=status["detail"])
            if status["status"] == "PASS":
                assert result_file.is_file(), f"Missing MATLAB result: {result_file}"
                result = json.loads(result_file.read_text())
                assert result["num_bands"] == R
                bands = result["bands_hz"]
                assert len(bands) == R
                target = result.get("fault_frequency_name", result.get("fault_name"))
                expected = (result["expected_fault_hz"] if dataset == "cwru" else
                            result["bpfi_hz"] if target == "BPFI" else result["bpfo_hz"])
                if dataset == "cwru":
                    raw_peak = result["raw_periodicity_peak_hz"]
                    fused_peak = result["fused_periodicity_peak_hz"]
                    raw_contrast = result["raw_fault_contrast"]
                    fused_contrast = result["fused_fault_contrast"]
                else:
                    prefix = "bpfi" if target == "BPFI" else "bpfo"
                    raw_peak = result[f"raw_{prefix}_peak_hz"]
                    fused_peak = result[f"fused_{prefix}_peak_hz"]
                    raw_contrast = result[f"raw_{prefix}_contrast"]
                    fused_contrast = result[f"fused_{prefix}_contrast"]
                row.update(actual_bands=R,
                    band_bounds_hz=";".join(f"{a:.6f}-{b:.6f}" for a, b in bands),
                    band_centers_hz=";".join(f"{(a+b)/2:.6f}" for a, b in bands),
                    possible_band_pairs=R*(R-1)//2,
                    valid_band_pair_windows=result["frequency_pair_count"],
                    frequency_triplets=result["frequency_triplet_count"],
                    time_endpoints=len(result["candidate_impacts_s"]),
                    time_pairs=result["eligible_time_pairs"],
                    target_name=target, theoretical_hz=expected,
                    raw_target_peak_hz=raw_peak, fused_target_peak_hz=fused_peak,
                    raw_target_contrast=raw_contrast,
                    fused_target_contrast=fused_contrast,
                    target_error_hz=abs(fused_peak-expected),
                    unlabelled_raw_peak_hz=result["unlabelled_raw_peak_hz"],
                    unlabelled_fused_peak_hz=result["unlabelled_fused_peak_hz"],
                    retained_pixel_fraction=result["retained_pixel_fraction"],
                    fs_hz=result["fs_hz"], wvd_frequency_bins=result["wvd_size"][0],
                    wvd_time_bins=result["wvd_size"][1])
            rows.append(row)
    assert len(rows) == 105, f"Expected 105 segment/R rows, got {len(rows)}"
    rows.sort(key=lambda r: (r["dataset"], r["file"], r["start_sample"], r["R"]))
    keys = ["dataset", "file", "start_sample", "R", "status", "failure_reason",
            "actual_bands", "band_bounds_hz", "band_centers_hz",
            "possible_band_pairs", "valid_band_pair_windows", "frequency_triplets",
            "time_endpoints", "time_pairs", "target_name", "theoretical_hz",
            "raw_target_peak_hz", "fused_target_peak_hz", "target_error_hz",
            "raw_target_contrast", "fused_target_contrast", "unlabelled_raw_peak_hz",
            "unlabelled_fused_peak_hz", "retained_pixel_fraction", "fs_hz",
            "wvd_frequency_bins", "wvd_time_bins"]
    with args.output.open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=keys)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Collected {len(rows)} rows: {sum(r['status']=='PASS' for r in rows)} PASS, "
          f"{sum(r['status']=='FAIL' for r in rows)} FAIL")


if __name__ == "__main__":
    main()
