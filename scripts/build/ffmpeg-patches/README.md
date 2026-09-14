# Private VideoToolbox hardware policy

The macOS Client dependency build applies
`0002-videotoolbox-require-and-attest-hardware.patch` after the unchanged client
identity-GBR patch to pinned FFmpeg9.0.1. Both build entrypoints verify the patch
hash and reverse dry run. This does not change the Linux Host or its FFmpeg.

HEVC session creation now requests `RequireHardwareAcceleratedVideoDecoder`.
H.264 already requests it. Successful HEVC/H.264 session creation additionally
requires `UsingHardwareAcceleratedVideoDecoder` to be readable and true;
otherwise the session is stopped and hardware initialization fails.

The private exported `av_videotoolbox_is_hardware_accelerated` accessor queries
the current session and returns1 for hardware,0 for software, or a negative
error when no session exists or its Boolean property cannot be read. The
qualification executable requires this accessor and checks it after every
received hardware frame. An unpatched library cannot satisfy that link.

The explicit software qualification mode remains available for comparison.
Application-level same-format software fallback is a separate inherited
behavior and cannot satisfy Teraguchi's hardware-only release gate.
