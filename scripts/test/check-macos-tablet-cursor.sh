#!/usr/bin/env bash
# Hidden native windows only; no host connection, input injection or focus change.
set -euo pipefail
umask 077
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-macos-tablet-cursor.sh ABSOLUTE_PRIVATE_OUTPUT [--build-only]}
: "${PLANK_QT_ROOT:?Set the pinned Qt root}"
: "${PLANK_MAC_CLIENT_DEPS:?Set the pinned Mac dependency root}"
[[ "$output" == /* && $(uname -s) == Darwin ]] || exit 2
[[ $# == 1 || ( $# == 2 && $2 == --build-only ) ]] || exit 2
mkdir -p "$output"
if git -C "$output" rev-parse --show-toplevel >/dev/null 2>&1; then exit 2; fi
cd "$output"
"$PLANK_QT_ROOT/bin/qmake" "$source_root/tests/input/macos-tablet-cursor.pro"
make -j4
if [[ ${2:-} != --build-only ]]; then ./mac-tablet-cursor; fi
