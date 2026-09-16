# Teraguchi Flame UI monitor origin

Updated 2026-09-16. Flame follows the X11 output at `+0+0`, not RandR
`primary`. On dual-horizontal hosts, Teraguchi must let the operator choose
which side holds Flame UI.

## Operator contract

| Setting | Flame UI | OS primary (optional) |
|---|---|---|
| Left (default) | Left monitor at `+0+0` | Either side |
| Right | Chosen output at `+0+0` | Either side |

Qualification on dxs-flame-06 used:

```bash
xrandr --output DP-2 --pos 0x0 --output DP-0 --pos 3840x0 --output DP-2 --primary
```

## Launch parameter (planned)

When `plankHostLayout=dual-horizontal`, the client sends:

- `plankFlameUiOrigin=left` (default)
- `plankFlameUiOrigin=right`

`left` is ignored on single-output and physical layouts. `right` is rejected
there so a miswired client fails instead of silently pinning the wrong output.

## Implementation status

| Layer | Status |
|---|---|
| `plank-display-prepare --flame-ui-origin` | Done in root packaging |
| Dual canvas ceiling check (8192x2160) | Done |
| `--cleanup` without `host.conf` | Done |
| Host supervisor live xrandr / MetaMode swap | Pending host submodule |
| Launch parse + topology `flame_ui` echo | Pending host submodule |
| Teraguchi picker + per-host persistence | Pending client UI |

## Acceptance

- Flame UI Right opens Flame on the right X monitor without SSH `xrandr`
- Reconnect and reboot keep the saved side
- Topology shows exactly one `flame_ui` output on dual-horizontal hosts
