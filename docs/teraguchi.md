# Teraguchi scope and next steps

Teraguchi is DXS's Flame-focused derivative of
[PLANK](https://github.com/instinctual/plank), created by
[Alan Latteri](https://github.com/alatteri). Preserve the shared foundation and
contribute general improvements upstream. Keep Teraguchi's interface, onboarding,
release claims, and studio integration clearly owned by DXS.

## Current state

The public fork starts at PLANK root commit
`d40f5587aea130cd967a426da60026859e820994`. Its initial documentation changes
establish attribution and scope. Product source, submodule pins, configuration
paths, application names, package identifiers, and wire behavior remain the
upstream baseline. No Teraguchi package has been built or installed, and no
Teraguchi production qualification is claimed.

The existing [Phase 0 project](https://github.com/thedepartmentofexternalservices/teraguchi-sunshine-kyber)
retains the requirements, probes, and redacted evidence. It is also public.
Its local raw results are ignored and must not be copied into this fork.
This documentation change does not import that repository's history or patches.

The operator has authorized the designated Mac Client and Linux Host for
installation and testing. Preserve existing remote access and display
configuration; the boot-time PLANK display helper stays disabled during this
first qualification. The existing host and hardware gates remain open;
additional Teraguchi transport development waits for those gates. Reading
PLANK's existing transport source does not count as developing a new transport.

## First supported configuration to qualify

- Rocky Linux 9.7, X11, and NVIDIA on the Flame host.
- Apple Silicon client first; macOS 26 compatibility is an evaluation target.
- One or two selected 4K60 displays, qualified separately by hardware class.
- Genuine 10-bit source and HEVC RExt 4:4:4 10-bit with hardware encode/decode.
  Software decoding or a different format cannot silently satisfy this target.
- Flame keyboard behavior and native Mac Wacom pressure, tilt, hover, eraser,
  and buttons verified through the complete client-to-Flame path.
- WAN performance, assigned-workstation access, and exclusive-seat behavior
  verified before production release.

These are Teraguchi targets, not additions to upstream's supported platform
matrix. PLANK currently targets macOS/SDK 27 and has its own profile selection
and fallback policy. Teraguchi's stricter target does not mean the current
inherited implementation already enforces it. Windows client work starts only
after the Mac production gate and a separate feasibility decision.

## Next work

1. Follow the [completed macOS 26 source review](development/macos-26-feasibility.md).
   A bounded compatibility build is recommended; explicit build/launch guards
   and bundled dependency targets need coordinated changes. Client compatibility work is in progress; no runtime support is claimed.
2. Correct hardware-decode attestation before accepting new Mac results. Both
   the PLANK probe and the earlier Phase 0 probe identify VideoToolbox output
   without proving its decoder used hardware. Strict `MAC-01`/`MAC-02` passes
   are reopened; throughput observations remain. PLANK's identity-GBR profile
   also needs its own exact-format decode and presentation evidence.
3. Resume host qualification only with an agreed test session and recovery
   access. Establish a pinned PLANK baseline before changing its runtime.
4. Adapt the existing client interface and onboarding after feasibility is
   established. Keep protocol names and component paths stable while cosmetic
   work is separated from compatibility and behavior changes.

## Collaboration and public information

Keep changes small and retain Alan's history and attribution. Offer shared fixes
and tests upstream; a collaboration arrangement is still to be discussed with
Alan. Do not describe him as responsible for Teraguchi-specific support.

Keep deployment inventories, artist identities, credentials, and raw captures
outside this public repository. Follow the inherited
[private-information policy](security/private-information.md). Sanitized tests,
reproducible examples, and component attribution belong in the public project.
