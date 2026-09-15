# Teraguchi handoff — 2026-09-15

## Later session update

Read the [development resume plan](teraguchi-resume-plan.md) first. Local physical
diagnostics and short installed-session checks have completed with the limits
recorded there. The 30-minute stability test and builder setup are paused. The
plan corrects source-provenance and pressure claims and supersedes the initial
operator-test sequence below. No product candidate was installed in this session.

## Resume here

The operator accepted the macOS interface as good enough for now. Pause visual
polish. The latest cumulative product branch is `codex/macos-workstation-ui`
in [Teraguchi](https://github.com/thedepartmentofexternalservices/teraguchi),
with the matching client branch in
[Teraguchi Client](https://github.com/thedepartmentofexternalservices/teraguchi-client).
Use the exact client gitlink from the root commit; initialize submodules before
building. Read AGENTS.md, HANDOFF.md and the applicable build runbook first.

This branch includes strict video admission, Mac pen and keyboard candidates,
Linux input preparation, the workstation picker, optional studio power
presentation and the accepted macOS design. Earlier checkpoints remain in its
history. It is development work, not a production release or a deployed UI.
Alan Latteri's PLANK remains the foundation and retains its attribution.

The separate Linux input candidate is
[`a16905e31635f2211f918a96f0788e98dc12db89`](https://github.com/thedepartmentofexternalservices/teraguchi-libvirtualhid/commit/a16905e31635f2211f918a96f0788e98dc12db89)
on `codex/linux-input-preparation`. Its existing portable tests pass, but Linux
build/backend qualification remains open. The host dependency gitlink has not
been advanced. Preserve that boundary.

The [Phase 0 repository](https://github.com/thedepartmentofexternalservices/teraguchi-sunshine-kyber)
retains requirements, probes and redacted historical measurements on
`codex/phase0-checkpoint-20260915`. Its architecture predates PLANK adoption;
do not start a replacement transport from that document.

## What is verified

- Mac UI: 69 QtTest results, network denial and 29 light/dark normal/compact
  captures. Accurate native control rendering uses Cocoa and the default Mac
  graphics backend. The installed client has not received this interface.
- Mac input: the earlier full candidate build and synthetic pen/keyboard/queue
  and Quit checks pass. Physical pen, reserved chords, dual-display mapping and
  complete Flame input remain unqualified.
- Strict video: the candidate requires native ten-bit source, exact HEVC RExt
  4:4:4 ten-bit and hardware decoding. It must not replace the working client
  simply to bypass the current native capture gate.
- Phase 0: 75 local tests pass. Hardware results retain their documented scope;
  isolated ramp/encoder results do not qualify deployed capture or WAN use.

The detailed environment and test counts live in the feature documents.
Mac UI validation used Mac Studio M2 Ultra, 64 GB, macOS 26.5.2 (25F84), Qt 6.10.2.
Raw logs, source receipts, screenshots and recovery bundles remain in the
operator's private audit store, outside Git. Credentials and deployment mappings
must stay private.

## Operator session next

The operator is at the station; the next physical test has not begun. Start with
the local `macos-pen-monitor` described in
[Mac input](teraguchi-macos-input.md). It uses a recording backend, has no host
connection and exits after two minutes or Escape. Verify hover, light/firm
pressure, tilt, eraser, both buttons and releases across focus changes. Keep the
normal Wacom driver and respect system permission results.

Then confirm the active Flame shortcut profile with the operator. Read private
machine notes before host work: only the previously authorized test workstation
is in scope. Desktop login/logout through PLANK was verified with GDM; PCoIP
remains installed as an SSH recovery fallback. Boot recovery and physical console
access remain unverified. Do not reboot, log out, change display managers or
replace an installed client as an incidental step in an input test.

Native capture, physical displays, complete input, recovery, WAN behavior,
assignment isolation, exclusive-seat access and release packaging remain gates.
New transport work waits for host viability; Windows follows the Mac production
gate. The UI still needs authoritative assignment and existing PLANK session
integration. Optional studio power still uses a fake provider; build/test the
private service independently before any live power pilot. A fleet list never
authorizes fleet power changes.

## Working rules

Keep work on reviewable development branches; publication is not a merge or a
deployment. Preserve upstream licenses and history. Do not send messages to
contributors or alter host services without applicable session authorization.
Read the private handoff for exact local paths and the test-host identity;
never copy those details into public commits or issues.
