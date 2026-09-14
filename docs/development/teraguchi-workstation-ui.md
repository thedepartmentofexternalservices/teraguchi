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
logout, restart or power action exists in the presentation API.

## Design and interaction

The first design uses a dark neutral workspace with one pale-green accent,
readable status text and a two-column layout. Status is conveyed through words
as well as color. The prototype wordmark is a proposal; package identifiers,
production icons, signing identity and saved settings remain unchanged.
Alan's attribution remains visible in the footer.

Buttons and workstation rows accept keyboard focus and activation. Each row
announces its name and status. Host names use plain text, never rich-text
interpretation. Main connection/recovery actions stay beneath the scrolling
details, so long errors cannot hide them at the compact window size. The chosen
display layout remains identifiable when its controls are locked during a
connection. Screen-reader and physical-keyboard acceptance remain open.

The preview contains a permanent simulation banner and developer scenario
controls. They are part of the harness, not the proposed artist workflow. Sample
names contain no deployment inventory or artist identities. No artwork, live
frame, measured latency or successful physical output is fabricated.

## Source and runtime boundaries

Client components are under `apps/client/app/gui/teraguchi/`. They are not loaded
by the current `main.qml` or production resource manifest. The standalone root
harness is under `probes/workstation-picker/`; tests are under
`tests/ui/workstation-picker/`. Read the component README before wiring an adapter.

The harness embeds QML resources and initializes only Qt and the sample model.
It has no ComputerManager, discovery, credential entry, saved bookmark access,
streaming or input-forwarding code. Its QML network manager rejects every
request, and a separate check verifies that rejection. It uses its own preview
application identity and writes no preferences. Captures use an offscreen Qt
window, not macOS screen recording.

## Build and inspect

Use the already prepared Qt 6.10.2 installation. Keep the output outside Git,
with raw build logs and captures in the private audit store:

```sh
export PLANK_QT_ROOT="/path/to/qt/6.10.2/macos"
bash scripts/test/check-workstation-ui.sh "$PRIVATE_UI_OUTPUT"
```

The script compiles an arm64 Mac preview, runs the QML state/control tests,
checks network denial, and renders normal/compact sample screens. To explore
it interactively on the development Mac after that build:

```sh
"$PRIVATE_UI_OUTPUT/build/teraguchi-ui-preview"
```

This executable relies on the prepared Qt installation. It is not a signed,
notarized or distributable Teraguchi application. No GUI preview was left running
after the automated checks.

## Validation and limitations

Test environment: Mac Studio M2 Ultra, 64 GB RAM, macOS 26.5.2 (25F84), Qt 6.10.2,
Apple Clang, arm64 target, offscreen software scene graph. No Rocky or Flame
runtime participated. This candidate does not establish physical display or
hardware-rendering performance.

The local suite covers unavailable/unassigned hosts, malformed catalogs,
required attestations, simultaneous requests, stale callbacks, cancellation,
assignment removal, selected display preservation, explicit reconnect,
disconnect semantics, mouse clicks, keyboard activation and compact action
visibility. Screens are rendered at 1120×790 and 860×680. Qt's first font lookup
emits a platform notice; no QML type or binding warning is accepted by the runner.
The 41 behavior/UI cases pass, plus QtTest setup and cleanup (43 results).
Both negative controls, removing stale-request rejection and display-count
matching, fail as expected. Network denial, 15 rendered screens and the existing
12 CI policy/context tests also pass. Exact commits and capture hashes are
retained in the private receipt.
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
