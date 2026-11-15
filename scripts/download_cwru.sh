#!/usr/bin/env bash
set -euo pipefail
dest="${1:-input/cwru}"
mkdir -p "$dest"
records=(105 130 144 156 106 131 145 158 107 132 146 159)
printf 'record,source_url,sha256,bytes\n' > "$dest/source_manifest.csv"
for record in "${records[@]}"; do
  curl --fail --location --show-error --silent --retry 3 \
    "https://engineering.case.edu/sites/default/files/${record}.mat" \
    --output "$dest/${record}.mat"
  test -s "$dest/${record}.mat"
  hash=$(sha256sum "$dest/${record}.mat" | cut -d' ' -f1)
  bytes=$(stat -c '%s' "$dest/${record}.mat")
  printf '%s,%s,%s,%s\n' "$record" "https://engineering.case.edu/sites/default/files/${record}.mat" "$hash" "$bytes" >> "$dest/source_manifest.csv"
done
(
  cd "$dest"
  sha256sum -c <<'CHECKSUMS'
f80b0ea04fd06b372a0eaec7c056543ea37e4bb4727a5b173d2a5bacd2aa9cab  105.mat
35a095307d0971477049b343a1b5981dde465a58fb7f233ad89b035068c1717d  130.mat
CHECKSUMS
)
