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

The current design adapts the **1986 Studios Coolant** system to native Qt/QML:
ink/paper contrast, square controls, a larger Archivo Black wordmark, indexed
workstations, and outlined one/two-display cards. Cyan marks selection and
keyboard focus. Lime and azure support status labels; words carry the meaning
independently of color. Primary buttons invert black/white on hover. No imagery,
gradients, rounded cards, shadows or remote asset loading are introduced.
Alan's PLANK attribution remains visible in the footer. The wordmark is a
proposal; package identifiers, production icons, signing identity and saved
settings remain unchanged.

The source is `1986 Studios Design System coolant/README.md` and
`colors_and_type.css` in the supplied design-system repository. Its README and
CSS define the Coolant cyan palette; the older orange in that folder's
`SKILL.md` is not used. The Qt theme maps the core tokens directly and converts
OKLCH accents to channel-clipped sRGB: cyan `#0099AF`, azure `#3C79D1`, lime
`#6FC267`. It follows the 8-point spacing scale and hard-edged line icon rules.
Automotive imagery and customer pitch content are not part of this client.

Typography uses installed Archivo, Archivo Black and JetBrains Mono on the
preview Mac, with explicit Helvetica Neue/Archivo and Menlo fallbacks. Font
files are not copied or downloaded at runtime. A distributable client still
needs licensed font assets and notices bundled with its resources so that a
clean Mac receives the same typography. The preview does not close that gate.

Buttons and workstation rows accept keyboard focus and activation. Each row
announces its name and status. Host names use plain text, never rich-text
interpretation. Main connection/recovery actions stay beneath the scrolling
details, so long errors cannot hide them at the compact window size. The chosen
display layout remains identifiable when its controls are locked during a
connection. Scrollbars have square, visible thumbs, and the details scrollbar
is positioned at the right edge with the full viewport height. Screen-reader
and physical-keyboard acceptance remain open.

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
The Coolant revision passes 43 behavior/UI cases, plus QtTest setup and cleanup
(45 results). Added cases exercise scrolling to compact-window details and
keyboard activation of the display cards while preserving the locked selection.
Network denial and 15 rendered screens also pass. Normal and compact ready,
error and recovery screens were visually inspected. The preceding candidate's
stale-request/display-count negative controls and 12 CI policy/context tests
remain applicable; flow logic and CI wiring did not change in this visual
revision. Exact commits, design-source hashes and capture hashes are retained
in the private receipt.
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
