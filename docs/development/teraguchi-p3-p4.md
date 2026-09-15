# P3 and P4 implementation order

Updated 2026-09-15. The operator prioritized work that advances P3 and P4 while
physical input testing, the stability session, and builder setup remain paused.
This follows the PLANK-based roadmap retained on `codex/product-roadmap` at
`d26d192`. It does not waive P2 or authorize a deployment.

P3 delivers a usable, controlled Mac candidate. P4 proves it on real artist WAN
routes. P3 development and P4 test preparation can proceed now. P4 live entry
requires the P2 hardware gates and P3 access/distribution controls.

## P3: work in this order

### 1. Finish the assignment-to-session boundary

- [x] Add generation-scoped refresh replies, bounded cache lifetime, refresh
  timeout, and explicit stale UI state to the offline picker.
- [x] Cancel pending connection work on expiry; reject late replies; retain the
  selected displays; keep established sessions on refresh failure; disconnect
  on explicit assignment removal in an accepted snapshot.
- [x] Add a native local Tailscale provider and selected-host verification boundary.
  Keep stable peer/workstation identity independent of address and row order.
  A bookmark's `authorized` or `online` role cannot establish assignment or a
  free seat. Avoid introducing a separate account database or catalog service.
- [x] Resolve the stable ID against the current native model at action time.
  The new `ComputerModel` assignment methods resolve account, node, route, and
  host identity without retaining an index. Offline tests cover changed handles,
  sign-out, old replies, and cancellation. Live certificate/host-change behavior
  remains part of the integration gate.
- [x] Wire the development picker to existing TLS/PAM and native `Session`
  execution. Use request-scoped authentication, a session-owned target snapshot,
  background assignment checking and takeover denial. Preserve strict video
  admission and wait for `readyForDeletion` plus return from `exec()`.
- [x] Add cancellation/cleanup handling for login, startup, disconnect and Quit;
  exercise model lifetime ordering, idle application Quit and the native SDL Quit
  bridge locally. Real active-session cleanup remains a live gate.
- [ ] Implement and qualify native Mac two-output presentation. The current
  integrated entry binds one physical output and explicitly rejects two before
  credentials. It does not silently select one or span two onto one surface.
- [ ] Qualify the exact integrated candidate with external guest sharing, live
  PAM, startup cancellation, display loss, reconnect, revocation and seat denial.

The explicit `--workstations` development entry is integrated and uses separate
settings. Ordinary launch retains the existing interface. Local tests establish
code behavior; they do not establish live access or physical video qualification.

### 2. Build resumable onboarding

- [x] Add prerequisite states for Tailscale availability, sign-in/share
  acceptance and assigned workstation visibility. Trusted setup currently comes
  from an explicit development launcher argument.
- [ ] Add Mac permission onboarding and trusted distributable studio setup.
- [ ] Reuse the candidate's non-prompting permission checks. Open the normal
  system settings flow only after user action; support cancel, return, retry,
  missing tablet/display, and permission loss with clear next actions.
- [ ] Decide stable product bundle IDs before permission qualification.
  Keep the diagnostic app's grants separate from product grants.
- [ ] Exercise the state flow offline, then qualify clean-Mac setup and repair
  with the operator. No UI state substitutes for a real OS permission check.

### 3. Close access and ownership controls

- [ ] Inventory the endpoints used by the pinned PLANK path and prepare a
  deny-by-default sharing policy with offline allow/deny cases. Do not copy
  the old Phase 0 transport ports into a deployed policy.
- [ ] Check assignment, certificate trust, PAM account authentication, and
  exclusive seat ownership separately. Test second-identity denial, expired
  sessions, same-identity reconnect, and revocation.
- [ ] Run shared-user visibility, allowed/denied ports, and revocation on the
  agreed test scope with the operator. Live policy changes need a scoped window.

### 4. Prepare distribution and recovery

- [ ] Extend the existing Mac DMG/build manifest path for the chosen product
  identity. Retain exact root/client pins, package hash, signer, and version.
- [ ] Add fail-closed update verification: modified package, wrong signer,
  expired/replayed manifest, and downgrade rejection. Keep installation outside
  an active session; retain a verified previous version for rollback.
- [ ] Prepare actionable support messages and a bounded diagnostic export that
  excludes credentials, artwork, keystrokes, pen coordinates, and identities.
- [ ] Qualify signing, notarization, clean install, permission persistence,
  cancellation, update, and rollback using the exact candidate. Signing and
  installation are separate from an offline compile/package-content check.

## P4: prepare now, run after entry gates

- [ ] Prepare a private evidence manifest linking each run to exact candidate
  hashes, hardware/OS, display count, route class, duration, and test result.
  Missing measurements and skipped tests remain visibly incomplete.
- [ ] Inventory the existing native transport counters before adding telemetry.
  Record direct/relay path, RTT, jitter, loss, wire bitrate, FEC, dropped/replaced
  frames, queue sizes, and per-stage timings. Counter sums do not prove physical
  input-to-display latency.
- [ ] Prepare repeatable loss/burst and endpoint-change cases from the inherited
  acceptance criteria. Keep impairment and recovery procedures reversible and
  limited to the designated pilot endpoints.
- [ ] Run at least two representative artist routes, with 30-minute direct-path
  load observations, interruption/reconnect, revocation, and seat-denial drills.
  Relay runs retain that label and do not pass the direct-path gate.
- [ ] Complete real Flame editing, Paint, QuickTime playback/scrubbing, audio,
  and input workloads. Preserve evidence of failures before reconnecting where
  practical. Finish five eight-hour single-display shifts and five eight-hour
  dual-display shifts before claiming both configurations production-ready.

## P2 gates that still control pilot entry

Native ten-bit capture and exact video; full traced pen/keyboard input; physical
one/two-display color and mapping; sustained audio/playback stability; recovery
and seat ownership; exact-candidate qualification. See the
[resume plan](teraguchi-resume-plan.md) for evidence limits and the paused tests.
Offline P3 work cannot satisfy these gates. Builder provisioning remains paused.

## Next coding slice

The [integrated development picker](teraguchi-tailscale-workstations.md) now reaches
native login and Session execution. Next: native Mac two-output presentation,
permission onboarding, and trusted configuration/product identity. Then prepare
external guest and exact-candidate live acceptance. Keep P2 hardware limits and
the deferred operator work explicit; this slice does not complete P3 or enter P4.
