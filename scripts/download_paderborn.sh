#!/usr/bin/env bash
set -euo pipefail
root="${1:-input/paderborn}"
mkdir -p "$root"
for bearing in K001 KA04 KI04; do
  archive="$root/${bearing}.rar"
  target="$root/$bearing"
  mkdir -p "$target"
  curl --fail --location --show-error --silent --retry 3 --max-time 420 \
    "https://groups.uni-paderborn.de/kat/BearingDataCenter/${bearing}.rar" \
    --output "$archive"
  sha256sum "$archive"
  unar -quiet -no-directory -output-directory "$target" "$archive" \
    "${bearing}/N15_M07_F10_${bearing}_1.mat" \
    "${bearing}/N15_M07_F10_${bearing}_2.mat" \
    "${bearing}/N15_M07_F10_${bearing}_3.mat" \
    "${bearing}/measuring_log_${bearing}.pdf"
  ls -lh "$target"
  rm "$archive"
done
