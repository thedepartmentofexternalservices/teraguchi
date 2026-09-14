# VideoToolbox hardware and exact-format qualification

The private FFmpeg patch requires hardware for HEVC/H.264 VideoToolbox sessions
and reads UsingHardwareAcceleratedVideoDecoder from the created session. Missing,
unreadable, false, or non-Boolean values fail the hardware path. The existing
application-level exact-format software fallback remains available; it cannot
satisfy Teraguchi's hardware gate. This slice uses the client target policy already
on main (26.0 by default, with explicit 27.0 supported). Its diff changes no Quit,
deployment-target, Host, or transport behavior.

## Run the checks

Read the build runbook before preparing the pinned dependencies. Both bootstrap
and application preflight verify the hardware patch checksum and reverse dry run.
An unpatched library cannot link the probe's private hardware-query accessor.

```bash
bash scripts/test/check-decode-contract.sh "$PLANK_WORK_ROOT/decode-contract"
bash scripts/test/build-macos-decode-probe.sh "$PLANK_WORK_ROOT/decode-probe"
python3 scripts/test/check-macos-decode-probe.py \
  "$PLANK_WORK_ROOT/decode-probe/macos-videotoolbox-decode" \
  "$PLANK_WORK_ROOT/decode-cases"
```

The portable checker exercises 24 assertions, including false/unreadable hardware
status and all expected metadata fields. Mac CI compiles the probe and runs 15
software/argument cases against the pinned client's embedded fixtures. On the
qualified M2 Ultra, add `--hardware` for four hardware cases, including its known
H.264 4:4:4 10-bit hardware rejection. This hardware matrix is model-specific.
All 19 cases pass locally. An intentional rejection must return the documented
error code/reason, not crash or time out.

The probe now requires an expected profile, dimensions, and frame count:

```bash
"$PLANK_WORK_ROOT/decode-probe/macos-videotoolbox-decode" hardware \
  "$FIXTURE" hevc-rext10-444-identity 3840 2160 1800
```

Profiles are `hevc-rext10-444-identity`, `hevc-rext10-444-bt709-full`, and
`h264-44410-identity`. Each frame must match codec, profile, all component depths,
chroma, dimensions, matrix, and range; hardware mode also requires a hardware
surface and a true session property. Extra/missing frames and format changes fail.
Software mode is labeled explicitly and never reports hardware attestation.
The old format-reporting-only invocation is deliberately rejected.

## Sustained identity-GBR result

On the Mac below, the stricter probe accepted every frame of a synthetic 4K
HEVC RExt 4:4:4 10-bit identity-GBR sequence: 1,800 frames at 120.007 fps single,
and 125.888 / 125.559 fps for two overlapping hardware sessions. Output was
p410le, matrix 0, full range, with hardware attestation on every frame.

Reproduce the synthetic source with an available FFmpeg/libx265 encoder:

```bash
bash scripts/test/make-hevc-identity-fixture.sh "$NEW_PRIVATE_FIXTURE_DIRECTORY"
```

The script records the encoder version and fixture checksum. It generates 120
moving ten-bit RGB ramp frames, then repeats that complete sequence 15 times.
This is 30 seconds of stream content decoded faster than real time, not a
long-duration soak. It qualifies this sample's format/decode capacity, not native
Host capture, pixel fidelity, physical 10-bit output, or dual-display rendering.
No desktop capture or host connection occurs. Raw output remains outside Git.

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
