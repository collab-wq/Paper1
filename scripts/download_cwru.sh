#!/usr/bin/env bash
set -euo pipefail
dest="${1:-input/cwru}"
mkdir -p "$dest"
for record in 97 105 118 130; do
  curl --fail --location --show-error --silent --retry 3 \
    "https://engineering.case.edu/sites/default/files/${record}.mat" \
    --output "$dest/${record}.mat"
done
(
  cd "$dest"
  sha256sum -c <<'CHECKSUMS'
16bf48babcf1c7ac224bc1a81cd9eafdb27e42d5cf559761907e067e8e  97.mat
f80b0ea04fd06b372a0eaec7c056543ea37e4bb4727a5b173d2a5bacd2aa9cab  105.mat
b00628f8dd8d1d930af77fa465d1e5cdb385fe259489053f91f3680bda7f640e  118.mat
35a095307d0971477049b343a1b5981dde465a58fb7f233ad89b035068c1717d  130.mat
CHECKSUMS
)
