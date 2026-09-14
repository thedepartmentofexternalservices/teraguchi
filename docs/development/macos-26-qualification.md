# macOS 26 client qualification, 2026-09-14

The Apple Silicon development client builds, launches, and streams a Flame
workstation on macOS 26.5.2. The operator reported quick, responsive interaction,
then one picture freeze during a QuickTime import/play attempt. Reconnecting
restored streaming. Stability remains open; this is not a production release.

## Reproducible source and artifacts

- Built root: `328688773be3b9d9ae0c51a71cbd98b0e2ae034e`.
- Built client: `0dd2812288c3cacb9553a028477a3d36313d5461`.
- Unchanged Linux Host: `9329784ac41f50cbec0c9d76badfd22227ec5e5f`.
- Unchanged transport: `912ece5c64787997f978673ca60d313898a3548c`.
- Client version: `1.0.103-macos26-client`; deployment target `26.0`.
- Toolchain: Apple clang 21.0.0, selected SDK 26.5, Qt 6.10.2, Rust 1.89.0,
  private FFmpeg 9.0.1 with both required VideoToolbox patches.
- Client hardware: Apple M2 Ultra, 64 GB, macOS 26.5.2 (25F84).
- Host package: upstream PLANK `v1.0.103`, Rocky 9.7 x86_64 RPM,
  source root `06bc71add24d7b7bddd19db1a9c2e914f0cb8383`.
- Host RPM SHA-256:
  `e5fd6e3606dc1b2738fb99427c8ee211fc251ad283652a62dae4e411c85a8e56`.

Later documentation and CI commits do not change the recorded artifact pins.
The installed Mac app is an ad-hoc-signed development build. It has no Developer
ID signature or notarization ticket and is not a distributable release package.
Release signing and notarization gates remain enforced by the package script.

## Completed checks

A clean worktree and fresh target/SDK dependency tree built successfully from
pinned sources. The deployed app contains 106 Mach-O binaries. Bundle minimum-OS,
arm64 coverage, dependency closure, deep strict code-signature verification,
and offscreen version checks passed. All 25 focused tests passed: minimum-OS
validation, build-path checks, client target/cache policy, and CI context. Shell
syntax and diff checks passed. Hosted CI has not qualified this branch. No
operating-system upgrade was performed.

The hardware patch requires VideoToolbox hardware for HEVC/H.264 and queries the
session's hardware-decoder property. A missing, unreadable, or false property
fails that hardware path. The strict probe checks every decoded frame and exact
frame count. This does not remove the inherited client's separate exact-format
software fallback; software results cannot satisfy Teraguchi's hardware gate.

| Decode test | Result |
| --- | --- |
| 4K moving HEVC RExt 10-bit 4:4:4, one stream | 1,800 frames, hardware attested, 112.023 fps / 1.867x |
| Same tuple, two concurrent streams | 1,800 frames each, both hardware attested, 117.894 / 117.442 fps |
| Embedded HEVC 10-bit 4:4:4 identity-GBR fixture | Hardware attested; p410le, matrix 0, full range, matching depth/chroma |
| Embedded H.264 10-bit 4:4:4 fixture | Hardware path rejected; separate software comparison decoded successfully |

The sustained samples use BT.709 YCbCr. They requalify Phase 0 `MAC-01` and
`MAC-02` for that tuple on this M2 Ultra. The identity-GBR fixture is one frame
at 1280x720; it is not a sustained dual-display identity-GBR test. Results do not
qualify other Mac models, physical output precision, or end-to-end pixel fidelity.

## Installed Host and live session

The authorized Rocky 9.7 Host has an RTX PRO 6000 Blackwell Max-Q and driver
580.126.18. The verified RPM installed without other package changes. PLANK Host
and PAM broker are active. PCoIP, Xorg, and all 29 recorded display/remote-access
configuration hashes were preserved. Boot-time display preparation remains
disabled; the existing display configuration remains the recovery baseline.

A Mac-to-Host TLS 1.3 check verified the certificate and hostname and received
HTTP 200. The live client negotiated one 3840x2160, 60 fps HEVC 10-bit 4:4:4
stream using `nvenc-direct`. Exact identity-GBR hardware profile validation
passed, and Metal rendered the Flame interface. The capture source is explicitly
NvFBC 8-bit/up-converted. This cannot close native ten-bit source or color gates.

## Reported freeze

During the first session, the operator reported responsive interaction followed
by a freeze while importing a QuickTime and trying to play it. The client process,
Flame process, Xorg, and Host service remained running; the Host service reported
zero restarts. No recent kernel GPU/OOM fault or core dump was found in the
checked interval, and no new Mac client crash report was found.

The retained logs show an encoder target change from 50 to 22 Mbps at 13:56:30
UTC, Host video-queue replacements and repeated client IDR requests around
13:56:59-13:57:02 UTC, a toolbar-requested disconnect at 13:57:36 UTC, and a new
session at 13:57:48 UTC. These are correlations, not a proven cause. The last
pre-disconnect statistics interval reported 58.97/58.97/58.91 fps for network,
decode, and render. A later interval after reconnect reported 60.01/60.01/59.92 fps.
Aggregate statistics cannot establish what the picture showed during the freeze.

Retest the same import/play workflow with fixed settings and preserve logs at
both ends before changing encoder, transport, or display behavior. A repeatable
failure is needed to localize capture, encoding, delivery, decoding, or presentation.
The operator then retried the same QuickTime and reported normal playback after
reconnect. The freeze has not been reproduced. No crash fix or stability pass
is claimed.

## Remaining gates

- Reproduce and resolve the reported picture freeze; qualify sustained sessions.
- Native 10-bit capture through the deployed adapter and physical output precision.
- Sustained identity-GBR color checks and two physical 4K outputs.
- Wacom and ordered Flame shortcut tests through the full path.
- WAN, assigned-host access, exclusive-seat, recovery, and signed distribution.

Preserve the existing remote-access session while console recovery is deferred.
Additional Teraguchi transport development waits for the host gates. Windows
work follows the Mac production gate. Private machine inventory, logs, captures,
and commands stay in the private audit store outside Git.
