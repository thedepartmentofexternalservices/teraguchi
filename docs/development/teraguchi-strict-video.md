# Teraguchi strict video admission

This change makes Teraguchi's required video path an admission rule in new Mac
client builds. It does not qualify native host capture, physical display output,
or a production release. PLANK's capture and decode work remains the foundation;
this is a bounded Teraguchi policy on top of it.

## Behavior

The root `scripts/build/build-macos-client.sh` enables qmake
`CONFIG+=teraguchi-strict-video`. That configuration defines
`TERAGUCHI_STRICT_VIDEO` in the client and is available only on Mac builds.
Direct upstream builds without that configuration retain PLANK's exact-format
hardware-then-software policy. No protocol or host configuration changes are
required by this patch.

A strict client requires all of the following:

- The bookmark selects **Native X11/XShm 10-bit** capture and **HEVC 10-bit
  4:4:4 NVENC** encoding. Existing bookmarks are not rewritten. NvFBC and
  software-encoder bookmarks fail with an explanation before connecting.
- The host advertises HEVC RExt 4:4:4 10-bit and identity-GBR support. Identity
  color and full range are explicit; color environment overrides are rejected.
- Decoder probes, initial creation and reset use `ExactHardwareOnly`. A backend
  that reports software decoding cannot satisfy that request, even if its
  initializer reports success. The pinned FFmpeg patch requires a real hardware
  VideoToolbox session and checks the session property.
- Stream setup matches the requested format, dimensions and frame rate.
- Each decoded frame, before presentation, has the required codec/profile,
  dimensions, full range, identity matrix, VideoToolbox surface and 10-bit 4:4:4
  storage description. The actual VideoToolbox session must still attest that
  hardware decoding is active.

A frame mismatch ends the session. The failure is latched independently of the
SDL event queue, so reconnect event filtering or a failed wakeup cannot clear
it. Ordinary session cleanup remains responsible for stopping transport and
releasing resources. This patch does not change the existing active-seat policy.

## Native capture already in PLANK

Source review used Linux host commit
`9329784ac41f50cbec0c9d76badfd22227ec5e5f`:

| Existing implementation | Boundary checked in source |
| --- | --- |
| `src/platform/linux/x11grab.cpp`, `native10_attr_t` | LSB-first depth-30 root and matching XComposite overlay, RGB10 masks, MIT-SHM, and returned image depth/size. A transparent keepalive window prevents fullscreen unredirect. |
| `src/platform/linux/misc.cpp`, capture selection | A requested `x11-native10` source fails if unavailable; it does not select NvFBC instead. |
| `src/platform/linux/cuda.cpp`, native NVENC conversion | Packed RGB10 input is uploaded and converted to 10-bit 4:4:4 identity planes. The encoder input contract rejects another depth or color mapping. |
| `src/session_stream.cpp`, native stream admission | Native NVENC requires the accepted HEVC 10-bit 4:4:4 identity mode. |

This establishes an existing implementation to qualify. A source flag, depth-30
desktop, or 10-bit encoded stream alone does not prove that a live Flame image
retained more than 8-bit precision through capture, encoding and presentation.
NvFBC's 8-bit source cannot satisfy this gate through up-conversion.

## Repeatable checks

Use the prepared dependency variables from the Mac build runbook and keep
outputs in a private directory outside Git:

```bash
bash scripts/test/check-strict-video.sh "$PLANK_WORK_ROOT/strict-video"
bash scripts/test/build-macos-decode-probe.sh "$PLANK_WORK_ROOT/decode-probe"
python3 scripts/test/check-macos-decode-probe.py \
  "$PLANK_WORK_ROOT/decode-probe/macos-videotoolbox-decode" \
  "$PLANK_WORK_ROOT/decode-cases"
```

On an authorized hardware-capable Mac, add `--hardware` to the last command.
The decode probe calls the same frame predicate as the live client for hardware
HEVC identity fixtures. Hosted CI runs the software fixture matrix and policy
tests; it does not claim hardware qualification.

The policy tests exercise both build modes, unavailable hardware between probe
and reset, a backend ignoring the hardware-only request, and incompatible
capture/profile/stream parameters. A build without the strict define must fail
the strict negative control. Frame tests use synthetic FFmpeg metadata to test
wrong depth, chroma, matrix, range, dimensions, missing context/surface and
failed or unknown hardware status. Those tests are not hardware attestation.

## Local results, 2026-09-14

Test client: Mac Studio, Apple M2 Ultra, 64 GB, macOS 26.5.2 (25F84), SDK 26.5.
The build used deployment target 26.0, Qt 6.10.2, Rust 1.89.0 and the pinned
FFmpeg 9.0.1 with both required patches. Dependencies were rebuilt using the
current bootstrap recipe in a fresh dependency directory.

- Full arm64 Mac client build and offscreen `--version`: pass,
  `1.0.103-strict-video-admission`. The application was not installed.
- Policy tests: 30 assertions in each of the strict and upstream modes, plus
  the missing-strict-define negative control. Frame metadata: 24 assertions.
- Decode probe: all 19 cases pass, including real hardware identity decoding
  and the deliberate hardware H.264 rejection. The sandbox denied hardware
  access; hardware results came from the authorized run outside that sandbox.
- Existing native Quit regressions: all eight scenarios and the negative
  control pass.
- Moving synthetic HEVC identity fixture: 1,800 frames at 3840x2160, containing
  30 seconds at 60 fps. Single decode: 124.730 fps. Concurrent decodes: 132.300
  and 132.207 fps. All frames passed the shared product predicate with hardware
  attestation, P410 10-bit 4:4:4 storage, identity matrix and full range.

Decode throughput excludes capture, transport, presentation and physical
displays. It is not latency or dual-display session qualification. No host was
modified or tested with this candidate. Interactive rejection, decoder reset,
reconnect cleanup and native source precision remain live acceptance work.

## Remaining acceptance

1. Build the exact candidate and retain its root/client/dependency provenance.
   Build success is separate from signed packaging and interactive acceptance.
2. With verified recovery access, qualify native capture on the authorized test
   Flame. Use patterns that distinguish native 10-bit values from 8-bit
   up-conversion, including fullscreen and moving content at the target rate.
3. Test startup, decoder reset and reconnect with the installed strict candidate,
   including deliberately unavailable hardware and changed stream metadata.
   Verify a clear error, session cleanup and the ability to reconnect afterward.
4. Verify the actual Mac render surface and one/two selected physical 4K
   displays separately. This patch does not implement or qualify Mac dual-display
   presentation, color accuracy or display-count negotiation.
5. Complete Flame shortcuts, native Mac Wacom, audio, WAN and recovery gates
   before a production claim or Windows work.

Do not replace a working installed client with this candidate merely to pass a
build check. Switching a bookmark to native capture is a separate live test and
must respect the host recovery gate.
