# Mac client release verification preparation

Updated 2026-09-15. This is offline P3 release tooling. It does not download,
mount, execute, install, publish, or notarize a package. The production bundle
identity, Developer ID team, studio key, release key and trusted delivery channel
remain unselected. The development client has no configured production studio key.

## Implemented boundary

`scripts/package/sign-client-release.py` signs metadata for one exact Mac client
DMG from the existing `collect-package.py` catalog. It checks filename, version,
branch, channel, platform, architecture, OS major, package-validation status,
size and SHA-256. It copies the recorded root, client, Linux host and Kymux
commits into the signed payload. Missing or conflicting provenance stops signing.
The collector must come from the trusted build; its assertions are not separately
authenticated by this tool and arbitrary source commits are not fetched.

`scripts/package/verify-client-release.py` uses independently trusted policy and
installation history to verify the signature, declared identity, validity,
sequence, version and actual package bytes. It writes a private preparation
receipt and leaves the supplied history untouched. No success path installs or
advances the installed-version record.

The manifest uses Ed25519 with a release-specific message prefix:
`Teraguchi client release v1\n`. Studio setup signatures use a separate prefix;
the release key must also differ from the studio setup key. JSON payloads and
envelopes use sorted keys, compact separators, UTF-8 and canonical base64.
Duplicate fields, extra payload fields, malformed encodings and oversized JSON
are rejected. The outer file may have surrounding whitespace; the signed payload
may not. JSON is bounded to 32 KiB and package files to 8 GiB. Final symlinks and
nonregular files are rejected, with package size/metadata rechecked after hashing.

## Private input contract

Profiles, policy, history, keys, signed manifests and receipts stay outside Git,
in owner-only directories (`0700`) and files (`0600`). Use absolute paths. New
outputs must not exist. The commands report generic errors without printing
input values, paths, OpenSSL diagnostics or key material. The collection and DMG
may be in the existing artifact catalog. Do not relabel a collected DMG: the
current adapter deliberately retains the inherited `plank-client_…_arm64.dmg`
filename until the product packaging identity is implemented.

The signing profile has these exact fields:

- `schema_version`: integer `1`.
- `product`: `teraguchi-client`; `platform`: `macos`; `architecture`: `arm64`.
- `bundle_id`: the chosen reverse-DNS application identifier.
- `team_id`: the chosen ten-character uppercase Developer ID team identifier.
- `minimum_os`: major/minor string, for example `26.0`. The collector binds its
  OS major; actual application/dependency deployment targets need package checks.
- `studio_public_key`: the 64-character lowercase hexadecimal Ed25519 public key
  intended to be compiled into this candidate.
- `channel`: `candidate` or `stable`.
- `sequence`: positive integer, at most 2,147,483,647, increasing for every new
  authorization, including rollback. Never reuse an authorization sequence.
- `package_version`: three numeric components; candidates require the exact
  branch suffix recorded by the collector, such as `1.2.3-test-candidate`.
- `issued_at`, `expires_at`: canonical UTC `YYYY-MM-DDTHH:MM:SSZ`. Authorization
  must be current and span at most 30 days. Verification assumes a trusted clock.
- `operation`: `update` or `rollback`.
- `rollback_from_sha256`: empty for updates; current package digest for rollback.

The signer derives `package_sha256`, `package_size` and `source` from the package
and collection. `source` has exact `root`, `client`, `host`, `kymux` commit fields.

Trusted policy contains exactly the eight identity fields (`product`, `bundle_id`,
`team_id`, `platform`, `architecture`, `minimum_os`, `studio_public_key`, `channel`)
and `release_public_key`, the independently provisioned Ed25519 public key in
lowercase hexadecimal. Never obtain this policy or key from the download being
checked. The verifier requires exact agreement with every declared identity field.

Installation history contains exactly `schema_version: 1`, `policy_sha256`,
`highest_sequence`, `current`, `previous`, and `session_state`. The policy digest
is SHA-256 of canonical policy JSON. A first-install record uses sequence zero
and null current/previous. Otherwise, each retained entry has only `sha256` and
`version`, and the high-water sequence is positive. History is bound to one
policy/channel. Key, identity and channel migration need a separate trusted
procedure; this implementation does not reset or migrate history automatically.

Only an `idle` session assertion is accepted. This CLI does not inspect the
running client: the operator or eventual installer must establish idle state
authoritatively. A receipt sets its proposed history's session state to `unknown`
so it cannot immediately be reused as an idle assertion.

## Offline commands

These commands require prepared private inputs and a pinned OpenSSL 3 executable.
They do not create production keys. The signing key must already be usable
noninteractively by that OpenSSL executable; no passphrase CLI option is exposed.

```bash
python3 -B "$PLANK_SOURCE_ROOT/scripts/package/sign-client-release.py" \
  --profile "$RELEASE_PRIVATE/profile.json" \
  --collection "$PACKAGE_COLLECTION/manifest.json" \
  --package "$CLIENT_DMG" \
  --private-key "$RELEASE_PRIVATE/release-signing.pem" \
  --openssl "$RELEASE_OPENSSL" \
  --output "$RELEASE_PRIVATE/client-release.json"

python3 -B "$PLANK_SOURCE_ROOT/scripts/package/verify-client-release.py" \
  --manifest "$RELEASE_PRIVATE/client-release.json" \
  --package "$CLIENT_DMG" \
  --policy "$RELEASE_PRIVATE/trusted-policy.json" \
  --state "$RELEASE_PRIVATE/installation-state.json" \
  --openssl "$RELEASE_OPENSSL" \
  --output "$RELEASE_PRIVATE/preparation-receipt.json"
```

The receipt records the input manifest/package hashes, source pins, declared
identity, verification time, authorization expiry, operation and proposed history.
It explicitly records `installation: not-performed` and
`apple_signature_and_notarization: not-checked`. Retain it with private evidence.
Do not use a receipt as a reusable installation authorization.

## Update and rollback behavior

Updates require a sequence above the accepted high-water value and cannot lower
the three-component version. A stable version cannot be replaced with different
bytes under the same version number. Candidate revisions sharing a base version
are ordered by the trusted release sequence, not branch-name alphabetization.
The current package digest cannot be installed again as a new update.

Rollback requires a new, higher-sequence signed authorization that binds both
the exact current digest and the exact retained previous digest/version. The
previous package must still be available and pass byte verification. An old
download or old update manifest is insufficient. The preparation receipt proposes
retaining the displaced current package so recovery remains reviewable; it does
not remove either package or modify state.

An eventual installer must lock state, confirm no active/pending session, reverify
the authorization and package at use, check actual Apple signatures and identity,
retain the verified previous package, and advance durable history only after a
successful atomic install. Interrupted installation, permission persistence,
post-install launch failure and actual rollback remain clean-Mac acceptance cases.
Never mark history accepted merely because the preparation CLI returned success.

## Local evidence and limits

Twenty-five tests pass using real OpenSSL Ed25519 signatures, ephemeral test keys
and synthetic bytes named as DMGs. Coverage includes altered content/size,
wrong signing key/domain, changed signed metadata, expiry/future/overlong validity,
identity mismatches, replay, downgrade, stable replacement, policy/history mismatch,
active/unknown session state, exact fresh rollback, stale/wrong rollback, malformed
JSON/base64, collection conflicts, symlinks/FIFOs, private output permissions,
CLI interoperability, nondisclosing errors and unchanged input history. Synthetic
packages are never mounted or claimed to be Apple-signed applications.

Run on the prepared Mac toolchain:

```bash
bash "$PLANK_SOURCE_ROOT/scripts/test/check-client-release.sh" \
  "$RELEASE_PRIVATE/regression"
```

The Mac client CI path includes this suite; hosted CI has not run at this
checkpoint. Existing package-collection tests remain separate.

Signed declarations do not inspect the DMG's actual bundle ID, Team ID, embedded
studio key, deployment target or notarization ticket. Existing Mac packaging
already performs signing/notarization gates; the chosen Teraguchi identity and
build-key attestation still need integration there. Native updater/installer
integration, production key custody/rotation, trusted initial delivery, durable
history protection, Apple trust validation and clean-Mac recovery are open P3
gates. Owner-only JSON is not tamper-resistant rollback protection against the
owning account replacing or deleting it. This slice does not enter P4.
