# Teraguchi development resume plan

Updated 2026-09-15 after operator input and reconnect checks.
This is the starting point for the next session, including a different model.
It supersedes earlier instructions to begin with the first physical pen test.

## Read first

1. `AGENTS.md`, `HANDOFF.md`, and this file.
2. `docs/development/teraguchi-macos-input.md` and
   `docs/development/teraguchi-macos-keyboard.md`.
3. `docs/development/teraguchi-linux-input-preparation.md` and
   `docs/development/teraguchi-strict-video.md` before related changes.
4. The applicable platform build runbook before building.
5. The local private-notes README before machine work. Exact paths, machine
   identities, diagnostic sources and raw logs belong only in the private store
   described in `docs/security/private-information.md`.

Private continuation records are in the audit subdirectory
`teraguchi-input-2026-09-15/`: `NEXT-SESSION.md`, `receipt.json`, diagnostic sources
and shortcut logs. The older `teraguchi-handoff-2026-09-15/NEXT-SESSION.md` locates
the development worktrees and recovery bundles. Temporary worktrees can disappear;
use Git and verified bundles to reconstruct them rather than guessing paths.

## Repository and source state

- Product: [Teraguchi](https://github.com/thedepartmentofexternalservices/teraguchi),
  branch `codex/assignment-refresh`, based on the archived `de64db3` checkpoint.
- Client gitlink: `a354a8c3db1ad7a9f59cbd2298f7e0524f3f054e` in
  [Teraguchi Client](https://github.com/thedepartmentofexternalservices/teraguchi-client).
  Use the root's exact gitlink and initialize required submodules before builds.
- Separate Linux input candidate:
  `a16905e31635f2211f918a96f0788e98dc12db89` on
  `codex/linux-input-preparation` in
  [Teraguchi libvirtualhid](https://github.com/thedepartmentofexternalservices/teraguchi-libvirtualhid).
  It is **not promoted** into the Host dependency gitlink.
- The Phase 0 repository is a requirements/probe archive on
  `codex/phase0-checkpoint-20260915`. Its architecture predates PLANK adoption.
  Do not use it to start a replacement transport.
- Alan Latteri's PLANK remains the foundation. Preserve attribution, licenses,
  upstream history and the existing transport.

## Development status

The accepted Mac interface is a development preview. Visual polish is paused.
Its 69 QtTest results and 29 native light/dark captures remain prior evidence;
the interface has not replaced the installed product client. Authoritative
assignments and existing PLANK session integration remain unfinished. Optional
studio power uses a fake provider; no live power integration is authorized by
an inventory list.

The Mac input and strict-video candidates are development code, not a released
or installed product. Strict admission requires native ten-bit source, exact
HEVC RExt 4:4:4 ten-bit and hardware decode. Do not weaken this policy or replace
the working client to evade the existing capture gate.

## Completed local diagnostics

These ran on the development Mac with recording senders and no host connection.
They exercise candidate components but are not a complete deployed session.

- Pen monitor: 8,365 events, 4,124 samples and 1,586 distinct pressure values.
  The operator tentatively reported the controls worked. Individual eraser,
  tilt and button semantics were not explicitly attested in that run.
- Keyboard monitor: all 13 selected physical keys had matching presses/releases.
  Smoke Classic and the saved schematic/version/audio overrides were confirmed.
- Reserved-key diagnostic: normal Accessibility and Input Monitoring permission
  was granted by the operator to a separate local diagnostic app. All 12 tested
  Command/Control chords had matching captured downs/ups; the operator confirmed
  Mac actions did not activate. Two focus losses left no held output or failure.
- Modifier/pen monitor: strokes were recorded with Control, Shift, Option and
  Command. No sender failures or stuck final state were recorded.
- Timed focus test: the monitor minimized its own window after three seconds
  with Control and pen contact active. One focus loss occurred during contact;
  both pen and key output cleared, with zero uncleared state or failures.
  Manual mouse-driven focus changes were unsuitable because the pen owns the
  pointer. Reuse the timed method when reproducing this test.
- Rechecked 75 keyboard-state assertions and 61 synthetic reserved-bridge
  assertions. Linux preflight rechecked 16,401 portable helper assertions and
  14 modifier-profile tests. These are not Linux backend build results.

The local diagnostic app is ad-hoc signed, not a distribution package. Its
granted permissions do not establish permissions for a future product build.
Diagnostic sources/results remain private; do not assume temporary executables
are durable, reproducible release artifacts or silently copy their logs into Git.

## Installed-session observations

The operator reported these working through the existing PLANK session:

- Mark In/Out, play/stop and the saved schematic/version/audio overrides.
- Light/firm pressure behavior in Paint, Control/Shift painting and releases.
- Both pen side buttons and their releases.
- QuickTime import, playback and scrubbing; the earlier freeze did not recur
  during this short check.
- Disconnect/reconnect restored picture, shortcuts and reported pen behavior.

Eraser did not work. The operator recalled a longstanding limitation, but its
cause is unknown. Do not attribute it to Flame, the driver or transport without
evidence. No pressure trace, host input trace, quantitative precision check or
sustained soak was collected in these manual checks.

### Important source-provenance correction

The historical installed-client receipt names root
`22bcfec9531ab1243c615a441713d450366c9a11` and client
`2f0e0dbf9c10bb6f382150f6ec6ee3d9b657ac8d`. Source inspection finds
`LiSendPenEvent` only in `linuxwacom.cpp`, gated by Linux libinput; the new Mac
pen path is in the later development candidate. Current installed binary source
was not independently reattested: its hash differs from the retained build
executable and the recorded packaged staging executable is unavailable. Packaging
can change hashes, so this difference alone does not prove a different source.

Keep the operator's observations, the historical source receipt and candidate
diagnostic results separate. Earlier conversational claims of an end-to-end
pressure pass were too strong. The pinned host library maps eraser to
`BTN_TOOL_RUBBER`; that proves code exists, not delivery or Flame consumption.

## Paused builder attempt

The dedicated Rocky builder in the runbook came from PLANK's environment. No
operator-owned dedicated builder was established. The automation controller is
not automatically that builder, and no new VM was created.

A controller-only Ansible workflow attempted an isolated Rocky 9.7 container
using the image digest pinned by product CI. Rootless image download succeeded,
but RPM bootstrap failed on ownership because the account lacked subordinate
UID/GID mappings. Compilation never started. Interactive sudo was unavailable.
A privileged alternative was staged and syntax-checked, **not executed**.

The operator rejected the infrastructure detour. **Builder setup is paused.**
Do not resume it, configure sudo/cgroups/UID mappings, or provision a VM merely
because the prepared files exist. No controller packages or host services were
changed. Private staged files and rootless storage remain; inspect exact paths
in the private receipt before eventual cleanup. Do not prune unrelated containers.

## Current priority: P3 and P4

The operator deferred provenance/physical input follow-up and requested
independent work toward P3 and P4. Follow the [implementation order](teraguchi-p3-p4.md).
The assignment-refresh candidate on `codex/assignment-refresh` adds offline
freshness, timeout, and late-reply handling. The native Tailscale provider and scoped PAM/Session handoff are now development
components. Production dialog, display, and session-lifecycle wiring remain next. No deployment, builder restart, or background soak is authorized
by that work. The pickup order below remains the deferred physical-test sequence.

## Pickup order

### 1. Resolve provenance and pressure measurement

- [ ] Confirm the executable actually serving the operator's session and its
  version, hash, build receipt and source. Use read-only inspection first.
- [ ] Reconcile reported pressure with the recorded client's lack of the newer
  Mac pen path. Do not dismiss the observation or invent an explanation.
- [ ] With the operator present, define explicit light/firm strokes and an
  authorized trace method to distinguish real pressure values from mouse-like
  drawing or brush behavior. Keep traces private and bounded to the test.
- [ ] Check eraser identity at the Mac diagnostic, then host device and Flame
  consumption only when the relevant code is deployed and the test authorized.

### 2. Resume the deferred stability check when convenient

- [ ] Run 30 minutes of editing, Paint, QuickTime playback and scrubbing in a
  disposable project through the working session.
- [ ] If a freeze occurs, note its time and collect endpoint/session logs before
  reconnecting when practical. A short successful replay is not a stability gate.

The operator postponed this test. No background soak, reminder or monitor is
scheduled. Do not claim testing continued while the operator was away.

### 3. Choose the smallest justified development task

- [ ] After provenance is clear, agree the exact candidate and test objective.
  Mac input code belongs in the Client; Linux injection changes belong in the Host.
- [ ] Qualify the separate Linux library with the required compiler and Linux
  backend/XTest checks before advancing its Host gitlink. First agree a build
  location consistent with the operator's preference to avoid infrastructure work.
- [ ] Keep genuine device-consumer tests distinct from mock/backend tests and
  container compilation. Record skips and failures honestly.
- [ ] Before any product installation, prepare exact artifacts, provenance,
  recovery procedure and a scoped test window. Preserve the working client and
  designated Host's GDM baseline and retained SSH recovery path.

### 4. Remaining product gates

Native ten-bit production capture; physical display/color and dual-display pen
mapping; complete input including keypad Enter; recovery/boot qualification;
WAN behavior; assignment isolation and exclusive seats; UI/session integration;
signed release packaging. New transport work waits for host viability. Windows
waits for the Mac production gate. None is waived by these diagnostics.

## Instructions to the next model

Continue authorized work without handing control back after every command.
Pause when physical participation, missing information or a consequential action
requires it. Explain the concrete blocker. Do not turn inherited infrastructure
assumptions into a new deployment project. Avoid repeating completed checks
unless a failure, code change or unresolved measurement justifies it.

Keep work on reviewable development branches. A documentation commit is not a
merge, publication or deployment. Read current private authorization before host
work; no fleet operations, messages to contributors, display-manager changes,
logouts, reboots, or live power actions are implied by this handoff.
