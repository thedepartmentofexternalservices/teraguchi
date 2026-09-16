# Teraguchi P2 reconnect checklist (1.0.116)

Use Host/Client candidates from `artifacts/packages/candidates/1.0.116-reconnect-lifecycle/`
or the operator-installed 1.0.116 pair on dxs-flame-06. Record results in private
audit notes, not Git.

## Scenarios

- [ ] Normal login and logout through Teraguchi Pilot
- [ ] Temporary network outage → **Ask** prompt appears before hard disconnect
- [ ] **Keep Waiting** → session recovers when the host returns
- [ ] **Disconnect** while paused → clean teardown, no zombie host session
- [ ] Definitive auth/TLS/permission rejection stops retrying (no credential spam)

## Do not

- Induce production account lockouts for a test
- Relabel an old candidate package after merging main

## Clipboard regression (2026-09-16 baseline)

After reconnect work, re-check on the clipboard-qualified Pilot build:

- [ ] Mac → Flame copy/paste still works
- [ ] Flame → Mac copy/paste still works
