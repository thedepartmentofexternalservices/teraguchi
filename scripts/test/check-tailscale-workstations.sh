#!/usr/bin/env bash
# Native parser/process tests. Uses synthetic child processes, never Tailscale/hosts.
set -euo pipefail
umask 077
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-tailscale-workstations.sh ABSOLUTE_PRIVATE_OUTPUT}
: "${PLANK_MAC_CLIENT_DEPS:?Set the retained Mac client dependency root}"
: "${PLANK_QT_ROOT:?Set the pinned Qt 6.10.2 root}"
[[ "$output" == /* ]] || exit 2
mkdir -p "$output"
if git -C "$output" rev-parse --show-toplevel >/dev/null 2>&1; then exit 2; fi
[[ $("$PLANK_QT_ROOT/bin/qmake" -query QT_VERSION) == 6.10.2 ]] || exit 2
mkdir -p "$output/build"
(
    cd "$output/build"
    "$PLANK_QT_ROOT/bin/qmake" "$source_root/tests/tailscale/provider.pro"
    make -j4
) > "$output/build.log" 2>&1
"$output/build/tailscale-provider-tests" -o "$output/tests.txt,txt"
