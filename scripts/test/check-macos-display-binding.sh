#!/usr/bin/env bash
# Synthetic identities/modes only. No host, UI activation, or permission request.
set -euo pipefail
umask 077
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-macos-display-binding.sh ABSOLUTE_PRIVATE_OUTPUT}
: "${PLANK_QT_ROOT:?Set the pinned Qt 6.10.2 root}"
: "${PLANK_MAC_CLIENT_DEPS:?Set the retained Mac client dependency root}"
[[ "$output" == /* ]] || exit 2
mkdir -p "$output"
if git -C "$output" rev-parse --show-toplevel >/dev/null 2>&1; then exit 2; fi
[[ $("$PLANK_QT_ROOT/bin/qmake" -query QT_VERSION) == 6.10.2 ]] || exit 2
mkdir -p "$output/build"
(
    cd "$output/build"
    "$PLANK_QT_ROOT/bin/qmake" "$source_root/tests/video/macos-display-binding.pro"
    make -j4
) > "$output/build.log" 2>&1
"$output/build/mac-display-binding-tests" -o "$output/tests.txt,txt"
if [[ ${2:-} == --native ]]; then
    mkdir -p "$output/native-build"
    (
        cd "$output/native-build"
        "$PLANK_QT_ROOT/bin/qmake" "$source_root/tests/video/macos-window-placement.pro"
        make -j4
    ) > "$output/native-build.log" 2>&1
    "$output/native-build/mac-window-placement" > "$output/native-tests.txt" 2>&1
fi
