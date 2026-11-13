#!/usr/bin/env bash
# Build a release .prg for every product in manifest.xml into bin/release/noor-<device>.prg.
set -euo pipefail
cd "$(dirname "$0")/.."
SDK=$(~/go/bin/connect-iq-sdk-manager-cli sdk current-path)
rm -f bin/release/noor-*.prg
mkdir -p bin/release
for d in $(grep -o 'product id="[^"]*"' manifest.xml | cut -d'"' -f2); do
  "${SDK%/}/bin/monkeyc" -d "$d" -f monkey.jungle -o "bin/release/noor-$d.prg" -y ~/.Garmin/developer_key.der -l 3 -w -r >/dev/null
  echo "bin/release/noor-$d.prg"
done
