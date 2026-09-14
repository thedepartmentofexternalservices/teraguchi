#!/usr/bin/env bash
# Offline QML preview only. No product launch, saved settings or host access.
set -euo pipefail
umask 077
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-workstation-ui.sh ABSOLUTE_PRIVATE_OUTPUT}
: "${PLANK_QT_ROOT:?Set the pinned Qt 6.10.2 root}"
[[ "$output" == /* ]] || { echo 'Output must be absolute and outside Git.' >&2; exit 2; }
mkdir -p "$output"
if git -C "$output" rev-parse --show-toplevel >/dev/null 2>&1; then
    echo 'Keep UI captures and build logs outside Git checkouts.' >&2
    exit 2
fi
qtbin="$PLANK_QT_ROOT/bin"
[[ $("$qtbin/qmake" -query QT_VERSION) == 6.10.2 ]] || exit 2
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic
mkdir -p "$output/build"
(
    cd "$output/build"
    "$qtbin/qmake" "$source_root/probes/workstation-picker/preview.pro"
    make -j4
) > "$output/build.log" 2>&1
"$qtbin/qmltestrunner" -input "$source_root/tests/ui/workstation-picker" \
    -o "$output/qml-tests.txt,txt" > "$output/qml-runner.log" 2>&1
"$output/build/teraguchi-ui-preview" --verify-network-block > "$output/network-block.log" 2>&1
python3 - "$output" <<'PY'
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

out = Path(sys.argv[1])
log = (out / 'qml-tests.txt').read_text()
# Qt's first font-alias lookup is a platform notice, not a QML binding error.
if any('QWARN' in line and 'qt.qpa.fonts:' not in line for line in log.splitlines()):
    raise SystemExit('Unexpected Qt/QML warning; inspect private test log.')
scenarios = ('ready', 'offline', 'occupied', 'incompatible', 'empty', 'connected',
             'interrupted', 'display-mismatch', 'source-depth', 'permissions',
             'seat-race', 'connection-failure')
captures = []
for compact, states in ((False, scenarios), (True, ('ready', 'display-mismatch', 'interrupted'))):
    for state in states:
        name = state + ('-compact' if compact else '')
        image = out / (name + '.png')
        args = [str(out / 'build/teraguchi-ui-preview'), '--scenario', state, '--capture', str(image)]
        if compact:
            args.append('--compact')
        with (out / (name + '.log')).open('w') as record:
            subprocess.run(args, stdout=record, stderr=subprocess.STDOUT, timeout=15, check=True)
        captures.append({'file': image.name, 'sha256': hashlib.sha256(image.read_bytes()).hexdigest()})
summary = {'kind': 'offline-ui-preview', 'network_block': 'passed',
           'qt_tests': next(line for line in log.splitlines() if line.startswith('Totals:')),
           'captures': captures, 'hardware_qualified': False, 'installed': False}
(out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(summary['qt_tests'])
print('Network requests blocked; 15 simulated screens rendered. No workstation connected.')
PY
