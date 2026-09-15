# Documentation

- [User documentation](user/): bookmark behavior and product configuration.
- [Architecture](architecture/): media, input, authentication and lifecycle.
- [Development](development/): platform matrix, acceptance, build runbooks and plans.
  [GitHub-hosted builds](development/build/github-builds.md) covers CI scope,
  artifacts and signing boundaries.
  [Teraguchi strict video](development/teraguchi-strict-video.md) describes the
  Mac admission policy, native capture source review and remaining live gates.
  [Mac pen and Flame shortcuts](development/teraguchi-macos-input.md) covers the
  client bridge, local diagnostic, host pressure limit and keyboard gaps.
  [Mac keyboard capture](development/teraguchi-macos-keyboard.md) covers owned-key
  cleanup, reserved chords, local test evidence and remaining host requirements.
  [Linux input preparation](development/teraguchi-linux-input-preparation.md) covers
  the uninstalled pressure/keypad dependency candidate and draft modifier checks.
  [Workstation picker preview](development/teraguchi-workstation-ui.md) covers
  the first P3 Qt interface, offline interaction tests and live-adapter boundary.
  [Optional studio power](development/teraguchi-studio-power.md) covers managed
  power-on controls, status uncertainty and the private service implementation order.
- [Security](security/): threat models and security-focused contracts.
  [Private information policy](security/private-information.md) defines the
  boundary between public development material and private operational notes.
- [Hardware](hardware/): qualified hardware and display data.
- [Releases](releases/): release notes.
- [Reference](reference/): retained technical reference material.

Shared wire contracts live in [protocol](../protocol/). Current work belongs in
[HANDOFF.md](../HANDOFF.md), not a growing chronology in the top-level README.

- [Tailscale shared workstations](development/teraguchi-tailscale-workstations.md):
  local share discovery, native PAM handoff, test evidence, and remaining UI gates.
- [Workstation certificate trust](development/teraguchi-host-trust.md): signed
  node/host bindings, pre-credential TLS checks, rotation and local adversarial tests.
- [Client release verification](development/teraguchi-client-release.md): offline
  package metadata, exact-byte checks and fresh rollback authorization preparation.
- [Guest access policy preparation](development/teraguchi-guest-access-policy.md):
  pinned endpoint inventory, offline sharing draft, certificate trust gap and live cases.
- [P3/P4 implementation order](development/teraguchi-p3-p4.md): current coding
  priorities and the live gates before the WAN pilot.
