#!/usr/bin/env bash
# Build, unit-test and screenshot the face in the headless simulator container.
# usage: tools/sim.sh test | shot [out.png] | check device...
# shot sets a Riyadh position and sample steps/calories through the simulator's dialogs
# (xdotool clicks at fixed coordinates on a 1024x1400 Xvfb screen).
set -euo pipefail
cd "$(dirname "$0")/.."
SDK=$(~/go/bin/connect-iq-sdk-manager-cli sdk current-path)
SDK=${SDK%/}
CSDK=${SDK/$HOME//home/dev}
KEY=~/.Garmin/developer_key.der
mode=${1:?test, shot or check}

# check: build and run each device at the simulator's default position (Kansas, so US Central
# time), print the console (runtime errors show up there) and save bin/check/<device>.png.
if [ "$mode" = check ]; then
  shift
  mkdir -p bin/check
  for d in "$@"; do "$SDK/bin/monkeyc" -d "$d" -f monkey.jungle -o "bin/check/$d.prg" -y "$KEY" -l 3 -w >/dev/null; done
  docker run --rm -e TZ=CST6 -v ~/.Garmin:/home/dev/.Garmin -v "$PWD":/work ciq-sim bash -c "
    Xvfb :1 -screen 0 1024x1400x24 >/dev/null 2>&1 & export DISPLAY=:1; sleep 2
    '$CSDK/bin/simulator' >/tmp/sim.log 2>&1 & sleep 6
    for d in $*; do
      echo \"== \$d\"
      timeout 15 '$CSDK/bin/monkeydo' bin/check/\$d.prg \$d 2>&1 | grep -v -i -e gtk -e 'not properly signed' | tail -5
      eval \$(xdotool getwindowgeometry --shell \$(xdotool search --name 'CIQ Simulator' | head -1))
      import -window root -crop \${WIDTH}x\${HEIGHT}+0+0 /work/bin/check/\$d.png
    done
  "
  exit
fi
out=${2:-screenshot.png}

if [ "$mode" = test ]; then
  "$SDK/bin/monkeyc" -d fr245m -f monkey.jungle -o bin/test.prg -y "$KEY" -l 3 -w --unit-test
else
  "$SDK/bin/monkeyc" -d fr245m -f monkey.jungle -o bin/noor.prg -y "$KEY" -l 3 -w
fi

docker run --rm -e TZ=UTC-3 -v ~/.Garmin:/home/dev/.Garmin -v "$PWD":/work ciq-sim bash -c "
  Xvfb :1 -screen 0 1024x1400x24 >/dev/null 2>&1 & export DISPLAY=:1; sleep 2
  '$CSDK/bin/simulator' >/tmp/sim.log 2>&1 & sleep 6
  if [ '$mode' = test ]; then
    timeout 120 '$CSDK/bin/monkeydo' bin/test.prg fr245m -t
    exit
  fi
  timeout 20 '$CSDK/bin/monkeydo' bin/noor.prg fr245m >/dev/null 2>&1 || true
  # Settings > Set Position
  xdotool mousemove 73 12 click 1; sleep 1; xdotool mousemove 106 912 click 1; sleep 2
  xdotool key ctrl+a; xdotool type '24.7136, 46.6753'; xdotool key Return; sleep 1
  # Simulation > Activity Monitoring > Set Activity Monitor Info: goal, steps, calories
  xdotool mousemove 150 12 click 1; sleep 1; xdotool mousemove 200 87; sleep 1
  xdotool mousemove 400 87; sleep 0.3; xdotool mousemove 420 112 click 1; sleep 2
  for c in '276 8000' '396 6482' '636 1847'; do
    set -- \$c; xdotool mousemove \$1 91 click --repeat 2 1; sleep 0.4
    xdotool key ctrl+a; xdotool type \$2; xdotool key Return; sleep 0.4
  done
  xdotool mousemove 956 587 click 1; sleep 1
  xdotool windowmove \$(xdotool search --name 'Edit Activity Monitor Info' | head -1) 1100 0
  # Relaunch so the face redraws with the new data
  timeout 20 '$CSDK/bin/monkeydo' bin/noor.prg fr245m >/dev/null 2>&1 || true
  import -window root -crop 386x604+1+27 /work/$out
"
echo "wrote $out"
