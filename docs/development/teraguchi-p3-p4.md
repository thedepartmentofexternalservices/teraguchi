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
- [x] Add [two-output Metal rendering](teraguchi-mac-two-output.md) with shared
  video/input crop geometry, ten-bit GPU checks and hidden-window resource tests.
- [x] Wire native Mac two-output window placement, paired fullscreen/windowed
  transitions, close/minimize/restore and both-output monitoring. Bind native
  display identities before PAM and retain them through reconnect. Synthetic
  binding and hidden native placement checks pass.
- [ ] Qualify native Mac window lifecycle on two physical outputs, including
  Spaces, focus, scale, display loss, reconnect and input across the seam.
  Local fixtures do not establish a complete live two-display session.
- [ ] Qualify the exact integrated candidate with external guest sharing, live
  PAM, startup cancellation, display loss, reconnect, revocation and seat denial.

The explicit `--workstations` development entry is integrated and uses separate
settings. Ordinary launch retains the existing interface. Local tests establish
code behavior; they do not establish live access or physical video qualification.

### 2. Build resumable onboarding

- [x] Add prerequisite states for Tailscale availability, sign-in/share
  acceptance and assigned workstation visibility.
- [x] Add [Mac permission onboarding](teraguchi-mac-permissions.md) with separate
  Accessibility/Input Monitoring statuses and the actual running bundle name.
- [x] Reuse the candidate's non-prompting permission checks. Open System Settings
  only after user action; support cancel, return, retry and permission loss.
  Native login, startup, reconnect and the SDL loop repeat the OS checks.
- [x] Add [signed studio setup import](teraguchi-studio-setup.md), build-pinned
  verification, private persistence, explicit repair messages, and native
  provider/PAM/session expiry checks. No production key is configured yet.
- [ ] Deliver trusted client/setup through the chosen distribution channel and
  qualify clean-Mac import, repair, expiry and key rotation.
- [ ] Add missing tablet/display repair guidance.
- [ ] Decide stable product bundle IDs before permission qualification.
  Keep the diagnostic app's grants separate from product grants.
- [x] Exercise permission cancellation, retry and loss offline, including loss
  before/during PAM. No UI state substitutes for a real OS permission check.
- [ ] Qualify clean-Mac setup, permission persistence and repair with the operator.

### 3. Close access and ownership controls

- [x] Inventory the pinned PLANK endpoints and prepare a
  [guest sharing draft and offline allow/deny cases](teraguchi-guest-access-policy.md).
  TCP/UDP 28989, packaged firewall consistency and source drift are checked.
  The draft has not been merged, validated by Tailscale or deployed.
- [x] Add [workstation-specific HTTPS trust](teraguchi-host-trust.md) from signed
  setup and verify before every assigned PAM/token request. 21 local TLS cases
  prove rejection and credential nondisclosure, including rotation and reconnect.
- [ ] Qualify administrator-supplied host bindings, trusted setup delivery and
  actual certificate rotation using the exact client before pilot PAM credentials.
  Retain the pinned host's IPv4-only QUIC limitation in guest qualification.
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
native login and Session execution with permission onboarding and bound one/two
Mac outputs. Signed studio setup is implemented locally. Next independent coding:
product distribution identity/build-manifest checks. Workstation-specific HTTPS
trust and synthetic credential-nondisclosure tests now pass locally. Endpoint inventory and the offline
guest policy draft are prepared; full-policy and external-guest acceptance remain.
Physical Mac
window/input qualification and P2 hardware limits remain explicit; this slice
does not complete P3 or enter P4.
