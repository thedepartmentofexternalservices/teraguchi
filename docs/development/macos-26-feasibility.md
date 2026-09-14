# macOS 26 client feasibility

Reviewed 2026-09-14. **Proceed to a bounded compatibility build; runtime support
is not proved.** The inspected client has explicit macOS 27 build and launch
restrictions, but this review found no macOS 27-only API requirement in its
active Apple rendering path. A replacement renderer or transport is not
indicated by the evidence so far.

Reviewed Teraguchi root `6397a50c032415947dd5bcdee2cc8438c1996a44`, derived from
PLANK `d40f5587aea130cd967a426da60026859e820994`, with client
`c032da3ae0d7e816a7a6f9bb9a51dd489d4d369c`. Only the pinned client submodule was
initialized for this review. No product build, app launch, hardware test, host
connection, OS/toolchain upgrade, or transport change was performed.

## Explicit compatibility blockers

- [Client dependency bootstrap](../../scripts/build/bootstrap-macos-client-deps.sh)
  sets `MACOSX_DEPLOYMENT_TARGET=27.0`, requires SDK 27, and passes deployment
  target 27 to CMake. Rebuilding only the application would retain incompatible
  private libraries.
- [Client build](../../scripts/build/build-macos-client.sh) independently sets
  target 27, rejects other SDK versions, and supplies target 27 to qmake.
  Cargo is invoked by the client project and inherits this environment.
- The pinned client's
  [qmake project](https://github.com/instinctual/plank-client/blob/c032da3ae0d7e816a7a6f9bb9a51dd489d4d369c/app/app.pro#L604)
  assigns target 27. Its
  [Info.plist](https://github.com/instinctual/plank-client/blob/c032da3ae0d7e816a7a6f9bb9a51dd489d4d369c/app/Info.plist#L19)
  separately requires 27. Updating root scripts alone is insufficient.
- [Hosted builds](../../.github/workflows/build.yml) and
  [CI bootstrap](../../scripts/ci/bootstrap.sh) require both macOS 27 and SDK
  27 for Mac jobs. Separate client compatibility policy from the Mac Host's
  existing requirements; do not lower every Mac guard globally.
- [Client packaging](../../scripts/package/build-macos-client-dmg.sh) builds
  its icon helper for 27 and labels packages `macos-27`. The existing dependency
  closure/signature checks do not verify every Mach-O's minimum OS version.
  A compatibility package needs both checks.

The separate [Mac transport helper](../../scripts/build/build-macos-transport.sh)
also requires 27, but the client build invokes Cargo directly through qmake.
It is not necessary to weaken the Mac Host/helper policy to evaluate the client.

## Evidence supporting a compatibility build

The active Mac project compiles `vt_base.mm` and `vt_metal.mm`. The retained
`vt_avsamplelayer.mm` is not in that build, so its old interfaces are not current
client blockers. The active renderer uses VideoToolbox, CoreVideo, CoreGraphics,
CAMetalLayer, and Metal vertex/fragment shaders.

A syntax-only Objective-C++ probe referencing the renderer's selected Apple
APIs compiled successfully against the locally selected SDK 15.2, targeting
15.2, with unguarded-availability diagnostics treated as errors. It covered
all twelve 8/10-bit bi-planar pixel-format constants in the renderer, P410
texture mapping, `BGR10A2Unorm`, EDR/drawable controls, device selection, runtime
shader-library creation, and display-mode declarations. The probe has no
`main`; it was not linked or run. This is declaration-availability evidence,
not a compilation of the client or a decoder/display qualification.

- [Qt 6.10's platform documentation](https://doc.qt.io/qt-6.10/macos.html)
  explicitly includes macOS 26. It distinguishes the SDK used to build from
  the minimum OS on which a binary can run.
- [SDL 3.4.2's source documentation](https://github.com/libsdl-org/SDL/blob/release-3.4.2/docs/README-macos.md)
  requires a much older SDK baseline than 27.
- [Rust 1.89's target documentation](https://github.com/rust-lang/rust/blob/1.89.0/src/doc/rustc/src/platform-support/apple-darwin.md)
  supports Apple Silicon from macOS 11 and honors `MACOSX_DEPLOYMENT_TARGET`.
  The client need not replace the native Rust transport to target 26.
- The exact [FFmpeg 9.0.1 archive](https://ffmpeg.org/releases/ffmpeg-9.0.1.tar.xz)
  matched the bootstrap SHA-256
  `cf38e0e28c7e5605942c4a77755349b0145804a397af37eb1fb4c77cb237f635`.
  Its VideoToolbox sources expose 4:4:4 10-bit P410 through feature checks;
  no 27-only requirement was found in the inspected decode/mapping files.
  PLANK's required identity-GBR patch passes a forward dry run against that
  source and must be preserved in a compatibility build.

Other native dependencies and the complete Rust dependency graph have not been
rebuilt or exhaustively audited. Their bundled binaries still require minimum-OS,
linkage, and runtime verification. Keep pinned versions unless a concrete build
failure requires a separately reviewed change.

## Hardware-decode evidence needs correction

The [current decode probe](../../tests/video/macos-videotoolbox-decode.mm#L31)
comments that pinned FFmpeg requires hardware for H.264/HEVC. In the verified
FFmpeg 9.0.1 source, `videotoolbox_decoder_config_create` instead selects
`EnableHardwareAcceleratedVideoDecoder` for HEVC. PLANK's identity-GBR patch
only adds pixel-format cases; it does not change this decoder specification.

Apple distinguishes
[enabling hardware when available](https://developer.apple.com/documentation/VideoToolbox/kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder)
from [requiring it and failing otherwise](https://developer.apple.com/documentation/VideoToolbox/kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder).
The probe checks for `AV_PIX_FMT_VIDEOTOOLBOX` output but does not read the
session's `UsingHardwareAcceleratedVideoDecoder` property. VideoToolbox-backed
frames alone therefore do not prove the HEVC decoder used hardware.

The original Phase 0 Mac probe likewise accepts a `videotoolbox_vld` log marker
without session attestation. Its frame-count, format, throughput, and overlap
observations remain useful, but the strict `MAC-01`/`MAC-02` hardware passes
must be reopened pending explicit verification. This finding does not establish
that any previous run used software, nor negate unrelated host encode results.

Before accepting a Mac 26 result, require hardware in the decode session and
record `UsingHardwareAcceleratedVideoDecoder=true` for that session. Exercise
a rejected/unavailable-hardware case and ensure the qualification fails. Keep
this distinct from PLANK's separate application-level software fallback, which
also cannot satisfy Teraguchi's hardware-only release contract.

## Next implementation slice

1. Prepare a dedicated client compatibility branch. The root and a maintained
   client fork both need changes; commit client changes before its parent pin.
   Preserve the original upstream references and keep the Mac Host untouched.
2. Establish one client deployment-target setting and propagate it through
   dependency bootstrap, CMake, qmake, Cargo, Info.plist, and package metadata.
   Use separate dependency/build directories keyed by target and SDK so no
   library built for 27 is reused accidentally.
3. Add a package gate checking the minimum OS of the executable, every bundled
   framework/dylib/plugin, and its dependency closure. Verify architecture and
   retain the signing/notarization gates. Do not edit a released app's plist
   or signatures to bypass its minimum version.
4. Correct the hardware-decode proof before running qualification. Preserve
   PLANK's exact HEVC identity-GBR profile and patch. Measure one and two moving
   4K60 streams, hardware status, range/matrix, and output precision separately.
5. Once host gates permit an agreed live session, qualify Metal presentation,
   selected physical displays, TLS 1.3, audio, keyboard, reconnect, and Mac pen
   behavior. The Mac pen path is separately unfinished; changing the OS target
   does not supply it. Windows remains after the Mac production gate.

## Local toolchain and limits

The review Mac runs macOS 26.5.2. Its selected developer directory is Command
Line Tools with SDK 15.2; no Xcode app was found in the standard Applications
location. This setup does not meet the inherited SDK 27 build checks.

For a 26 compatibility build, use a pinned Xcode 26 toolchain supported by the
existing OS. Apple's [current matrix](https://developer.apple.com/xcode/system-requirements)
lists Xcode 26.6 with SDK 26.5 on macOS 26.2 or newer in the 26 series. Select
that developer directory per build, without changing the global selection.
An SDK newer than the deployment target can also work with correctly guarded
APIs; SDK version and runtime minimum are separate decisions.

Start qualification on the available 26.5.2 environment. A build targeting
26.0 is not proof of support for every 26.x release; test the oldest advertised
version before broadening the support statement. This review authorizes no
support claim and closes no hardware or production gate.
