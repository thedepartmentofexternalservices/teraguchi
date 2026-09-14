# macOS Client deployment-target change

Use one validated target for the client dependency build, qmake, Cargo, bundle
metadata, and packaging. Teraguchi defaults to 26.0 and permits explicit 27.0;
Mac Host retains its separate macOS/SDK 27 requirement. This slice retains the
original VideoToolbox decoder policy and contains no native Quit change.
PLANK/Alan Latteri attribution and component licenses remain intact.

## Build and cache rules

Export `PLANK_MACOS_CLIENT_TARGET=26.0` or `27.0` before the canonical client
bootstrap/build/package commands. The SDK must be at least the target major
version. A conflicting MACOSX_DEPLOYMENT_TARGET fails before building. Use a
fresh private dependency directory when changing target, SDK, or bootstrap
recipe. The profile records the bootstrap script SHA-256, including its pinned
archive and dependency-patch inputs, without depending on the separate decoder PR.
Existing dependencies with the earlier profile format intentionally require a
fresh bootstrap; never edit a profile to bless mismatched libraries.

The package gate inspects every Mach-O slice and bundle minimum-OS declaration.
Signing, notarization, dependency closure, and build-path gates remain enforced.
Hosted CI builds both client targets with SDK 27; only the Host's 27 job runs.
That matrix provides compile coverage, not runtime support for every 26.x release.

## Verification

29 focused tests pass locally: eight target/cache cases, four minimum-OS cases,
nine build-path cases, and eight CI context cases. Negative tests reject
unsupported targets, old/malformed SDKs, conflicting settings, unprofiled
libraries, cross-target/SDK reuse, changed dependency recipes, and malformed
Mach-O metadata. The client metadata change is extracted from `0dd28122`.

```bash
python3 tests/packaging/test-macos-client-target.py -v
python3 tests/packaging/test-macos-minimum-os.py -v
python3 tests/packaging/test-build-paths.py -v
python3 -m unittest discover -s tests/ci -v
```

The installed combined build passed 106 Mach-O checks, dependency closure,
local signature checks, and live streaming on the Mac below. This independent
slice still requires its own hosted builds. Production distribution and
runtime coverage beyond that single OS/model remain open.

## Tested configuration

Test environment: Mac Studio M2 Ultra, 64 GB, macOS 26.5.2 (25F84), SDK 26.5,
Qt 6.10.2, and the pinned private FFmpeg 9.0.1 dependency tree. Earlier live
checks used Rocky Linux 9.7, Autodesk Flame 2027.1 (application package
2027.1.0-249), RTX PRO 6000 Blackwell Max-Q, NVIDIA 580.126.18, and upstream
PLANK Host v1.0.103. The installed development app remains the combined root
`22bcfec9531ab1243c615a441713d450366c9a11` / client
`2f0e0dbf9c10bb6f382150f6ec6ee3d9b657ac8d` build. No new app or Host package was
installed during this split. Live evidence from that app must not be relabeled
as a standalone build of this branch. Hostnames, raw logs, and fixtures stay private.
