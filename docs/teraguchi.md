# Teraguchi scope and next steps

Teraguchi is DXS's Flame-focused derivative of
[PLANK](https://github.com/instinctual/plank), created by
[Alan Latteri](https://github.com/alatteri). Preserve the shared foundation and
contribute general improvements upstream. Keep Teraguchi's interface, onboarding,
release claims, and studio integration clearly owned by DXS.

## Current state

The fork retains PLANK's history from root
`d40f5587aea130cd967a426da60026859e820994`. A bounded macOS 26 client adaptation
has now been built, installed, and connected to the authorized Linux Host running
the verified upstream v1.0.103 package. Alan's Host and transport code remain
unchanged. See the [qualification record](development/macos-26-qualification.md)
for exact built pins, hardware-decode evidence, and an unresolved picture freeze.
No Teraguchi production qualification is claimed.

The existing [Phase 0 project](https://github.com/thedepartmentofexternalservices/teraguchi-sunshine-kyber)
retains the requirements, probes, and redacted evidence. Both repositories are
public; raw evidence stays in the appropriate private store and is never published.
The operator authorized this Mac Client and Linux Host for installation/testing.
PLANK-only GDM login/logout now passes on that Host. The operator approved GDM
startup with PCoIP retained, stopped, and disabled; an exercised SSH recovery
procedure is retained privately. Preserve this access baseline and the unchanged
Xorg configuration. Startup after a reboot remains untested. The boot-time PLANK
display helper stays disabled. Additional Teraguchi transport development waits
for the remaining host gates.

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

1. Reproduce and resolve the live picture freeze reported during QuickTime
   import/play. Preserve the working recovery path and collect evidence at both ends.
2. Qualify sustained identity-GBR rendering and color precision. Strict moving
   BT.709 hardware decode now passes on the M2 Ultra; the earlier M5 results still
   need session hardware attestation. Neither result proves physical output depth.
3. Resume genuine ten-bit desktop capture when console recovery is verified.
   Keep the present NvFBC 8-bit source clearly labeled during functional tests.
4. Qualify Wacom, keyboard, dual-display, WAN, and release behavior, then adapt
   the interface and onboarding in separate changes.

## Collaboration and public information

Keep changes small and retain Alan's history and attribution. Offer shared fixes
and tests upstream; a collaboration arrangement is still to be discussed with
Alan. Do not describe him as responsible for Teraguchi-specific support.

Keep deployment inventories, artist identities, credentials, and raw captures
outside this public repository. Follow the inherited
[private-information policy](security/private-information.md). Sanitized tests,
reproducible examples, and component attribution belong in the public project.
