# Workstation certificate trust

The assigned Mac client now requires workstation certificate bindings from
version-2 signed studio setup before login. Tailscale sharing determines the
assignment; the signed binding establishes which certificate may receive
credentials for that node. No new account, assignment database or network
service is added.

## Admission and requests

A binding contains the stable Tailscale node ID, PLANK host ID and one or two
SHA-256 fingerprints of the host's DER leaf certificate. Native parsing rejects
missing/duplicate identifiers, malformed fingerprints and certificate reuse
across nodes. The existing setup signature, revision and validity checks cover
these fields. Version-1 and unsigned development setup remain discovery-only.

Before opening the credential dialog, the model checks for a signed binding and
matches the advertised host ID. Missing trust opens a repair message. The
certificate is then verified by the real HTTPS request before any username,
password, PAM conversation identifier or bearer token is transmitted. A claimed
host UUID cannot bypass the certificate check.

Each assigned request owns a fresh QNetworkAccessManager, disables redirects,
HTTP/2, proxy use and cookies, and binds the exact current node IP and control
port. Its TLS handshake must satisfy TLS 1.3, the existing PLANK certificate
profile, an approved fingerprint and a current setup/connection permit.
`encrypted()` aborts before HTTP data if any check fails. Fresh managers avoid
Qt's connection-reuse exception to that signal. See the
[Qt 6.10 signal contract](https://doc.qt.io/qt-6.10/qnetworkaccessmanager.html#encrypted).

The assigned path permits only the current metadata, PAM, topology, application
list, launch and resume routes. Responses are bounded to 32 KiB for PAM and
1 MiB for metadata/launch. HTTP/TLS errors from this boundary do not echo
arbitrary server text. The
launch UDP port must equal the bound control port, and its reported QUIC
fingerprint must match the verified HTTPS leaf. The pinned Linux host already
uses that port/certificate pair.

The request-scoped PAM result owns this trust. Session creation checks the same
setup object and node; the session copies it without writing to a bookmark.
Startup, token refresh and reconnect use that immutable trust and current
assignment/cancellation checks. Permission, display, seat and strict-video
checks remain separate. The ordinary PLANK entry keeps its inherited TLS path;
this qualification applies to the explicit assigned-workstation entry.

A worker restarting for a display change can refuse or time out before sending
a certificate. With a still-valid setup/assignment and no TLS rejection, those
failures retain their network-error type so the existing bounded startup wait
can retry. Certificate/profile failures and expired or cancelled permission
remain trust denials. This distinction sends no HTTP data before verification
and does not extend the retry window.

## Administrator bootstrap and rotation

Prepare bindings through an independently trusted administrator channel: retain
an already-verified workstation node ID, host ID and local certificate copy.
Do not learn a trusted fingerprint from the artist's unverified HTTPS connection,
an error dialog or an unauthenticated server response. A read-only local
fingerprint command is:

```sh
"$PINNED_OPENSSL" x509 -in "$VERIFIED_HOST_CERTIFICATE" -outform DER |
  "$PINNED_OPENSSL" dgst -sha256
```

Put the matching lowercase digest and IDs in the private version-2 profile and
use [the studio signing helper](teraguchi-studio-setup.md#administrator-preparation).
The signed file and actual bindings stay outside public Git. Include only the
workstations intended for that setup delivery. The file itself grants no share
or seat; an unrelated peer with the same display name remains unauthorized.

A controlled certificate replacement uses increasing setup revisions:

1. Independently verify the replacement certificate. Sign a newer setup with
   both the current and replacement fingerprints for the same node/host binding.
2. Deliver/import that setup while the client is idle. Import is disabled while
   login or session cleanup is pending. There is no automatic trust-on-first-use
   or artist-facing certificate override.
3. Change the workstation certificate during the agreed maintenance window and
   qualify login/reconnect through the replacement. This live operation has not run.
4. Sign/import another newer setup retaining only the replacement fingerprint.
   Retest old-certificate denial and reject older/conflicting setup imports.

Retain recovery access and the previous verified package/setup evidence.
Downgrade prevention uses the saved signed revision, including after expiry and
restart. As documented for studio setup, replacing/deleting application data as
the local account can reset that history; it is not secure anti-rollback storage
against a compromised client account. Production key custody, trusted delivery,
actual host bindings and certificate rotation remain operator qualification.

## Local evidence

```sh
bash scripts/test/check-studio-setup.sh "$PRIVATE_SETUP_OUTPUT"
bash scripts/test/check-host-trust.sh "$PRIVATE_TLS_OUTPUT"
bash scripts/test/check-tailscale-workstations.sh "$PRIVATE_PROVIDER_OUTPUT"
bash scripts/test/check-workstation-ui.sh "$PRIVATE_UI_OUTPUT"
```

The production NvHTTP code runs against synthetic loopback HTTPS servers with
fresh test certificates and fake credentials. 24 cases pass: success; wrong pin,
node, port and setup; development setup; certificate/setup expiry; TLS 1.2 and
invalid certificate profile; certificate swaps before password, token use and
reconnect; authorized overlap and retired-pin denial; cancellation; redirects
at PAM and bearer-token routes; malformed/oversized replies; connection refusal,
pre-certificate timeout and cancellation during that timeout. The transport
cases require a network exception, while all trust cases require a rejection.
The pre-certificate peers receive no HTTP data or credentials. A baseline run
reproduces the incorrect trust rejection for a refused connection. Redirect canaries
receive no requests. The deliberately unpinned control receives fake credentials,
proving the server-side request oracle detects the missing check.

The initial qualification also recorded 25 native setup results,
three retained-build key-removal results, 28 provider
results and 147 QML results pass. The complete arm64/macOS 26 client builds with
no production studio key. Forty-two network-denied synthetic UI screens render;
blank-settings startup/invalid-argument/idle-Quit smoke passes. These results do
not qualify installed credentials, live PAM/FreeIPA, share revocation, physical
input/video, package signing or artist readiness. Those local checks changed no
host, share, policy, permission or installed application.

The later supervised headless pilot reached a live desktop and recovered through
the login-to-user-desktop transition. Logs attest a single 3840x2160x60 stream,
native 10-bit capture, HEVC 4:4:4 and hardware decoding; the operator confirmed
the desktop works. Machine-specific evidence is retained privately. The new
network-error classification passed the loopback suite but has not replaced the
running pilot or been qualified against a fresh live display transition.
