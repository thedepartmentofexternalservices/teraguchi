# Teraguchi daily-work blockers

Updated 2026-09-16. Both items block normal Flame remote work on dual-monitor
hosts. They are parallel P3 product work, not post-pilot polish.

Qualification on dxs-flame-06 (2026-09-16) established:

- RandR `primary` and nvidia-settings "Make this the primary display" do not move
  Flame UI. Flame follows X11 origin (`+0+0`) and Xinerama enumeration order.
- PLANK headless currently pins `DFP-0` / virtual-1 at `+0+0` left and
  `DFP-2` / virtual-2 on the right (`plank-display-prepare`).
- Swapping positions live works:

  ```bash
  xrandr --output DP-2 --pos 0x0 --output DP-0 --pos 3840x0 --output DP-2 --primary
  ```

  After that swap: OS primary can remain on the left panel while Flame main UI
  sits on the right — the operator-confirmed desired layout.

- Teraguchi has no Mac ↔ Linux clipboard bridge. The inherited Moonlight
  `Ctrl+Option+Shift+V` path injects Mac clipboard text as keystrokes only; it
  is not documented product behavior and does not cover host → Mac copy.

Neither gate is satisfied by SSH workarounds, manual `xrandr`, or hidden
hotkeys.

## 1. Flame UI monitor selection

### Operator requirement

When the host presents two displays, the artist chooses which side owns Flame
main UI (menus, viewers, timeline). This is independent of:

- which Mac monitor(s) Teraguchi streams to;
- which output RandR marks `primary` for the desktop shell;
- nvidia-settings primary display.

The choice must survive reconnect and reboot without SSH.

### Product contract

| Layer | Behavior |
|---|---|
| Teraguchi picker | For two-display host sessions, expose **Flame UI: Left** / **Flame UI: Right**. Persist per host in the existing assignment snapshot. |
| Launch request | Send `plankFlameUiOrigin=left` or `right` with `plankHostLayout=dual-horizontal`. Default `left` preserves current headless layout. |
| Host supervisor | Apply swapped MetaMode positions and `nvidiaXineramaInfoOrder` before the authenticated session starts. For virtual headless: the output at `+0+0` is the Flame UI side; the companion output sits at `+width+0`. |
| Topology | Echo actual geometry in `/plank/topology`. `outputs[].primary` remains the RandR primary flag (shell menus); add explicit `flame_ui: true` on exactly one output when dual-horizontal is active. |
| Restore | Session end restores the pre-session MetaMode exactly (existing physical-lease behavior). |

### Implementation notes

- Start in `packaging/host/linux/bin/plank-display-prepare` (`--flame-ui-origin`)
  and the host display transition that already calls it.
- Do not require artists to edit `/etc/plank/host.conf`; the client launch
  request is authoritative for the session lease.
- Wacom tablet mapping must follow the same desktop geometry after swap.
- Teraguchi dual-Mac-output presentation is unchanged; this is host-side only.

### Acceptance

- [ ] Dual-horizontal session with **Flame UI: Right** opens Flame main UI on
  the right X monitor without manual `xrandr`.
- [ ] Reconnect with the same assignment keeps the same Flame UI side.
- [ ] Reboot + connect with saved assignment keeps the same Flame UI side.
- [ ] Single-output sessions ignore the control.
- [ ] Topology JSON shows one `flame_ui` output matching the picker.

## 2. Bidirectional clipboard sync

### Operator requirement

Copy on Mac, paste in Flame (and other Linux apps). Copy in Flame, paste on Mac.
Text is the first gate; images and files are out of scope for v1.

Normal shortcuts must work when the stream window is focused:

- Mac → host: `Cmd+C` locally, then `Ctrl+V` in Flame / remote apps.
- Host → Mac: `Ctrl+C` (or Flame copy) on host, then `Cmd+V` on Mac.

The hidden `Ctrl+Option+Shift+V` inject path is not sufficient and must not
remain the only option.

### Product contract

| Layer | Behavior |
|---|---|
| Protocol | `PLANK_TRANSPORT_EVENT_CLIPBOARD_OFFER` / `PLANK_TRANSPORT_INPUT_CLIPBOARD_OFFER`, 1 MiB UTF-8, independent generations, feature `0x400000`. |
| Client | Watch NSPasteboard while streaming; on change, send offer if feature enabled. On host offer, write macOS pasteboard. `Cmd+V` in stream uses local pasteboard → existing text inject **or** synced payload. |
| Host | Watch X11/Wayland clipboard selection while session active; on change, send offer. On client offer, set host clipboard and notify Flame toolkits. |
| Security | Session-bound only; no clipboard persistence across hosts; reject non-text v1; rate-limit offers; log byte counts, not contents. |
| Settings | No user toggle v1 — on whenever negotiated. Later: admin disable in `host.conf`. |

### Out of scope v1

- Image, HTML, Flame internal clip formats, file URLs.
- Clipboard while disconnected or on the login screen.
- Cross-user clipboard on shared hosts.

### Acceptance

- [x] Copy sentence on Mac → paste in remote gnome-terminal and Flame text field.
- [x] Copy sentence in remote app → paste in Mac TextEdit while stream focused.
- [ ] Copy while stream unfocused does not leak to host (Mac pasteboard local only).
- [ ] Session end clears injected clipboard state; no stale host text on Mac after disconnect.
- [ ] Payload over limit fails with visible client notice, not silent truncate.

## Parallel delivery

| Track | First deliverable | Depends on |
|---|---|---|
| Flame UI monitor | `plank-display-prepare --flame-ui-origin` + host transition wiring + picker QML | Host supervisor (sunshine fork gitlink) |
| Clipboard | Protocol doc + feature flag + client/host stubs + unit tests | PlankTransport schema agreement |

Both tracks need host submodule commits before end-to-end qualification on
dxs-flame-06. Client-only and packaging-only work can land in this repository
first.

## References

- [Headless display plan](plans/headless-display-plan.md) — `primary display` in bookmarks
- [Output topology](../../protocol/output-topology.md) — launch parameters and topology JSON
- [Teraguchi Mac two-output](teraguchi-mac-two-output.md) — client presentation (orthogonal)
- [Teraguchi support](teraguchi-support.md) — current clipboard limitation statement
