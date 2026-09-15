# Tailscale shared-workstation integration

## Assignment model

The studio shares one workstation with each artist through Tailscale's existing
machine-sharing invitation. Artists accept with their own Tailscale account.
The client reads the resulting local peer view; it does not invite artists into
the studio tailnet, create accounts, or call the administrator API.

The studio's exact Tailscale DNS suffix is a setup input supplied through trusted
studio configuration. It identifies the studio within the artist's peer list;
it grants no network access. There is no per-artist assignment database or
embedded token. Shipping a trusted configuration/bootstrap is still P3 work.
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

The picker initially lists permitted studio node candidates. Selecting Connect
can prepare a normal bookmark at that node's Tailscale address. Existing bookmark
choices are preserved. A new bookmark selects native X11 ten-bit capture and
NVENC HEVC 4:4:4 ten-bit. Credentials are requested only after the normal PLANK
poller confirms Linux host metadata and establishes its saved host UUID. A node
running another service fails this check. Preparation is bounded to ten seconds.

Login binds the Tailscale account, stable node ID, current endpoint, bookmark ID,
and PLANK host UUID. Native authentication checks the selected endpoint and host
UUID again before sending credentials and before retaining the reply. PAM
requests have distinct IDs, so a cancelled request cannot complete a later one.
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

`sessionPrepared` is **not** a connected or video-qualified event. The parent
still owns Session execution, selected physical-display binding, reconnect,
close/Quit cancellation, and `readyForDeletion`. The new components are included
in the client resources and the provider is registered with QML, but `main.qml`
has not switched to this interface. End-to-end onboarding remains unfinished.

## Validation

Run with the retained Qt 6.10.2 toolchain:

```sh
bash scripts/test/check-tailscale-workstations.sh "$PRIVATE_TAILSCALE_OUTPUT"
bash scripts/test/check-workstation-ui.sh "$PRIVATE_UI_OUTPUT"
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

Connect these components to the production credential dialog and Session
presentation while preserving selected physical displays and lifecycle cleanup.
Provide trusted studio configuration through setup. Then use a real external
shared-user Mac to prove one-machine visibility, login, removal, and seat denial.
Do not broaden tailnet membership or add a separate assignment service to make
these tests easier. Keep strict capture and the existing working installation.

### Local checkpoint

The development client builds for arm64/macOS 26 with Qt 6.10.2 and the retained
pinned dependencies. It reports `1.0.103-assignment-refresh` in an offscreen
version launch. The native provider suite passes 23 results; the combined QML
suite passes 111, including setup/cleanup. Strict video admission and frame
metadata regressions pass. The preview blocks network requests and renders 32
simulated screens. Offscreen captures verify layout only; native control pixel
qualification remains the prior evidence.

The compiled provider also parsed the installed local Tailscale CLI successfully.
That check sent no host probe or login request and exposed counts only. Raw
logs and exact source/binary receipts are retained in the private audit store.
No app installation, permission grant, Tailscale share/policy edit, or host change
occurred. Hosted CI and external guest/live PAM tests have not run for this slice.
