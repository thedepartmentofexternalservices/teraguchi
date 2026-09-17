#!/usr/bin/env bash
# Synthetic status and private temporary files; no real logs, permissions or UI.
set -euo pipefail
umask 077
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-support-diagnostics.sh ABSOLUTE_PRIVATE_OUTPUT}
: "${PLANK_QT_ROOT:?Set the pinned Qt 6.10.2 root}"
[[ "$output" == /* ]] || exit 2
mkdir -p "$output/build"
if git -C "$output" rev-parse --show-toplevel >/dev/null 2>&1; then exit 2; fi
[[ $("$PLANK_QT_ROOT/bin/qmake" -query QT_VERSION) == 6.10.2 ]] || exit 2
(
    cd "$output/build"
    "$PLANK_QT_ROOT/bin/qmake" "$source_root/tests/support/diagnostics.pro"
    make -j4
) > "$output/build.log" 2>&1
"$output/build/support-diagnostics-tests" -o "$output/tests.txt,txt"
cat "$output/tests.txt"
