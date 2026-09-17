# P4 network impairment preparation

Updated 2026-09-15. This documents repeatable loss and endpoint-change cases from
the inherited [acceptance criteria](acceptance-criteria.md). It authorizes no live
impairment on production Flames, artist routes, or studio infrastructure.

## Required observation points

Run each accepted profile at:

- zero loss;
- 0.5%, 1%, 2%, 5%, and 10% independently random client-ingress packet loss;
- deterministic burst loss;
- reconnect after a temporary complete outage.

Record source symbols, repair symbols, pre-FEC loss, post-FEC loss, recovered
objects, unrecoverable objects, QUIC loss/RTT, queue high-water marks, and the
first visible failure. Remove impairment and verify normal routing after every run.

The in-session toolbar shows 10-second peaks for pre-FEC loss and sampled network
RTT. Session teardown logs publish final native transport counters. Use
`scripts/test/parse-session-transport-log.py` and
`scripts/test/prepare-p4-evidence-manifest.py --merge-transport-log` to attach
those values to a private P4 manifest. Toolbar peaks and teardown counters do
not prove pen-to-picture latency.

## Offline transport probe

For designated pilot endpoints only, the existing cross-host probe supports random
and periodic-burst impairment through a temporary nftables table:

```bash
export PLANK_TRANSPORT_CLIENT=artist-test-client
export PLANK_TRANSPORT_CLIENT_IP=203.0.113.10
export PLANK_TRANSPORT_SERVER_IP=203.0.113.20
export PLANK_TRANSPORT_LOSS_PERCENT=1
export PLANK_TRANSPORT_LOSS_PATTERN=random
bash scripts/test/prepare-p4-network-impairment.sh
```

Set `PLANK_P4_IMPAIRMENT_ACK=1` before running. The helper refuses example
addresses, requires explicit loss values from the accepted set, and always
removes the temporary nftables table on exit. A successful probe run does not
qualify Flame editing, WAN artist routes, or production Host/Client packages.

## Endpoint-change drills

Prepare separate manifest runs for:

- direct-path observation retained through a 30-minute load window;
- relay-path observation labeled explicitly and excluded from the direct-path gate;
- reconnect after complete outage;
- Tailscale endpoint change while the session remains assigned to the same host.

Live endpoint-change qualification remains operator-owned and is not implied by
this offline preparation.
