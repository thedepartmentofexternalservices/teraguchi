# Guest machine-sharing policy preparation

Source review: 2026-09-15. This prepares the P3 access gate for the assigned Mac
client and Linux PLANK host. No tailnet policy, share, host firewall, service or
installed application changed. P4 entry remains closed.

## Reviewed endpoint path

The [inventory](../../tests/tailscale/endpoint-inventory.json) records source
digests and these reviewed revisions:

- Root baseline: `e96ed37fe8030a29020b1f044d59a55ec9b4dd7a`.
- Client: `c30f0477d5e271da9af524970c89861da10011af`.
- Linux host: `9329784ac41f50cbec0c9d76badfd22227ec5e5f`.
- Kymux: `912ece5c64787997f978673ca60d313898a3548c`.

| Path | Host destination | Source evidence |
| --- | --- | --- |
| Host metadata | TCP 28989, HTTPS `GET /serverinfo` | Host `src/nvhttp.cpp`, client `app/backend/nvhttp.cpp` |
| PAM conversation | Same TCP endpoint, `POST /plank/auth/start` and `/plank/auth/respond` | Same files; credentials travel inside TLS |
| Authorized topology, application list, launch and resume | Same TCP endpoint, `/plank/topology`, `/applist`, `/launch`, `/resume` | Host routes require existing bearer authentication |
| Session setup, video, audio, input, control and reconnect transport | UDP 28989, native QUIC/KyProto | Host endpoint setup in `src/nvhttp.cpp`; client `Session::startPlankTransportDataPlane`; root native transport |
| Tailscale assignment discovery | Local `tailscale status --json` subprocess | Client `TailscaleWorkstations`; no PLANK discovery listener |
| Host PAM broker and supervisor | Local Unix sockets/descriptors | Host `src/auth/pam_broker.cpp` and `src/session/host_supervisor.cpp`; no artist-facing PAM/FreeIPA port |

`network.port` defaults to **28989** in the packaged host configuration and
client policy. Host `nvhttp::PORT_HTTPS` is zero; `net::map_port(0)` supplies both
HTTPS and QUIC. The launch response reports that port as `PlankTransportPort`.
The client consumes the reported UDP port; it does not enforce equality with
its HTTPS port. The draft blocks an unexpected destination port. Changing the
base port requires coordinated host configuration, client policy or explicit
bookmark port, firewall and Tailscale changes.

The assigned picker adds a manual node address, with IPv4 preferred. HTTPS binds
to the dual-stack wildcard `::`; the pinned Linux host QUIC listener binds to
`0.0.0.0`. An IPv6-only peer can currently appear in the provider, but this host
source does not establish an IPv6-only media path. Record that case as blocked
or incomplete; a successful HTTPS probe cannot qualify it.

The client initiates connections. Kymux binds an ephemeral local UDP port;
responses use the established connection. No range of destination ports is
needed for return traffic. Tailscale's coordination, direct-path and relay
connections are separate from these inner PLANK ports. This draft does not
configure underlay egress or claim direct-path performance.

The development picker disables mDNS. Optional relay wake defaults off and uses
port 28988, excluded here. SSH, file services, web management, old Sunshine ports
and archive Phase 0 transport ports are excluded. Wildcard listeners still
require a host firewall limited to the approved interface. Tailscale policy
alone does not restrict LAN interfaces.

The root transport README also describes a newer pre-session library interface.
This inventory follows the actual pinned Linux host and assigned client calls:
HTTPS/PAM/launch followed by native QUIC. Library capability alone does not
establish a different product endpoint flow.

## Draft policy

The [guest policy example](../../packaging/host/linux/tailscale/guest-policy.example.json)
contains one grant from `autogroup:shared` to `*`, with exactly `tcp:28989` and
`udp:28989`. It includes empty legacy ACL and Tailscale SSH lists. It is a
standalone guest-only draft, not a replacement for the studio's complete policy.

Machine shares remain the assignment authority. Tailscale documents that a
recipient can reach only machines shared to that individual; the wildcard
destination further limits those shares by port. Recipients stay outside the
studio tailnet. Tags stripped from the recipient's peer view are not required
by this draft. An invite's delivery email can differ from the accepting account;
qualification must use the actual accepted identity.
[Tailscale sharing](https://tailscale.com/docs/features/sharing#sharing-and-access-control-policies).

Keep reviewed member/admin rules in the private full policy. Inspect every
existing grant and ACL that could match guests. Tailscale combines grants;
a narrow grant cannot remove access from an existing broad rule. Empty lists
in this example cannot cancel broad rules elsewhere in a merged policy.
[Grant semantics](https://tailscale.com/docs/reference/syntax/grants#core-concepts).

These files contain no artist identity, studio address, invite link or token.
They perform no policy upload, invitation, share acceptance or firewall edit.

## Offline checks

Run from the root checkout with Python 3 and local Git:

```sh
python3 -B -m unittest discover -s tests/tailscale -p 'test_guest_policy.py' -v
python3 -B scripts/test/check-tailscale-policy.py --host-source "$PINNED_HOST_SOURCE"
```

Use a local checkout at the recorded host pin when the host submodule is
unpopulated. The guard never clones, fetches, initializes submodules or calls
Tailscale. It checks the draft, packaged host/firewalld ports, product gitlinks
and 19 reviewed source-file digests. A changed pin or reviewed file requires
another inventory. The root revision is the review baseline; later
documentation-only root commits can pass with those source files unchanged.

Regression cases cover both TCP and UDP across all 65,535 destination ports,
the native policy examples, extra grants, ACLs, SSH, wildcard protocols, port
ranges, missing UDP, duplicate JSON, configuration drift and unavailable source
checkouts. These checks inspect this narrow template's declared capabilities.
They are **not** a Tailscale policy compiler or a share/revocation simulation.
18 local regressions and 12 existing CI policy/context tests pass. The hosted
policy job includes the regression suite; hosted CI has not run for this slice.

The [native policy tests example](../../packaging/host/linux/tailscale/guest-tests.example.json)
contains two accepts and 23 denies, with explicit TCP/UDP protocols. In a
private copy, replace the reserved host address and example source with the
actual shared workstation and accepted guest. Merge those tests into the
complete private policy, then run Tailscale's policy validation in the agreed
operator window. This has not run. Policy tests establish policy assertions;
device tests below establish share visibility and revocation.
[Tailscale tests syntax](https://tailscale.com/docs/reference/syntax/policy-file#tests).

## Separate access gates

| Gate | Current code | Remaining gate |
| --- | --- | --- |
| Studio setup | Build-pinned signature, validity and exact DNS suffix | Trusted distribution, production key custody and rotation |
| Assignment | Fresh account/node/address match from the local network map | External guest visibility and actual removal timing |
| Network | Draft permits the two PLANK protocol/port pairs | Full-policy validation, live connections and host firewall enforcement |
| Host certificate | TLS 1.3 and PLANK certificate profile; QUIC fingerprint from HTTPS launch | Workstation-specific HTTPS trust before credentials; replacement tests |
| PAM account | Request-scoped conversation and cancellation | Real FreeIPA/PAM policy, account expiry and denial |
| Seat ownership | Assigned sessions disable takeover and retain host admission | Second identity denied without eviction; same identity reconnect and expiry |

The HTTPS certificate issue is a **P3 pilot blocker**. `NvHTTP::handleSslErrors`
accepts specified trust/name errors for a currently valid self-signed RSA
certificate of the required shape. `postPlankJson` uses that policy for PAM;
there is no persistent workstation-specific pin in that path. Node and host
UUID checks do not supply cryptographic trust. The signed studio suffix also
does not bind a host certificate. Establish a trusted pin/bootstrap and rotation
path before pilot credentials. This slice leaves runtime TLS unchanged.

## Prepared live cases

Run with the agreed endpoints, external guest accounts, operator attendance and
recovery access. Retain exact candidate hashes, accepted identities, addresses,
policy version and observations in the private audit store.

1. Share workstation A with guest A and workstation B with guest B. Check each
   local peer list and picker. Another user in a recipient's tailnet must not
   inherit the share. Test direct node-address attempts too; UI visibility is
   not proof of isolation.
2. Verify TCP/UDP 28989 to the assigned workstation and the listed port denies.
   A closed socket alone is not proof of policy enforcement: retain policy
   validation plus an approved listener/packet observation for deny checks.
   Do not scan the fleet.
3. Verify wrong/changed certificates, bad/expired PAM accounts and missing
   assignments fail independently. Successful PAM does not establish a free
   seat. Use synthetic credentials for certificate rejection tests until local
   credential-nondisclosure checks pass.
4. On the agreed host, authorize both guests temporarily for the seat test.
   Guest B must fail while A remains active with uninterrupted video/input.
   Test same-identity reconnect, expired tokens and host-worker change.
5. Revoke A's accepted share during idle, pending PAM, active input and reconnect.
   Record enforcement and UI cleanup times separately. Verify held input is
   released and reconnect fails. A failed status read alone is not confirmed
   revocation. Restore only the intended share when the case is complete.
6. Verify guests cannot reach other studio nodes, subnet services or exit routes
   through the share. Check IPv4/IPv6 policy coverage while retaining the host's
   IPv6 media limitation. Preserve direct/relay route labels.

No live case has passed in this slice. Physical Mac lifecycle/input, hardware
video, the postponed soak and builder setup remain open.
