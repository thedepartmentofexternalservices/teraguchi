#!/usr/bin/env bash
# Offline guest-policy and endpoint-inventory guard. No Tailscale calls.
set -euo pipefail
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-guest-access-prep.sh ABSOLUTE_PRIVATE_OUTPUT}
[[ "$output" == /* ]] || exit 2
mkdir -p "$output"
if git -C "$output" rev-parse --show-toplevel >/dev/null 2>&1; then
  exit 2
fi
python3 -B "$source_root/scripts/test/check-tailscale-policy.py" \
  > "$output/tailscale-policy.txt" 2>&1
cat "$output/tailscale-policy.txt"
