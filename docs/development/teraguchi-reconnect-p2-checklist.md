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

## Clipboard regression

After reconnect work, re-check on the clipboard-hardened Pilot build:

- [ ] Mac → Flame copy/paste still works (`Cmd+C` on Mac, `Ctrl+V` in Flame)
- [ ] Flame → Mac copy/paste still works (`Ctrl+C` on host, `Cmd+V` on Mac)
- [ ] Copy while Pilot is unfocused does not send to the host
