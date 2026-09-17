# Teraguchi Flame UI monitor origin

Updated 2026-09-16. Flame follows the X11 output at `+0+0`, not RandR
`primary`. On dual-horizontal hosts, Teraguchi must let the operator choose
which side holds Flame UI.

## Operator contract

| Setting | Flame UI | OS primary (optional) |
|---|---|---|
| Left (default) | Left monitor at `+0+0` | Either side |
| Right | Chosen output at `+0+0` | Either side |

Earlier operator observations motivate this contract. Machine-specific commands
and qualification receipts remain in private notes; they do not qualify the
current integration candidate.

## Launch parameter (planned)

When `plankHostLayout=dual-horizontal`, the client sends:

- `plankFlameUiOrigin=left` (default)
- `plankFlameUiOrigin=right`

Clients omit the field for single-output and physical layouts. The
`plank-display-prepare` CLI rejects `--flame-ui-origin right` unless the
requested layout is `dual-horizontal`.

## Implementation status

| Layer | Status |
|---|---|
| `plank-display-prepare --flame-ui-origin` | Boot-overlay generation complete; hardware validation pending |
| Host supervisor live xrandr / MetaMode swap | Pending host submodule |
| Launch parse + topology `flame_ui` echo | Pending host submodule |
| Teraguchi picker + per-host persistence | Pending client UI |
| Client launch wiring | Pending |

## Acceptance

- Flame UI Right opens Flame on the right X monitor without SSH `xrandr`
- Reconnect and reboot keep the saved side
- Topology shows exactly one `flame_ui` output on dual-horizontal hosts
