# Signed studio setup

The development picker now imports a signed studio setup file, verifies it with
a public key pinned into the client, saves it privately and rechecks it on each
launch. Artists still accept an individual Tailscale machine-share invitation
and authenticate to their workstation through the existing TLS/PAM path.
Setup neither grants a share nor creates an account, seat or server connection.

## Artist flow

1. Open the configured client’s workstation picker.
2. Click **Import setup…** and select the `.teraguchi-studio` file supplied by
   the studio administrator. A verified studio name appears after successful
   validation and saving.
3. Accept the workstation invitation in Tailscale, sign in with that account,
   refresh the list and connect to the selected workstation.

Import is disabled while login/session cleanup is pending. An invalid import
shows an error and preserves the last valid setup. Missing, expired or invalid
saved setup blocks discovery and login until repaired. Setup never automatically
connects a workstation, accepts an invitation or changes Mac permissions.

The explicit development entry remains `--workstations`. A local signed file
can also be imported with `--workstations --studio-config "$STUDIO_SETUP_FILE"`;
that path must be absolute. An explicit failed CLI import exits without falling
back to saved setup. Ordinary PLANK startup is unchanged. Product naming,
default launch behavior, bundle IDs and signed/notarized distribution remain a
separate release slice; this implementation is not a production distributor.

## File and trust contract

The UTF-8 JSON envelope contains exactly `payload` and `signature`, both
canonical base64. The payload is compact, sorted-key JSON with these fields:

| Field | Meaning |
| --- | --- |
| `version` | Integer `1` |
| `revision` | Increasing positive integer, at most 2147483647 |
| `label` | Plain studio name, at most 80 UTF-16 code units |
| `dns_suffix` | Exact lowercase Tailscale suffix, such as `studio-example.ts.net` |
| `issued_at` | UTC timestamp in `YYYY-MM-DDTHH:MM:SSZ` form |
| `expires_at` | UTC timestamp, after issuance and at most 90 days later |

The Ed25519 signature covers the exact bytes
`Teraguchi studio setup v1\n` followed by the payload bytes. The whole file is
limited to 8192 bytes. Unknown fields, duplicate/ambiguous serialization,
noncanonical base64, wrong versions, malformed dates, future/expired documents,
wildcards, URLs, and signatures from a different key are rejected. No credential,
artist identity, host address list, invitation URL or Tailscale API key belongs
in this document.

A client pins one Ed25519 public key through the build-only
`PLANK_STUDIO_CONFIG_PUBLIC_KEY` input: 64 lowercase hexadecimal characters
representing the raw 32-byte public key. It cannot learn its trust key from the
setup file, command line or runtime environment. The qmake rule generates a
header dependency so a retained build also rebuilds when the key is removed or
changed. Malformed nonempty key inputs fail the build.

Without a build key, signed setup is unavailable and the UI requests a configured
client. The existing explicit `--studio-dns-suffix` development launcher remains
available only in builds without a key and is labelled **Development setup**.
Builds with a key reject that unsigned override. No real studio key is embedded
in this checkpoint; test keys are ephemeral and are not distribution keys.

The administrator must deliver the matching client through a trusted channel.
This file signature does not establish the identity of an arbitrary downloaded
client, provide notarization, or implement the later package-update verifier.
A key rotation requires a new configured client and a setup signed by that key.

## Persistence and session enforcement

The client atomically saves the original signed envelope in its application-data
folder as `studio-setup.json`, with owner-only permissions. Portable test mode
uses the isolated working directory’s `studio-config/` folder. No imported path
or unsigned copy of its contents is trusted on restart. Symlink files and
non-regular files are rejected; failed reads/writes leave the current setup intact.

Lower revisions and conflicting content at the same revision are rejected
against the current saved, signed revision, including when that revision has
expired. This detects ordinary re-imports of older setup. It is not protected
rollback storage against an attacker who controls the local account and can
replace/delete the saved file. Durable package-update rollback protection remains
open; this profile store must not be described as providing it.

The native provider requires a valid setup before starting a local Tailscale
read, accepting a result or resolving a login target. Each PAM request keeps the
exact verified setup object used at dispatch. Session creation rejects a changed
setup even when its DNS suffix matches. The session and its background assignment
checker retain an immutable permit, so Qt UI state cannot extend it while SDL
owns the main thread. Startup/reconnect and the native streaming loop enforce
expiry; the loop checks at least every two seconds and uses normal held-input
and transport cleanup when setup expires. Wall-clock rollback and elapsed-time
expiry invalidate the current permit. This is not a remote trusted-clock service.

## Administrator preparation

Use an operator-owned Ed25519 key and profile in private storage outside Git.
The repository never generates or stores a production private key. The signer
requires owner-only key/output storage and refuses to overwrite a destination.
An encrypted key may prompt through OpenSSL; do not pass passwords in arguments.

```sh
python3 scripts/package/sign-studio-setup.py \
  --openssl "$PINNED_OPENSSL" \
  --private-key "$STUDIO_PRIVATE_KEY" \
  --profile "$STUDIO_PROFILE_JSON" \
  --output "$STUDIO_SETUP_FILE"
```

All paths must be absolute. Use the pinned OpenSSL 3 toolchain. Its unbundled Mac
CLI may require `DYLD_LIBRARY_PATH="$PLANK_MAC_CLIENT_DEPS/install/lib"` when
running from the retained dependency prefix. This affects the local signing tool,
not client trust. The file is signed offline; no API request or invitation is sent.

Build the client using the normal Mac build runbook with the matching raw public
key in `PLANK_STUDIO_CONFIG_PUBLIC_KEY`. Stable product identity, private-key
custody, Developer ID signing, notarization, transfer verification, clean-Mac
installation and permission persistence still need qualification before delivery.

## Local verification

```sh
bash scripts/test/check-studio-setup.sh "$PRIVATE_SETUP_OUTPUT"
bash scripts/test/check-tailscale-workstations.sh "$PRIVATE_PROVIDER_OUTPUT"
bash scripts/test/check-workstation-ui.sh "$PRIVATE_UI_OUTPUT"
```

Use the retained Qt 6.10.2 and Mac dependency roots. The setup test creates a
private ephemeral Ed25519 key, signs a profile with the production signing tool,
and verifies it with the actual native implementation. Negative cases include
wrong key/domain, tampering, invalid fields/dates/revisions, oversize input,
conflicting/older imports, expiry after restart, runtime key substitution,
fake-QML provider objects and direct unsigned suffix injection. The same retained
fixture build is rebuilt with its key removed to detect stale compiled trust.
No test contacts Tailscale, captures input, changes permissions, signs an app or
installs a candidate. See the [P3/P4 checklist](teraguchi-p3-p4.md) for remaining gates.

Local results: 23 setup QtTest results, three retained-build key-removal results,
28 provider/worker results and 146 QML results pass. Forty-two network-denied
simulated screens render, including setup needed/verified/expired states. Text
and layout were reviewed; offscreen rendering does not qualify native control
painting. The complete arm64/macOS 26 client build, uninstalled blank-settings
startup/invalid-argument smoke and eight native Quit scenarios also pass. The
candidate has no production studio key, and no live signed-setup session or
clean-Mac installation was exercised.
