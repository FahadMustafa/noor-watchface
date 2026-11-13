#!/usr/bin/env bash
# Build, unit-test and screenshot the face in the headless simulator container.
# usage: tools/sim.sh test | shot [out.png]
set -euo pipefail
cd "$(dirname "$0")/.."
SDK=$(~/go/bin/connect-iq-sdk-manager-cli sdk current-path)
SDK=${SDK%/}
KEY=~/.Garmin/developer_key.der
mode=${1:?test or shot}
out=${2:-bin/screenshot.png}

if [ "$mode" = test ]; then
  "$SDK/bin/monkeyc" -d fr245m -f monkey.jungle -o bin/test.prg -y "$KEY" -l 3 -w --unit-test
  prg=bin/test.prg; flags=-t
else
  "$SDK/bin/monkeyc" -d fr245m -f monkey.jungle -o bin/noor.prg -y "$KEY" -l 3 -w
  prg=bin/noor.prg; flags=
fi

docker run --rm -v ~/.Garmin:/home/dev/.Garmin -v "$PWD":/work ciq-sim bash -c "
  Xvfb :1 -screen 0 1024x768x24 >/dev/null 2>&1 & export DISPLAY=:1; sleep 2
  '${SDK/$HOME//home/dev}/bin/simulator' >/tmp/sim.log 2>&1 & sleep 6
  if [ '$mode' = test ]; then
    timeout 120 '${SDK/$HOME//home/dev}/bin/monkeydo' $prg fr245m $flags
  else
    timeout 30 '${SDK/$HOME//home/dev}/bin/monkeydo' $prg fr245m & sleep 12
    win=\$(xdotool search --name 'CIQ Simulator' | head -1)
    import -window \"\$win\" $out
    kill %2 2>/dev/null || true
  fi
"
