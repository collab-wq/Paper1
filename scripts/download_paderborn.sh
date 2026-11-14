#!/usr/bin/env bash
set -euo pipefail
root="${1:-input/paderborn}"
mkdir -p "$root"
declare -A expected_sha=(
  [K001]=0f119ebdb28fb2f4d9fac1beb1319429f63f7ae1256c23c872f280f3560918e5
  [KA04]=6fc317157e2cd4cb55bc54d6fac1b1753f8ab31abcccd1ac68cbfb78e5e8299d
  [KI04]=8fde861a9ceac4b41fe8a030b4c5bbb4b9b9af0590d9338a8de0150b4661be77
)
for bearing in K001 KA04 KI04; do
  archive="$root/${bearing}.rar"
  target="$root/$bearing"
  mkdir -p "$target"
  curl --fail --location --show-error --silent --retry 3 --max-time 420 \
    "https://groups.uni-paderborn.de/kat/BearingDataCenter/${bearing}.rar" \
    --output "$archive"
  sha256sum "$archive"
  printf '%s  %s\n' "${expected_sha[$bearing]}" "$archive" | sha256sum --check
  unar -quiet -no-directory -output-directory "$target" "$archive" \
    "${bearing}/N15_M07_F10_${bearing}_1.mat" \
    "${bearing}/N15_M07_F10_${bearing}_2.mat" \
    "${bearing}/N15_M07_F10_${bearing}_3.mat" \
    "${bearing}/measuring_log_${bearing}.pdf"
  if [[ -d "$target/$bearing" ]]; then
    mv "$target/$bearing"/* "$target/"
    rmdir "$target/$bearing"
  fi
  for n in 1 2 3; do
    test -s "$target/N15_M07_F10_${bearing}_${n}.mat"
  done
  ls -lh "$target"
  rm "$archive"
done
