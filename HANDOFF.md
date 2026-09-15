# Teraguchi / PLANK handoff

Read AGENTS.md and the platform build runbook before work.

The operator accepted the macOS UI and requested publication and a new-task
handoff on 2026-09-15. Start with the [current handoff](docs/development/teraguchi-handoff.md).
Physical input diagnostics and short operator session checks have now run.
Start with the [development resume plan](docs/development/teraguchi-resume-plan.md)
for their scope, the source-provenance correction, deferred stability check and
paused builder attempt. Earlier checkpoint sections below are historical.

## P3/P4 continuation

The installed Mac cursor candidate at root `879e90c` / client `6267acf7`
**failed** its physical test with Flame Tablet Margins at 5%. The operator sees
one stationary cursor on the target while the click lands elsewhere. Setting
all four margins to zero is the confirmed temporary workaround. Read-only host
samples show the virtual tablet axes and X pointer follow the configured 5%
crop. The exact divergence remains unresolved; offline cursor checks do not
qualify the live path.

An opt-in diagnostic build records up to 15 seconds of pen/mouse coordinates,
host cursor position, window mapping and cursor ownership in the existing
private client log. It changes no coordinate or input behavior. The diagnostic
candidate was installed and captured live traces. The operator then reported
that the pen cursor disappears inside the video, while remaining visible outside.
Host positions were arriving and mapped, with the native cursor hidden during
pen ownership. The replacement overlay's visible rendering is unqualified.
Flame still showed 5% margins while a host read showed the full tablet area;
this mismatch does not mean the operator changed preferences to zero. See [the input checkpoint](docs/development/teraguchi-macos-input.md#mac-pen-cursor-and-flame-margins).
No host settings were changed by the agent.

The disappearing cursor now has a reproduced local cause: renderer reset refreshes
the cursor before the replacement Metal view is appended, so video covers the
cursor despite valid parent attachment. The Mac overlay now restores its sibling
order when dispatching updates. The new regression fails before the repair and
all 43 native checks pass afterward. A visible local Metal fixture confirms the
replacement cursor is drawn over video. The clean candidate at root `478690d` /
client `293b4a08` is installed locally. All 107 Mach-O/signature/path checks and
packaged setup/startup/restart/Quit checks pass. Diagnostic coordinate logging is
absent. Pilot is reopened for operator-owned input-grant renewal; physical cursor
visibility and 5% alignment remain pending. This does not resolve the separate
margin state discrepancy by itself.

The preceding onboarding pilot was installed from root `fd5e9c3` and client
`5955945b`. Its bundled setup loaded automatically, and the live list contains
only the configured workstation. Settings and the separate Mac input dialog
were visually checked in the installed app. Fresh portable startup, saved setup,
restart, idle Quit, signature and all 107 Mach-O minimum-OS checks pass. The
previous working pilot is retained privately. The operator renewed the input
grants after the scoped reset and confirmed a working live session. The pilot
remains local-only; trusted artist distribution and clean-guest onboarding are
still open. Private notes hold exact hashes, setup revision/expiry and recovery.

The operator confirmed the dual-output top-edge repair works, then requested
simpler onboarding. The current slice puts import and Mac input review in
Settings, keeps the studio name in the header and shows only the next required
repair notice. Mac packages can carry verified signed setup for automatic
first-use import or a newer-revision update. The picker and background worker
intersect Tailscale peers with signed trusted node IDs. No new assignment service
or tailnet changes are involved. 29 setup results, three key-removal results, 30 provider results, seven
packaging tests, 166 QML results and 52 network-denied captures pass; installation and clean-artist qualification are recorded separately.

The first dual-output pilot exposed macOS menu-bar/Dock interference at the
Linux screen edge. A session-scoped presentation repair now hides those controls
only while the visible fullscreen pair has focus and restores the prior state
on focus loss, minimize, windowed mode and cleanup. App switching and Force Quit
remain available. 21 display tests, 142 hidden native checks, eight Quit scenarios
and packaged startup smoke pass. That previous pilot was installed from root
`fff0818` and client `e405dfeb`. The operator renewed input grants after the ad-hoc signature changed and
confirmed the live top-edge repair. Broader focus/cleanup acceptance remains open.

The supervised pilot now reaches a working headless desktop, confirmed by the
operator. The single-output stream reports 3840x2160x60, native 10-bit capture,
HEVC 4:4:4 and hardware decoding, with automatic login-to-desktop reconnection.
Private machine notes hold the configuration, recovery and session evidence.
The operator subsequently ended that session; the previous working pilot is
retained privately for recovery.

The first display-mode transition exposed a startup retry bug: a worker refusing
connections before presenting a certificate was reported as a trust rejection.
The client now preserves network errors for that bounded retry while rejecting
certificate/setup failures. All 24 loopback cases pass; the baseline reproduces
the failure. The repair is included in the updated installed pilot and still
needs a fresh live startup check. Physical Flame interaction, tablet behavior,
dual-output acceptance, WAN
and sustained-session qualification remain open.

The pilot connection check exposed a headless-display diagnostic gap. The
client still rejects a host with no active outputs, but now names that condition
and retains the sign-in error in the picker instead of replacing it with a
generic connection failure. 17 native topology results and 159 QML results pass;
negative controls reproduce the old message loss. These parser/UI tests do not
provision a host display or qualify a live connection. This diagnostic repair is
also included in the updated installed pilot.

Local pilot permission repair adds explicit, individually scoped OS requests.
Startup and session checks remain non-prompting. Pilot packaging must declare
the actual client as its main executable; the strict Mac client supports a
bundle boolean to open the picker without a launcher wrapper. Permission grants
and persistence still require the exact installed candidate and operator check.

The first authorized local pilot exposed a native assignment-list integration
bug: QVariantList signals arrive in QML as a sequence rather than a JavaScript
Array. The adapter now normalizes that list before the flow validates it. A
real native-provider-to-QML regression reproduces the failure before the fix;
all 29 native provider/worker results pass afterward. This is discovery repair,
not live login, video, input, or external-guest qualification.

Current client gitlink: `6267acf7a04023281b19fb72a58cb8984a6d3b39` on `codex/assignment-refresh`.

The operator deferred physical input follow-up and prioritized independent P3/P4
work. Start with [the ordered implementation checklist](docs/development/teraguchi-p3-p4.md).
The `codex/assignment-refresh` development slice adds bounded assignment-cache
freshness and asynchronous refresh handling to the offline picker. The native local Tailscale provider and scoped PAM/Session handoff now compile;
see [the integration boundary](docs/development/teraguchi-tailscale-workstations.md).
The explicit development picker now wires credentials, selected-output binding,
native Session cleanup and [Mac permission onboarding](docs/development/teraguchi-mac-permissions.md).
Non-prompting permission checks guard login, startup, reconnect and the native
streaming loop; Settings opens only after an explicit click. The arm64/macOS 26
build, 146 QML tests, five native permission tests, keyboard/bridge checks, strict
video, eight Quit scenarios and actual-client startup smoke pass. Forty-two
network-denied simulated screens render.

The [two-output Metal renderer](docs/development/teraguchi-mac-two-output.md) now
uses one decoded canvas with a crop per output. Eighteen geometry/input QtTest
results, 31,680 ten-bit GPU channel checks and 71 production-renderer lifecycle
checks pass locally. A deliberate uncropped negative control fails as required.
The lifecycle fixture uses hidden, non-activating windows and synthetic software
frames; it does not prove hardware decode or physical display behavior.
The native Mac window layer now binds one/two physical outputs before PAM and
retains their identities/modes through startup and reconnect. It places separate
windows, keeps both crops in borderless fullscreen and windowed mode, groups
minimize/restore and disconnects on either close or display change. 20 synthetic
binding QtTest results, 92 hidden native placement checks and 139 QML results pass.
Physical two-output/Spaces/focus/input and live session qualification remain open.
[Signed studio setup](docs/development/teraguchi-studio-setup.md) now verifies an
Ed25519-signed file against a build-pinned public key, saves it privately and
rechecks it on launch. Native discovery, PAM/session handoff and reconnect retain
that setup; expiry closes the session through input cleanup. The import panel
provides repair states. 23 setup tests, three key-removal checks and 28 provider/
worker tests pass, along with the complete build and startup smoke. Unsigned development setup is explicitly labelled and
rejected by key-configured builds. No production key or product identity has
been selected. The [guest policy preparation](docs/development/teraguchi-guest-access-policy.md)
now records the pinned TCP/UDP 28989 path, a guest-only draft, native policy test
examples and 22 source digests. 18 offline regressions and source/package checks
pass. Hosted CI includes the regression suite but has not run. No live policy was
validated or changed. [Workstation-specific host trust](docs/development/teraguchi-host-trust.md) now closes
the inherited certificate-profile gap in the assigned entry. Signed version-2
setup binds node/host IDs to approved leaf fingerprints; fresh HTTPS requests
verify before username/password/token transmission. PAM, Session and reconnect
retain that trust. 21 real-NvHTTP loopback cases pass, including swapped/expired
certificates, redirect canaries, rotation and an unpinned negative control. 25
setup results, three key-removal results, 28 provider results, 147 QML results,
42 network-denied screens, the full Mac build and blank-settings smoke pass.
Real administrator bindings, production key custody and rotation remain open.
[Offline release verification](docs/development/teraguchi-client-release.md) now
binds exact collected DMG bytes/source pins to separately signed release metadata,
identity policy and monotonic authorization history. Fresh signed rollback must
match the retained previous package and exact current digest. 25 real-Ed25519
synthetic-package tests pass, including both CLIs, replay/downgrade rejection and
unchanged history. Receipts explicitly perform no installation or Apple trust
checks. Product identity, production keys, actual bundle/build-key attestation,
native installer integration and clean-Mac recovery remain open.
[Help and private support reports](docs/development/teraguchi-support.md) now add
tablet/display repair guidance, permission review and preview-before-save status
export. The fixed native schema excludes logs, identities and input/artwork;
owner-only files are saved and revealed only by explicit actions. 16 native
QtTest results, 156 QML results, 49 offline captures and seven native Mac help
captures pass. The complete Mac build, startup/idle Quit smoke and 12 CI tests
pass. Physical tablet/display and video checks remain explicitly untested in
reports. Next independent slice: private P4 evidence manifest and transport-counter
inventory. The host's
IPv4-only QUIC listener still limits guest qualification. Physical client/guest/
permission qualification, the installed client, host, builder state and postponed
soak are unchanged.

## Teraguchi macOS workstation interface

Local branch `codex/macos-workstation-ui` starts at root
`ff3948bb2e6b208f1fa62bee5f48c84a6771f0ec` and client
`48568fa23314eb74daa40cee3695cbc81514bdb8`. The client gitlink is
`ce00cde589f91ee8ae8128bb42c2b8d0bc8e8dca`. Host, transport and other recursive pins are unchanged.
The Linux input candidate remains unpromoted.

The user's macOS direction replaces the Coolant visual proposal. The preview
uses Qt macOS controls, system typography, a compact toolbar, searchable sidebar,
native display radios and actions beside the selected workstation. Light/dark
appearance is supported. Optional studio power remains disabled by default;
telemetry is in a disclosure while the standby-cycle explanation stays visible.
Read [the UI scope and capture procedure](docs/development/teraguchi-workstation-ui.md)
and [the private power-service plan](docs/development/teraguchi-studio-power.md).

The arm64 preview build passes with Qt 6.10.2 on Mac Studio M2 Ultra,
macOS 26.5.2 (25F84). 69 QtTest results pass with network denial. There are 29
normal/compact light/dark captures. Accurate native control painting needs Cocoa
and the default Mac graphics backend: headless/software captures omit parts of
native controls and are layout evidence only. Native captures were visually
reviewed. The separate preview opens briefly and exits; it captures its own
window without screen recording. Exact commits and private evidence hashes are
retained with verified Git recovery bundles.

No installed client, host or power strip changed. No live power service is built and no Slack command was sent. These candidates
are being preserved on development branches; publication does not deploy them. The connection-flow model
and its strict checks are unchanged. Physical display/input, accessibility,
production lifecycle/resource integration and clean-Mac packaging remain open.

Next: wire authoritative assignments and PLANK's existing authentication/session
objects into the UI with the same strict admission and cancellation contract.
The private power service can be built against a fake controller before adding
read-only authenticated status. A later live pilot remains limited to the
previously authorized test workstation, with agreed attendance and verified
recovery. Inventory does not authorize fleet power changes. P2 gates remain open;
new transport work and Windows remain gated. Earlier input checkpoints follow.

## Teraguchi Linux input preparation

Local root branch `codex/linux-input-preparation` starts at
`60f3ddb28c39ec34794a10ea3e88079e53472056`. All product gitlinks are unchanged.
A separate local `plank-libvirtualhid` candidate, `a16905e31635f2211f918a96f0788e98dc12db89`,
starts at the currently pinned library `93d57db99a5bf4b1a9fbbc7ad1371671725b7e97`.
It prepares 0–8191 normalized pen pressure, native evdev keypad selection through
the existing API and repeat identity/release serialization. Do not advance the
host dependency until the Linux build and backend suite pass.

The root adds a file-only modifier profile checker and nine saved Flame shortcut
fixtures. Identity remains the default draft. Read the
[behavior, evidence and qualification order](docs/development/teraguchi-linux-input-preparation.md).
16,401 portable helper assertions, both negative controls, sanitizer checks,
14 profile tests and 12 CI policy/context tests pass locally. Linux integration,
CMake wiring and physical input remain unqualified. No installation, host access,
permission change, workflow dispatch, transport change or publication occurred.

Next with the operator present: local Mac pen observation and permission review,
then active Flame preset confirmation in an agreed session. Prepare a qualified
Linux builder run before any host candidate; retain verified recovery and native
capture gates. The existing strict Mac candidate rejects an 8-bit source even
when its encoded output is ten-bit. Older sections below are prior checkpoints.

## Teraguchi Mac keyboard candidate

Local branch `codex/macos-keyboard-input` starts from root
`cc393154bc6ab3a7d358be93ed40d056f623a3c3` and client
`07983bda03c1f1f9069f27956c19e6e1b9f9dd07`. Recursive dependencies are unchanged.
The candidate client gitlink is `22985f9df115702aadc10f1ff79be43f957dd21a`.
It adds physical key ownership, ordered reserved-key capture and pen-before-key
cleanup. Read [the behavior, validation and remaining gates](docs/development/teraguchi-macos-keyboard.md).

The full Mac build, 75 keyboard assertions, 61 bridge assertions, 16,427 pen
assertions, common-C modifier/pen queue test and eight native Quit scenarios pass
locally. No live tap, physical keyboard test, client installation or host change
was performed. This candidate is local and unpublished.

Next: qualify permissions and physical reserved chords, then the complete Flame
shortcut/pen path on the authorized test host with verified recovery access.
Distinct keypad Enter and host modifier profiles need coordinated host work;
the existing host pressure and native-capture gates remain open. Older sections
below describe earlier checkpoints and upstream history.

## Teraguchi Mac input candidate

Local branch `codex/macos-pen-input` builds on the strict-video candidate below.
Its root parent is `7cf9479731faaffb0aea111a206ec0c82649aeb7`; the client gitlink
is `07983bda03c1f1f9069f27956c19e6e1b9f9dd07`. Recursive dependency pins are
unchanged from the parent listed below.
The Mac client now assembles Cocoa/SDL pen samples and forwards normalized pen
input with cleanup and local toolbar routing. See
[Mac input behavior, tests and remaining gates](docs/development/teraguchi-macos-input.md).
The full build, exhaustive synthetic pressure preservation, modifier/pen
queue-order tests, strict-video regressions and eight Quit scenarios pass.
The local `macos-pen-monitor` is ready for a physical
check; no client or host has been installed or changed by this work.

Source review found the host normalized pen's `0...4096` limit. A separate Linux
dependency change and real device/Flame test must establish `0...8191` support.
Reserved Mac chords, modifier remapping and separate keypad Enter also remain
open. Native capture and recovery gates still apply before testing this strict
candidate on a live host. The saved source work is local, not published.

## Teraguchi strict-video candidate

The local `codex/strict-video-admission` branch starts from Teraguchi main
`0494d91a9cc1facfdcb608c0a0e465912cb03af7`. New root Mac builds enable strict
native capture / HEVC RExt 4:4:4 10-bit / hardware decode admission. Read
[the change and results](docs/development/teraguchi-strict-video.md) before
building or installing: existing NvFBC bookmarks are rejected by this candidate.
The full Mac build, policy/metadata tests, decode matrix, moving hardware
fixtures and Quit regressions pass. No installed client or host changed.
The client gitlink is `b2c52d829264f1a3e334562594efd46c9d096d05`; common-c
`b9650552f98d97f6e30c9f007115c6246f0809e5`, qmdnsengine
`b7a5a9f225d5e14b39f9fd1f905c4f505cf2ee99`, and Kymux
`912ece5c64787997f978673ca60d313898a3548c` are unchanged.

Next: qualify live native capture with verified recovery access, then exercise
the candidate's startup/reset/reconnect failures and physical presentation.
Mac Wacom/shortcut work can proceed locally while recovery access is pending.
New transport work and Windows remain gated. The retained upstream handoff
below describes PLANK history, not additional Teraguchi qualification.

## Hosted builds qualified; signing pending

The approved `github-builds` work is fast-forward merged into `main`, adding
GitHub-hosted clean-worktree builds. The 1.0.103 release is unchanged. See
`docs/development/build/github-builds.md` and the matching plan. Public jobs
have no signing/deployment secrets, private sources or access to internal
machines. No candidates have been installed and no existing builder is retired.

Hosted clean-bootstrap/build qualification results:

- macOS Host compile/portable tests and Ubuntu Client DEB/package gates passed
  in [run 34833324611](https://github.com/instinctual/plank/actions/runs/34833324611).
  Its overall result is failure because the other initial jobs needed fixes.
- macOS Client clean bootstrap/build passed in
  [run 34833858993](https://github.com/instinctual/plank/actions/runs/34833858993).
- Node 24 privacy checks passed in
  [run 34834417907](https://github.com/instinctual/plank/actions/runs/34834417907).
- Linux Host RPM and package gates passed in
  [run 34836078210](https://github.com/instinctual/plank/actions/runs/34836078210),
  explicitly checked against source `882cf322128584b30f48791f2b0ce3436b0a0f55`.
  The full CUDA architecture set and independent dependency-patch gates remain
  enabled; no hardware or installation tests were performed on the runner.

The Client DEB and Host RPM were transferred through the checked collector to
`artifacts/packages/candidates/1.0.103-github-builds/linux/`. SHA-256 values:

- Client: `831e04102110cb586ab2824630100f653479691e62a696c8f4852bedea5ccb23`
- Host: `895d53b9e83bc40759445bcd3ee6cbd807c53fe32a5c0f95b5cdf1dd5d2996db`

Their manifest retains each actual source commit, not the newer workflow-only
tip. Validation was across separate product runs, not one all-green aggregate
run at the final notes commit. Eight CI policy/context tests pass, including
the exact-source check and isolation from inherited runner environment values.

Selected-product manual dispatch permits retries without canceling other
platforms. Use `scripts/ci/dispatch.sh`: the expected-source gate now rejects
stale ref propagation before bootstrap. Container trust is exact-path only;
Rocky repositories are pinned before the first transaction; `python3-jinja2`
is declared and checked before lengthy dependency builds. Current Actions use
Node 24. These are CI/build fixes, not Host/Client runtime changes.

macOS distribution remains gated on operator provisioning of Developer ID and
notarization credentials in a separate protected environment. Ordinary Mac CI
does not upload unsigned applications as release packages. Initial clean runs
use no dependency caches; add exact-input caches only after clean bootstrap
qualification. Hardware/session gates remain separate from hosted build tests.
The user was asked whether to provision protected GitHub signing secrets or
retain local Mac signing; no answer/credential transfer is recorded yet.
The public and both private infrastructure CI branches are merged into their
respective `main` branches. Next: resolve signing authority and qualify an
exact-input dependency cache. Existing candidate packages keep their original
branch/source provenance; merging does not promote or relabel those artifacts.

## Current source

The final Host/Client repository is `instinctual/plank`. Build-path cleanup is
merged and all four mainline **1.0.103** packages passed build and payload review
from root **06bc71add24d7b7bddd19db1a9c2e914f0cb8383**. Later notes commits
do not change those package bytes. ENet cleanup was pushed and
merged at **5844885**; its **1.0.102** candidate provenance is retained below.
The audited Host/Client repository and its six required maintained dependencies
are PUBLIC following explicit approval. Release
[v1.0.103](https://github.com/instinctual/plank/releases/tag/v1.0.103) contains
the four verified packages, checksums and provenance manifest. Fresh live-session
testing was explicitly skipped for this release, not reported as passed. The
original development repository is preserved privately; do not import its
history, old gitlinks, deployment notes or credentials here. Private
infrastructure products remain independent and are not build dependencies.

Maintained companions now use the final `plank-client`, `plank-host-linux`,
`plank-kymux`, `plank-common-c`, `plank-build-deps`, `plank-libvirtualhid` and
`plank-enet` repository names. ENet is now removed from the current build graph;
its repository is not required for current builds and remains private. The seven
published repositories were fresh destinations populated only with audited refs.
External upstream references retain their original targets.
Author names, noreply attribution, licenses and useful development history are
preserved. Six unsolicited dependency-update branches from preparation were
excluded; inherited automatic update schedules are disabled on the affected
default branches. Pinned runtime dependencies did not change.

The 1.0.101 baseline rebuilt from the final repository names and rewritten source
identities. It made no streaming behavior change relative to 1.0.100. Optional
Client wake requests remain hidden/disabled without administrator opt-in.

## ENet cleanup

The Host-only common-C branch now contains three protocol headers and no
compiled implementation or recursive submodules. ENet, nanors and the unused
GameStream transport/library sources are removed. Input and PLANK wire headers
are unchanged; Limelight.h only loses the unused ENet RTT query declaration.
The Host's CMake source list follows the three retained headers. Client and
KyProto transport sources are unchanged. Historical builds are not supported.
Do not retain or restore current dependencies solely for old build compatibility.

Seven positive/negative tests pass, including standalone C/C++ header compilation.
The header-only CMake configure/build and four portable root CTest entries also
pass. Host executable source, Client gitlink and transport gitlink are unchanged.
The Host package preflight runs the tests and requires the header-only dependency.

Clean Host RPM build and all package gates pass from root
`d178c67240555d3425ba51df4d116fbb2f83b50b`, Host
`9329784ac41f50cbec0c9d76badfd22227ec5e5f`, Host headers
`775943b5ac5e5100a3c2b1b89d9e21151dea4f29`. Later notes commits do not
change those package bytes. The RPM is cataloged under
`artifacts/packages/candidates/1.0.102-enet-cleanup/linux/`, with version/branch
and SHA-256 provenance. It retains BUILD_TESTS=OFF and the full CUDA target set.
The exact clean source requires no ENet or nanors checkout, and the Host link
contains no ENet library. Existing Client packages require no code update for
this cleanup. No hardware/session testing or installation was performed.

Root, Host and Host-header commits were pushed and fast-forward merged in
dependency order. The completed enet-cleanup branches were removed locally and
remotely; their commits remain on the corresponding main/Host-header branches.
The current header branch replaces the Host-specific common-C branch, never the
Client's branch. Old remote repos/history were not deleted or rewritten.

## Audit and validation

### Build-path cleanup

Product builds now map C/C++ and Rust diagnostic paths to neutral build labels.
Cargo native compiler flags are isolated from qmake's Make variables. Client
FFmpeg bootstrap sanitizes only its generated configure-description string,
retaining the exact identity-GBR patch and actual private link/pkg-config paths.
macOS Client dependencies were rebuilt from pinned archives; OpenSSL runtime
defaults no longer point into an operator's home. No TLS verification downgrade,
new shipped trust/configuration file, media source or transport source change.

Normal package assembly strips debug sections before distribution signing.
All four package paths have a fail-closed home-path gate. Three exact public Qt
vendor paths (six occurrences) are narrowly allowed only in the pinned official
QtQuick/QtWidgets frameworks; there is no general home-path exemption.

Nine focused build-path cases and five portable CTest entries pass, including
privacy and bootstrap contracts. Mainline privacy CI passes. All four packages
passed clean builds and uninstalled package gates from the exact root above:

- `artifacts/packages/releases/1.0.103/linux/plank-host-1.0.103-1.el9.x86_64.rpm`
- `artifacts/packages/releases/1.0.103/linux/plank-client_1.0.103_amd64.deb`
- `artifacts/packages/releases/1.0.103/macos/plank-host_1.0.103_arm64.pkg`
- `artifacts/packages/releases/1.0.103/macos/plank-client_1.0.103_arm64.dmg`

The catalog retains SHA-256 checksums and source provenance; transfers were
hash-verified. Linux Host retains BUILD_TESTS=OFF and the full CUDA target set.
Both Mac products passed signing, notarization, stapling and Gatekeeper. The
actual Client on the read-only mounted final DMG passed a certificate-verified
TLS1.3 loopback using its bundled OpenSSL3.5.5. The mount and temporary signing/
validation job were removed after success. Initial fixture/compiler-flag failures
remain in private evidence; none were waived.

Extracted final payloads have zero supplied-secret or operator build-path
matches. Supplemental private-identity/token and symlink review found only two
non-text byte coincidences identical to the pinned official Qt input, not
deployment metadata. This is bounded scanning, not proof against unknown secrets
or every form of encoded metadata. Public Qt vendor literals above remain.
No installs or hardware/session tests occurred. Completed build-privacy branches
were removed locally/remotely after the fast-forward merge and push.

### Previous source/distribution audit

Every rewritten commit was checked for allowed URL/gitlink/pin changes, unchanged
executable source, retained messages and parent relationships. Historical
maintained gitlinks and branch hints resolve. All eight stored object sets have
zero supplied-password matches and zero maintainer personal-email matches.
Five previously reviewed Host test/demo/API scanner fixtures remain intentional.
See `docs/security/publication-review.md` for scope and limitations.

All four **1.0.101** packages passed clean build and uninstalled package gates
from `152dca081fea9585220ba0330b6492dff9137a6c`. Later handoff commits are
documentation only. Packages are under
`artifacts/packages/releases/1.0.101/{linux,macos}/`, with hashes and source
provenance in the version catalog's manifest. Transfers were SHA-256 verified.
The earlier 1.0.100 manifests retain their original provenance.

Linux Host retains `BUILD_TESTS=OFF` and the full supported CUDA target set.
Both macOS packages passed Developer ID signing, notarization, stapling and
Gatekeeper. All three builders used new worktrees and build outputs, reusing
the qualified bootstrap dependency caches. This was not another dependency
bootstrap. The temporary Mac signing job exited successfully and was unloaded.
Four portable root CTest entries pass, including 20 privacy guard cases.

## Current maintained inputs (1.0.103)

| Maintained input | Package source commit |
| --- | --- |
| Linux Host | `9329784ac41f50cbec0c9d76badfd22227ec5e5f` |
| Shared Client | `c032da3ae0d7e816a7a6f9bb9a51dd489d4d369c` |
| Transport | `912ece5c64787997f978673ca60d313898a3548c` |
| Host common-C | `775943b5ac5e5100a3c2b1b89d9e21151dea4f29` |
| Client common-C | `b9650552f98d97f6e30c9f007115c6246f0809e5` |
| Client mDNS engine | `b7a5a9f225d5e14b39f9fd1f905c4f505cf2ee99` |
| Host build dependencies | `caf0495d5e6baff94f349853d4a59e3779a451a0` |
| Host virtual HID | `93d57db99a5bf4b1a9fbbc7ad1371671725b7e97` |

## Remaining gates

The older **1.0.100/1.0.101** assets are not cleared for publication: their binary
build-path metadata is not repaired retroactively by 1.0.103. Do not republish,
patch signed binaries or relabel their manifests.

Publication was authorized after the operator waived fresh hardware/session
testing for 1.0.103. That waiver does not change package-manifest functional
validation to passed, or waive future acceptance criteria. No packages were
installed on test or production machines. Credential rotation remains the
operator's separate responsibility, not a verified audit result.

The release tag points to the exact package source commit above; later notes
commits on main do not change it. All six release assets were downloaded without
authentication and SHA-256 verified. The seven repositories are anonymously
accessible. Private infrastructure, PLANK2, the historical backup and retired
ENet repository remain private. Older preparation hosting objects are not cleared
for publication. Private operational evidence stays outside Git as documented
in `docs/security/private-information.md`.
