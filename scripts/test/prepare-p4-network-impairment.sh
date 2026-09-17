#!/usr/bin/env bash
# Run a bounded cross-host transport loss probe on designated pilot endpoints only.
set -euo pipefail
source_root=$(cd "$(dirname "$0")/../.." && pwd)
: "${PLANK_P4_IMPAIRMENT_ACK:?Set PLANK_P4_IMPAIRMENT_ACK=1 after reading docs/development/teraguchi-p4-network-impairment.md}"
: "${PLANK_TRANSPORT_CLIENT:?Set the SSH target for the pilot client probe host}"
: "${PLANK_TRANSPORT_CLIENT_IP:?Set the pilot client ingress IP}"
: "${PLANK_TRANSPORT_SERVER_IP:?Set the pilot server egress IP}"

loss=${PLANK_TRANSPORT_LOSS_PERCENT:-0}
pattern=${PLANK_TRANSPORT_LOSS_PATTERN:-random}
if [[ ! "$loss" =~ ^(0|0\.5|1|2|5|10)$ ]]; then
  echo 'loss percent must be one of: 0 0.5 1 2 5 10' >&2
  exit 2
fi
case "$PLANK_TRANSPORT_CLIENT_IP" in 203.0.113.*) echo 'refusing documentation example addresses' >&2; exit 2 ;; esac
case "$PLANK_TRANSPORT_SERVER_IP" in 203.0.113.*) echo 'refusing documentation example addresses' >&2; exit 2 ;; esac
export PLANK_TRANSPORT_LOSS_PERCENT=$loss
export PLANK_TRANSPORT_LOSS_PATTERN=$pattern
bash "$source_root/scripts/test/run-plank-transport-crosshost.sh"
