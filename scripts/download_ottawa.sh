#!/usr/bin/env bash
set -euo pipefail
root="${1:-input/ottawa}"
mkdir -p "$root"
base='https://prod-dcd-datasets-public-files-eu-west-1.s3.eu-west-1.amazonaws.com'
declare -A ids=(
  [I-A-2]=6fc987d1-78bb-4453-872f-418c11883b38
  [I-B-2]=bd215a9b-65cc-40f7-870a-2e224a1ddf9c
  [I-C-2]=52003e3e-64ee-4df4-a54a-0313ef8e0b8f
  [O-A-2]=d0aa841a-0fd0-414f-9a5e-fb9f043ff631
  [O-B-2]=9f009c49-dc7d-4988-96f8-cbc59d948a43
  [O-C-2]=93cb5c8a-a522-4732-8589-1e7028cba72a
)
printf 'record,source_url,sha256,bytes\n' > "$root/source_manifest.csv"
for name in I-A-2 I-B-2 I-C-2 O-A-2 O-B-2 O-C-2; do
  url="$base/${ids[$name]}"
  curl --fail --location --show-error --silent --retry 4 --max-time 600 \
    "$url" --output "$root/$name.mat"
  test -s "$root/$name.mat"
  hash=$(sha256sum "$root/$name.mat" | cut -d' ' -f1)
  bytes=$(stat -c '%s' "$root/$name.mat")
  printf '%s,%s,%s,%s\n' "$name" "$url" "$hash" "$bytes" >> "$root/source_manifest.csv"
done
