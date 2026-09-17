#!/usr/bin/env bash
# Uses injected status reads and Settings openers. No permission API or UI action.
set -euo pipefail
umask 077
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-macos-input-permissions.sh ABSOLUTE_PRIVATE_OUTPUT}
: "${PLANK_QT_ROOT:?Set the pinned Qt 6.10.2 root}"
[[ "$output" == /* ]] || exit 2
mkdir -p "$output"
if git -C "$output" rev-parse --show-toplevel >/dev/null 2>&1; then exit 2; fi
[[ $("$PLANK_QT_ROOT/bin/qmake" -query QT_VERSION) == 6.10.2 ]] || exit 2
mkdir -p "$output/build"
(
    cd "$output/build"
    "$PLANK_QT_ROOT/bin/qmake" "$source_root/tests/input/macos-permissions.pro"
    make -j4
) > "$output/build.log" 2>&1
"$output/build/mac-input-permissions-tests" -o "$output/tests.txt,txt"
