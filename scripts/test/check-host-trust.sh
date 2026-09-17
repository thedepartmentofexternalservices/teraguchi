#!/usr/bin/env bash
# Production HTTPS against local synthetic servers. No workstation or Tailscale use.
set -euo pipefail
umask 077
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-host-trust.sh ABSOLUTE_PRIVATE_OUTPUT}
: "${PLANK_MAC_CLIENT_DEPS:?Set the retained Mac client dependency root}"
: "${PLANK_QT_ROOT:?Set the pinned Qt 6.10.2 root}"
[[ "$output" == /* ]] || exit 2
mkdir -p "$output"
if git -C "$output" rev-parse --show-toplevel >/dev/null 2>&1; then exit 2; fi
[[ $("$PLANK_QT_ROOT/bin/qmake" -query QT_VERSION) == 6.10.2 ]] || exit 2
mkdir -p "$output/build"
(
    cd "$output/build"
    "$PLANK_QT_ROOT/bin/qmake" "$source_root/tests/tailscale/host-trust.pro"
    make -j4
) > "$output/build.log" 2>&1
export DYLD_LIBRARY_PATH="$PLANK_MAC_CLIENT_DEPS/install/lib"
python3 -B "$source_root/tests/tailscale/host-trust-loopback.py" \
    --client "$output/build/host-trust-probe" --output "$output" \
    --openssl "$PLANK_MAC_CLIENT_DEPS/install/bin/openssl" > "$output/tests.txt" 2>&1
cat "$output/tests.txt"
