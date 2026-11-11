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
  7z t "$archive" | tail -3
  7z e -y -o"$target" "$archive" \
    "${bearing}/N15_M07_F10_${bearing}_1.mat" \
    "${bearing}/N15_M07_F10_${bearing}_2.mat" \
    "${bearing}/N15_M07_F10_${bearing}_3.mat" >/dev/null
  7z e -y -o"$target" "$archive" '*.pdf' >/dev/null || true
  ls -lh "$target"
  rm "$archive"
done
