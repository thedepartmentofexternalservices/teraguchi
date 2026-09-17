#!/usr/bin/env bash
# Uninstalled strict Mac client smoke test. No configured studio or host access.
set -euo pipefail
umask 077
: "${PLANK_CLIENT_EXECUTABLE:?Set the built client executable}"
output=${1:?usage: check-workstation-client.sh ABSOLUTE_PRIVATE_OUTPUT}
[[ "$output" == /* && "$PLANK_CLIENT_EXECUTABLE" == /* ]] || exit 2
mkdir -p "$output"
if git -C "$output" rev-parse --show-toplevel >/dev/null 2>&1; then exit 2; fi
python3 - "$PLANK_CLIENT_EXECUTABLE" "$output" <<'PY'
from pathlib import Path
import os
import subprocess
import sys

exe, directory = sys.argv[1:]
out = Path(directory)
# Each run gets blank settings. Never inspect or overwrite the installed profile.
import tempfile
work = Path(tempfile.mkdtemp(prefix='portable-', dir=out))
(work / 'portable.dat').touch()
env = os.environ.copy()
env.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QML_DISABLE_DISK_CACHE='1')
for i, args in enumerate((['--workstations', '--studio-dns-suffix', '*.ts.net'],
                           ['--studio-dns-suffix', 'studio-example.ts.net'],
                           ['--workstations', 'stream', 'example.invalid'],
                           ['--workstations', '--studio-config', 'relative-file'],
                           ['--studio-config', '/nonexistent/example.teraguchi-studio'],
                           ['--workstations', '--studio-config', '/nonexistent/example.teraguchi-studio'],
                           ['--workstations', '--studio-config', '/nonexistent/example.teraguchi-studio', '--studio-dns-suffix', 'studio-example.ts.net'])):
    with (work / f'invalid-{i}.txt').open('w') as log:
        result = subprocess.run([exe, *args], cwd=work, env=env, stdout=log,
                                stderr=subprocess.STDOUT, timeout=10)
    if result.returncode == 0:
        raise SystemExit('Invalid setup unexpectedly accepted')
with (work / 'launch.txt').open('w') as log:
    process = subprocess.Popen([exe, '--workstations'], cwd=work, env=env,
                               stdout=log, stderr=subprocess.STDOUT)
    try:
        try:
            process.wait(timeout=3)
            raise SystemExit('Picker exited during startup')
        except subprocess.TimeoutExpired:
            pass
        process.terminate()
        if process.wait(timeout=15) != 0:
            raise SystemExit('Picker did not quit cleanly')
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)
logs = '\n'.join(p.read_text(errors='replace') for p in work.glob('*.log'))
if 'Teraguchi development picker loaded' not in logs:
    raise SystemExit('Picker load marker missing')
for line in logs.splitlines():
    if any(token in line for token in ('TypeError', 'ReferenceError', 'Binding loop', 'QQmlApplicationEngine failed', 'qrc:/gui/')):
        raise SystemExit('QML failure; inspect the private smoke log')
print('Picker loaded with blank settings; invalid configuration rejected; idle Quit passed. No studio configured.')
PY
