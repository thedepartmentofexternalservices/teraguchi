# Tailscale shared-workstation integration

## Assignment model

The studio shares one workstation with each artist through Tailscale's existing
machine-sharing invitation. Artists accept with their own Tailscale account.
The client reads the resulting local peer view; it does not invite artists into
the studio tailnet, create accounts, or call the administrator API.

The studio's exact Tailscale DNS suffix is a setup input supplied through trusted
studio configuration. It identifies the studio within the artist's peer list;
it grants no network access. There is no per-artist assignment database or
embedded token. The development launcher accepts this value explicitly; shipping a trusted
configuration/bootstrap is still P3 work.
Do not learn this suffix from an arbitrary peer or accept a wildcard.

Tailscale sharing omits studio tags, and `ShareeNode` describes the reverse
sharing direction. The provider therefore filters the current network map by
exact studio DNS suffix and excludes reverse-share entries. It uses `ID` as the
stable node identifier and only `TailscaleIPs` for endpoints. Hostnames, public
endpoints, routes, tags, and online status cannot authorize a desktop session.

Sources: [sharing](https://tailscale.com/docs/features/sharing),
[CLI status](https://tailscale.com/docs/reference/tailscale-cli), and
[status schema](https://github.com/tailscale/tailscale/blob/main/ipn/ipnstate/ipnstate.go).

## Components

- Client `backend/teraguchi/tailscaleworkstations.*`: bounded asynchronous local
  CLI reader, parser, account-change detection, and current-ID resolution.
- `TailscaleAssignments.qml`: refresh/expiry bridge to `WorkstationFlow` and
  current-target handoff to login. Account changes clear the old list and request
  cancellation/disconnection; refresh failure alone is not revocation.
- `TailscaleLogin.qml`: waits for PLANK host verification, requests credentials,
  correlates each PAM reply to its request and workstation, and prepares a
  native Session only while the assignment still matches.
- `ComputerModel`: resolves the current Tailscale node to a verified Linux PLANK
  bookmark, performs the existing TLS/PAM login, and creates a strict-video
  Session with takeover disabled. It never retains a view row across login.
- `AssignedLoginDialog.qml`, `WorkstationSession.qml`, and `WorkstationWindow.qml`:
  development launcher, credentials, native session execution and deferred cleanup.
- `AssignmentWatch`: a separate event-loop worker that continues checking local
  Tailscale state while SDL owns the Mac UI thread.
- `MacInputPermissions` and the permission panel/gate: non-prompting OS checks,
  explicit Settings actions and cancellation on loss. Native login and Session
  execution repeat the checks; see [permission onboarding](teraguchi-mac-permissions.md).

The picker initially lists permitted studio node candidates. Selecting Connect
can prepare a normal bookmark at that node's Tailscale address. Existing bookmark
choices are preserved. A new bookmark selects native X11 ten-bit capture and
NVENC HEVC 4:4:4 ten-bit. Credentials are requested only after the normal PLANK
poller confirms Linux host metadata and establishes its saved host UUID. A node
running another service fails this check. Preparation is bounded to ten seconds.

Login binds the Tailscale account, stable node ID, current endpoint, bookmark ID,
and PLANK host UUID. Native authentication checks the selected endpoint and host
UUID again before sending credentials and before retaining the reply. PAM
requests have distinct IDs and own their result/credentials until the selected
session consumes them. Cancellation discards that result under the same mutex
used to publish it. An in-flight PAM call may finish, but its result cannot
populate a bookmark or complete a later login. Closing the credential dialog
clears its fields; application Quit retires all pending results.
These checks preserve PLANK's existing TLS policy; a UUID is not a substitute
for a cryptographic certificate pin or distribution trust.

## Runtime limits

The native reader executes only the installed Mac Tailscale CLI with `status
--json`; it has no shell, login, invite, share, policy, or device-write operation.
Requests time out after ten seconds and stdout is bounded to 2 MiB. Raw stdout,
stderr, profiles, and invite links are not logged. JSON and subprocess failures
publish a generic state. Missing Tailscale, sign-in, device approval, stopped
service, missing configuration, and an empty studio list are distinct states.

Snapshots expire after thirty seconds. Monotonic and wall-clock checks prevent
use after delayed timers or clock changes. A fresh refresh failure preserves
an established session; an accepted snapshot removing its assignment requests
disconnect. Actual access enforcement remains Tailscale plus host session policy.
The parent must execute those cleanup requests, not merely hide the workstation.

`sessionPrepared` is **not** a connected or video-qualified event. The native
Session checks admission, performs the existing transport negotiation, and
initializes the real renderer before emitting `presentationReady`. This event
means runtime initialization succeeded, not that a frame was physically presented
or that the Mac has passed hardware qualification. The picker does not fabricate
video/seat attestations from a bookmark or from a successful PAM response.

Each assigned Session owns its authenticated computer snapshot. Polling cannot
redirect its address or replace its host identity. Reconnect uses the same
snapshot, requires a fresh background assignment check, and rechecks the saved
PLANK host UUID before sending credentials. Existing certificate policy remains
in force; UUID matching does not replace certificate trust.

The worker reads every ten seconds with the same bounded native provider.
Confirmed account change, sign-out, node removal or address replacement requests
disconnect through a sticky per-session flag. Failed reads and offline status
prevent new/reconnect attempts without treating them as confirmed removal.
Tailscale still enforces network revocation. The UI cache may expire during a
long native display transition; the native worker then owns the freshness gate.
Its worker/process are stopped before Session execution returns.

Cancel and close request native cleanup. The UI retains the Session until both
`exec()` has returned and `readyForDeletion` has arrived, and blocks a second
connection during cleanup. Native streaming/reconnect continues through PLANK's
existing SDL controls. Qt close/Quit and terminal termination exit through the
normal cleanup path. Real active-session cancellation still needs live testing.

## Development entry and display limit

The ordinary client entry stays available. A strict Mac development build can
open the integrated picker with a trusted launcher:

```sh
"$PLANK_CLIENT_EXECUTABLE" --workstations --studio-dns-suffix "$STUDIO_TAILSCALE_DNS_SUFFIX"
```

Omitting the suffix opens the setup-needed state without running Tailscale.
Wildcards, malformed suffixes, and combining this entry with a stream command
are rejected. The picker uses a separate `Teraguchi Development` settings
namespace and disables mDNS. It does not edit the installed PLANK bookmark
profile. This explicit launcher input is not a signed configuration distributor.

One display binds to the physical screen containing the launcher window at
session start; only that output participates in host layout resolution. Losing
or moving off the selected output closes the assigned session. Existing bookmark
layout choices are not overwritten. **Two-display Mac sessions are rejected
before credentials** and again at the native boundary. The inherited two-output
presentation implementation is Wayland-only. Adding and qualifying native Mac
two-output presentation is still required for the dual-display P3/P4 target.
No one-output fallback satisfies a two-output request.

## Validation

Run with the retained Qt 6.10.2 toolchain:

```sh
bash scripts/test/check-tailscale-workstations.sh "$PRIVATE_TAILSCALE_OUTPUT"
bash scripts/test/check-workstation-ui.sh "$PRIVATE_UI_OUTPUT"
PLANK_CLIENT_EXECUTABLE="$BUILT_CLIENT_EXECUTABLE" \
  bash scripts/test/check-workstation-client.sh "$PRIVATE_CLIENT_SMOKE_OUTPUT"
```

Native tests exercise the production parser/process reader and login-handle
matching with synthetic records and child processes. QML tests exercise the
production adapters with a recording PAM/session model. They cover late replies,
account/address changes, cancelled login, denied login, host verification before
credentials, expiry, revocation, and selected-display preservation. They do not
send credentials, connect to hosts, or perform real share/revocation changes.

The Mac build compiles the production ComputerModel/PAM/Session integration.
A read-only local CLI check confirms the installed Tailscale variant returns the
expected schema. This studio-member Mac cannot prove an external guest's peer
visibility. Guest acceptance, permission prompts, certificate/revocation timing,
actual session cleanup, and clean-Mac onboarding require the scoped live tests.

## Next integration gate

Implement native Mac two-output presentation; provide trusted studio setup and
stable product identity for distribution. Permission onboarding is integrated
but still needs clean-Mac and live revocation qualification. Then
use a real external shared-user Mac to prove one-machine visibility, credentials,
certificate handling, removal, active-session cleanup, reconnect and seat denial.
Do not broaden tailnet membership or add a separate assignment service to make
these tests easier. Preserve strict capture and the working installation.

### Local checkpoint

The development client builds for arm64/macOS 26 with Qt 6.10.2 and the retained
pinned dependencies. Native tests pass 27 results, including background refresh
and removal while the UI event loop is not pumped. The QML suite passes 135
results, including credential clearing, cancellation, cleanup ordering,
permission loss and selected-display rejection. Five native permission results
also pass with injected checks. Strict video admission/frame metadata and all eight
native Quit scenarios pass, including their negative controls.

The actual uninstalled client smoke test uses blank portable settings, an absent
studio suffix and an offscreen window. It rejects invalid setup arguments and
checks QML startup plus idle terminal Quit. It grants no OS permissions and
contacts no workstation. Native controls and physical presentation are not
qualified by these headless tests. The Mac CI entry includes the new smoke test;
hosted CI has not run for this slice.

No app installation, permission grant, Tailscale share/policy edit, or host change
occurred. Exact source/binary receipts, test logs and recovery bundles belong in
the private audit store. Live guest/PAM/session gates remain open.
