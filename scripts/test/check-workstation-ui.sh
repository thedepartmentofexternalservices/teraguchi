#!/usr/bin/env bash
# Isolated QML preview only. No product launch, saved settings or host access.
# Native capture opens short-lived sample windows and needs a Mac GUI session.
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
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=macOS
mkdir -p "$output/build"
(
    cd "$output/build"
    "$qtbin/qmake" "$source_root/probes/workstation-picker/preview.pro"
    make -j4
) > "$output/build.log" 2>&1
python3 - "$qtbin/qmltestrunner" "$source_root/tests/ui/workstation-picker" "$output" <<'PYTEST'
from pathlib import Path
import subprocess
import sys

runner, tests, output = sys.argv[1:]
out = Path(output)
with (out / 'qml-runner.log').open('w') as log:
    subprocess.run([runner, '-input', tests, '-o', str(out / 'qml-tests.txt') + ',txt'],
                   stdout=log, stderr=subprocess.STDOUT, timeout=60, check=True)
PYTEST
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
scenarios = ('support-displays', 'support-tablet', 'support-access', 'support-report', 'studio-needed', 'studio-ready', 'studio-expired', 'permission-panel-needed', 'permission-setup-needed', 'permission-setup-allowed', 'assignment-stale', 'assignment-refreshing', 'assignment-failure', 'ready', 'offline', 'occupied', 'incompatible', 'empty', 'connected',
             'interrupted', 'display-mismatch', 'source-depth', 'permissions',
             'seat-race', 'connection-failure', 'power-off', 'power-standby',
             'power-unknown', 'power-starting', 'power-unavailable', 'power-no-access', 'power-stale')
captures = []
capture_env = os.environ.copy()
native_capture = capture_env.get('PLANK_UI_NATIVE_CAPTURE') == '1'
if native_capture:
    capture_env['QT_QPA_PLATFORM'] = 'cocoa'
    capture_env.pop('QT_QUICK_BACKEND', None)

for appearance, compact, states in (('light', False, scenarios), ('light', True, ('support-displays', 'support-report', 'studio-expired', 'permission-panel-needed', 'permission-setup-needed', 'ready', 'display-mismatch', 'interrupted', 'power-off', 'power-unknown', 'power-starting')), ('dark', False, ('support-report', 'permission-setup-allowed', 'ready', 'power-off', 'interrupted')), ('dark', True, ('power-unknown',))):
    for state in states:
        name = state + ('-compact' if compact else '') + ('-dark' if appearance == 'dark' else '')
        image = out / (name + '.png')
        args = [str(out / 'build/teraguchi-ui-preview'), '--scenario', state, '--capture', str(image), '--appearance', appearance]
        if compact:
            args.append('--compact')
        with (out / (name + '.log')).open('w') as record:
            subprocess.run(args, env=capture_env, stdout=record, stderr=subprocess.STDOUT, timeout=15, check=True)
        captures.append({'file': image.name, 'sha256': hashlib.sha256(image.read_bytes()).hexdigest()})
summary = {'kind': 'offline-ui-preview', 'network_block': 'passed',
           'captures': captures, 'capture_platform': 'cocoa' if native_capture else 'offscreen',
           'native_control_pixels_available': native_capture,
           'qt_tests': next(line for line in log.splitlines() if line.startswith('Totals:')),
           'hardware_qualified': False, 'installed': False}
(out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(summary['qt_tests'])
print(f"Network requests blocked; {len(captures)} simulated screens rendered. No workstation connected.")
PY
