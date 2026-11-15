#!/usr/bin/env bash
set -euo pipefail
root="${1:-input/paderborn}"
mkdir -p "$root"
declare -A expected_sha=(
  [K001]=0f119ebdb28fb2f4d9fac1beb1319429f63f7ae1256c23c872f280f3560918e5
  [KA04]=6fc317157e2cd4cb55bc54d6fac1b1753f8ab31abcccd1ac68cbfb78e5e8299d
  [KI04]=8fde861a9ceac4b41fe8a030b4c5bbb4b9b9af0590d9338a8de0150b4661be77
  [KA16]=3e300d2e3402b47a18ce9c75694d3146f6e4b5f86bcd1d159f4938221fb261b6
  [KB24]=ae5928ee2ed02773e3787aeceaae73074b15ff3ae158cd932c7a6865fbc9c1ff
  [KI21]=1e3c563fa1d1564e3586736189b2e0807688389b549944af4a06908485c1d5bf
  [KI17]=d80dbdb612cfaeb7ba1ffe6387c52c4d938084b2466e55d96a5528aff4d8b084
)
bearing_list=(KA04 KA16 KB24 KI21 KI17 KI04)
printf 'record,source_url,sha256,bytes\n' > "$root/source_manifest.csv"
printf 'bearing,source_url,archive_sha256,archive_bytes\n' > "$root/archive_manifest.csv"
for bearing in "${bearing_list[@]}"; do
  archive="$root/${bearing}.rar"
  target="$root/$bearing"
  mkdir -p "$target"
  curl --fail --location --show-error --silent --retry 3 --max-time 420 \
    "https://groups.uni-paderborn.de/kat/BearingDataCenter/${bearing}.rar" \
    --output "$archive"
  sha256sum "$archive"
  digest=$(sha256sum "$archive" | cut -d' ' -f1)
  bytes=$(stat -c '%s' "$archive")
  printf '%s,%s,%s,%s\n' "$bearing" "https://groups.uni-paderborn.de/kat/BearingDataCenter/${bearing}.rar" "$digest" "$bytes" >> "$root/archive_manifest.csv"
  if [[ -n "${expected_sha[$bearing]:-}" ]]; then
    printf '%s  %s\n' "${expected_sha[$bearing]}" "$archive" | sha256sum --check
  fi
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
    file="$target/N15_M07_F10_${bearing}_${n}.mat"
    test -s "$file"
    matsha=$(sha256sum "$file" | cut -d' ' -f1)
    matsize=$(stat -c '%s' "$file")
    printf '%s,%s,%s,%s\n' "${bearing}_${n}" \
      "https://groups.uni-paderborn.de/kat/BearingDataCenter/${bearing}.rar#${bearing}/N15_M07_F10_${bearing}_${n}.mat" \
      "$matsha" "$matsize" >> "$root/source_manifest.csv"
  done
  ls -lh "$target"
  rm "$archive"
done
