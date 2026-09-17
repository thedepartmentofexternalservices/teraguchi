# Teraguchi scope and next steps

Teraguchi is DXS's Flame-focused derivative of
[PLANK](https://github.com/instinctual/plank), created by
[Alan Latteri](https://github.com/alatteri). Preserve the shared foundation and
contribute general improvements upstream. Keep Teraguchi's interface, onboarding,
release claims, and studio integration clearly owned by DXS.

## Current state

The current candidate is `codex/teraguchi-integration`, tracked in
[consolidation PR #7](https://github.com/thedepartmentofexternalservices/teraguchi/pull/7).
It combines the retained Teraguchi product lineage with Alan's frozen PLANK root
`413594743d110d6a9965e639068f132379e82ab2` and Client
`95060dee8fa63e0da98dfa83e7ddd8185731a837`.

The candidate restores the fuller workstation interface alongside the hardened
clipboard stack. macOS 26 build policy, strict hardware/video admission,
assigned-workstation trust, onboarding, native pen/keyboard handling, one/two
selected outputs, and support tooling are implemented. The arm64 Mac client
build and isolated regression suites pass locally. Implementation and synthetic
tests do not establish production acceptance; see [HANDOFF](../HANDOFF.md) for
exact source pins, results, and limitations.

The existing [Phase 0 project](https://github.com/thedepartmentofexternalservices/teraguchi-sunshine-kyber)
retains earlier requirements, probes, and redacted evidence. Its raw results and
all private operational evidence must remain outside public Git.

Machine testing is paused. Main, prior source branches, and the installed pilot
remain preserved. Do not change occupied Flame workstations or their remote-access
configuration. Host, physical input/video, WAN, and stability gates remain open.

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
and fallback policy. Teraguchi implements stricter admission checks, but those checks do not prove
the physical end-to-end path meets the target. Windows client work starts only
after the Mac production gate and a separate feasibility decision.

## Next work

1. Finish platform build validation and review the single integration candidate.
   The eight clipboard review findings now have code fixes and isolated
   regressions; obtain review and paired-system acceptance before promotion.
   Native Quit has merged upstream. Keep the focused clipboard stack separate. See the [branch guide and forward plan](development/teraguchi-forward-plan.md).
2. Complete Flame UI side selection across the client, protocol, Host topology,
   persistence, and restoration. The existing boot helper is only part of this.
3. Arrange a scoped operator qualification session with recovery access. Exercise
   picture precision, hardware decode, pen/tablet margins, one/two outputs,
   hardened clipboard, reconnect, native Quit and Command-Q, and audio against
   the exact candidate. Preserve the immediate native cursor behavior; the
   earlier host-mapped cursor was rejected for lag.
4. Complete signed/notarized distribution and clean-install/rollback acceptance,
   then qualify representative WAN routes and the inherited stability gates.
   macOS 26 support remains a Teraguchi qualification claim to earn independently
   of upstream macOS 27 results.

## Collaboration and public information

Keep changes small and retain Alan's history and attribution. Offer shared fixes
and tests upstream; a collaboration arrangement is still to be discussed with
Alan. Do not describe him as responsible for Teraguchi-specific support.

Keep deployment inventories, artist identities, credentials, and raw captures
outside this public repository. Follow the inherited
[private-information policy](security/private-information.md). Sanitized tests,
reproducible examples, and component attribution belong in the public project.
