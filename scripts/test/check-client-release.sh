#!/usr/bin/env bash
# Synthetic package bytes and ephemeral Ed25519 keys; no installation or network.
set -euo pipefail
umask 077
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-client-release.sh ABSOLUTE_PRIVATE_OUTPUT}
: "${PLANK_MAC_CLIENT_DEPS:?Set the retained Mac client dependency root}"
[[ "$output" == /* ]] || exit 2
mkdir -p "$output"
if git -C "$output" rev-parse --show-toplevel >/dev/null 2>&1; then exit 2; fi
export DYLD_LIBRARY_PATH="$PLANK_MAC_CLIENT_DEPS/install/lib"
export PLANK_TEST_OPENSSL="$PLANK_MAC_CLIENT_DEPS/install/bin/openssl"
python3 -B "$source_root/tests/packaging/test-client-release.py" > "$output/tests.txt" 2>&1
cat "$output/tests.txt"
