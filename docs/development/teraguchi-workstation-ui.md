# Teraguchi workstation picker preview

P3 interface development can proceed while P2 hardware qualification remains
open. This candidate adds reusable Qt/QML components and a standalone offline
preview. It does not switch the installed client interface or connect to a host.
Alan Latteri's PLANK remains the foundation. The existing Qt client is retained;
there is no new browser client, Swift rewrite or transport change.

## What is built

The workstation list shows only explicitly assigned entries. Sample states cover
available, offline, in use, needs attention and an empty assignment list. Each
state explains the next action. An available workstation starts a connection
check rather than being treated as already authorized or qualified.

Artists choose one or two displays. The requested native ten-bit, HEVC 4:4:4
and hardware-decode requirements stay visible, with further details expandable.
Every selected display must pass; failure cannot silently reduce the count or
accept software decode or an eight-bit source. Authentication and verification
in this harness are simulated. Production integration must retain PLANK's
actual strict admission and trust checks.

The interaction covers checking, opening, connected, interrupted and blocked
states. Cancel invalidates delayed replies before calling an adapter, including
synchronous callbacks from its cancellation handler. Occupancy or assignment changes
during a check stop it. A dropped connection requires explicit reconnect with
the same display selection. Failed reconnect keeps a return/disconnect action.
Disconnect is explained separately from logging out inside Rocky. No takeover,
logout, restart or power action exists in the connection-flow API. A separate,
optional studio provider supplies the proposed power-on interface described in
[studio power integration](teraguchi-studio-power.md).

## Design and interaction

The current direction follows familiar macOS utility conventions: a compact
15 px app label, toolbar, searchable sidebar, selected-workstation details and
nearby Connect/Power on actions. The user's macOS direction supersedes the
previous Coolant visual proposal. System typography and restrained surfaces
replace the custom fonts, numbered rows and outlined display cards. Alan's
PLANK attribution remains visible at the bottom of the sidebar.

The preview selects Qt Quick Controls' **macOS style**. Buttons, radio buttons,
search, scrollbars and the preview dialog use its standard controls. Their
backgrounds and content items are not replaced. The sidebar uses a deliberately
custom Basic delegate with system selection colors and an original QML computer
glyph. The spinner uses Basic's QML implementation because the prepared Qt tree
lacks the WebP plugin required by macOS style's animated spinner asset.

The system font comes from Qt's application font. There are no custom fonts to
bundle for this design. Light and dark surfaces follow the application's color
scheme; interactive previews follow the system by default. The capture-only
appearance option changes this process, not the user's macOS preferences.
This remains a Qt app; no SwiftUI conversion or Liquid Glass fidelity is claimed.
References: [Apple typography](https://developer.apple.com/design/human-interface-guidelines/typography),
[Apple layout](https://developer.apple.com/design/human-interface-guidelines/layout),
and [Qt macOS style](https://doc.qt.io/qt-6/qtquickcontrols-macos.html).

Search filters the assigned list locally; it cannot grant assignment or change
authorization. Up/Down changes selection within the visible list. Buttons and
rows accept keyboard focus and activation; each row announces its name/status.
Host names render as plain text. Display choice uses standard radio buttons and
remains identifiable when locked during a connection. Primary actions remain
outside the scrolling details area. Technical power telemetry is collapsed by
default, while the verified-standby outlet-cycle explanation stays visible.
Screen-reader and physical-keyboard acceptance remain open.

The harness has a permanent preview-only footer. Developer scenarios move into
a separate dialog instead of occupying the artist's main work area. Sample
names contain no deployment inventory or artist identities. Captures show the
window's content; the native window frame is not faked or drawn into the UI.
No live frame, measured latency or successful physical output is fabricated.

## Source and runtime boundaries

Client components are under `apps/client/app/gui/teraguchi/`. They are not loaded
by the current `main.qml` or production resource manifest. The standalone root
harness is under `probes/workstation-picker/`; tests are under
`tests/ui/workstation-picker/`. Read the component README before wiring an adapter.

The harness embeds QML resources and initializes only Qt and the sample model.
It has no ComputerManager, discovery, credential entry, saved bookmark access,
streaming or input-forwarding code. Its QML network manager rejects every
request, and a separate check verifies that rejection. It uses its own preview
application identity and writes no preferences. Captures read only the preview
window through Qt, without macOS screen recording.

## Build and inspect

Use the already prepared Qt 6.10.2 installation. Keep the output outside Git,
with raw build logs and captures in the private audit store:

```sh
export PLANK_QT_ROOT="/path/to/qt/6.10.2/macos"
bash scripts/test/check-workstation-ui.sh "$PRIVATE_UI_OUTPUT"
```

The script compiles an arm64 Mac preview, runs the QML state/control tests,
checks network denial, and renders normal/compact sample screens. Default
headless captures test layout only: native control painting is incomplete with
Qt's offscreen platform. For accurate native control pixels, run in an available
Mac GUI session with `PLANK_UI_NATIVE_CAPTURE=1` added to that command. It opens
short-lived simulated windows, uses Cocoa and Qt's default Mac graphics backend,
captures each preview's own window, and exits. It does not use screen recording.
Cocoa with the software scene graph also renders native controls incompletely;
leave `QT_QUICK_BACKEND` unset for visual review. The script does this for native
capture and records the capture platform in its summary.

To explore it interactively on the development Mac after that build:

```sh
"$PRIVATE_UI_OUTPUT/build/teraguchi-ui-preview"
```

This executable relies on the prepared Qt installation. It is not a signed,
notarized or distributable Teraguchi application. Each capture process exits automatically after saving its own window.

## Validation and limitations

Test environment: Mac Studio M2 Ultra, 64 GB RAM, macOS 26.5.2 (25F84), Qt 6.10.2,
Apple Clang, arm64 target, offscreen software scene graph for QML tests, Cocoa/default Mac graphics for
visual captures. No Rocky or Flame runtime participated. This candidate does not establish physical display or
hardware-rendering performance.

The local suite covers unavailable/unassigned hosts, malformed catalogs,
required attestations, simultaneous requests, stale callbacks, cancellation,
assignment removal, selected display preservation, explicit reconnect,
disconnect semantics, mouse clicks, keyboard activation and compact action
visibility. Screens are rendered at 940×650 and 780×570 in light appearance,
with four additional dark-appearance cases. Qt's first offscreen font lookup
emits a platform notice; no QML type or binding warning is accepted by the runner.
The current revision passes 69 QtTest results including both suites' setup and
cleanup. Search, arrow navigation, native display-control activation, compact
scrolling/action access and collapsed power telemetry are covered. Existing
power eligibility, freshness, duplicate request and simulated boot tests pass.
Network denial and 29 rendered screens also pass. Normal/compact connection,
power, error and recovery screens were visually inspected in native captures.
The flow model and CI wiring did not change in this visual revision. Exact
source commits, capture hashes and the visual-review record remain private.
The Mac CI build path now calls the same checker; hosted CI has not been run.

## Next integration slice

Connect the presentation to a source of authoritative assigned workstations and
existing PLANK authentication/session objects. Resolve stable IDs at use time,
handle asynchronous refresh failures, and preserve certificate checks, exclusive
seat rules, exact-video admission and release-all on cancellation or Quit.
Public discovery metadata must not grant access or prove a free seat.

Then qualify first-run permissions, real login/cancel/reconnect and saved display
choices with the operator present. Production branding identifiers, installer
signing, Tailscale isolation, and clean-Mac setup remain separate P3 work.
The P2 native capture, Wacom, shortcuts, physical displays and recovery gates
remain open. Neither this preview nor its tests promotes the Linux input
candidate or authorizes additional transport work.
