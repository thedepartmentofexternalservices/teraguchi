# Teraguchi

Teraguchi is a Flame-focused derivative of [PLANK](https://github.com/instinctual/plank),
created by [Alan Latteri](https://github.com/alatteri).

Alan's work on PLANK provides the foundation for this project, including its
remote-workstation architecture, video pipeline, transport, and qualification
tooling. The Department of External Services (DXS) maintains the Teraguchi fork
and its planned artist experience, studio integration, and additional platform
work. We aim to contribute reusable improvements and testing back to PLANK.

See [Attribution](ATTRIBUTION.md) for upstream credits and component licensing,
and [Teraguchi scope and next steps](docs/teraguchi.md) for this fork's status.
Teraguchi-specific support belongs to DXS; this fork does not imply an upstream
support commitment or endorsement.

## Teraguchi status

The current development candidate is `codex/teraguchi-integration`, tracked in
[consolidation PR #7](https://github.com/thedepartmentofexternalservices/teraguchi/pull/7).
It combines the existing artist interface, assigned-workstation onboarding and
trust, strict video policy, Mac input, and clipboard repairs with Alan's frozen
PLANK 1.0.120 source. There is no qualified Teraguchi production release yet.

The Apple Silicon client compiles locally for macOS 26, and its isolated product
regression suites pass. Upstream macOS 27 builds remain a separate contract.
Native ten-bit capture, exact-format hardware decode and presentation, physical
Mac pen input, sustained dual-display operation, and end-to-end Flame behavior
still require exact-candidate qualification. Machine testing is paused.

See [current provenance and validation](HANDOFF.md), the
[forward plan and branch guide](docs/development/teraguchi-forward-plan.md), and
the [scope document](docs/teraguchi.md). Main and the installed pilot have not
been replaced by this development candidate.

## PLANK upstream overview

The following overview, platform descriptions, build instructions, and licensing
notes are retained from upstream. They describe the PLANK baseline; upstream
build or qualification results are not Teraguchi release claims.

This is a fork of Sunshine/Moonlight with deep changes relevant to secure VFX Remote Desktop workflows. 

## Status:
Linux Host/Client stable.
macOS Host is beta quality.
macOS Client is alpha.

## Hardware:
Ideal hardware for Ubuntu client would be an Intel based NUC generation 12 or higher, or an Intel N150 or higher mini-pc.  These support hardware HEVC 10bit 4:4:4 decode.

## INSTALL:
RockyLinux 9.7 Host:
dnf install ./plank-host-X.XXXX.1.el9.x86_64.rpm

## Ubuntu 26.04 Client:
apt-get install ./plank-client_1.0.89_amd64.deb


## Uninstall:
RockyLinux 9.7 Host:
dnf remove plank-host


## Ubuntu 26.04 Client:
apt-get remove plank-client


## macOS 27 Host:
sudo "/Applications/PLANK Host.app/Contents/Resources/uninstall.sh"


## Configuration:
RockyLinux 9.7 Host: /etc/plank/host.conf
[display] - If you are going to work hybrid, both in office with a physical display, and also remotely, leave startup_layout = physical.  If you are going to work purely headless, startup_layout = virtual.

Ubuntu 26.04 Client: /etc/plank/client.conf

When creating a bookmark to macOS Host on the Client, make sure to chose “macOS” in the Capture field. It defaults to NvFBC which is for Linux.

## Connectivity:
The current workflow expects a “direct connection”. There is no “broker”.  You are expected to provide your own VPN/LAN/WAN/Port Forward connection from the Client to Host.
The default is both TCP/UDP port 28989.

macOS Host has NOT been tested with Flame on Undies.  Photoshop and Pixelmator both successfully receive Wacom pressure with the PTH-8x0 series, without the need for Wacom driver on the macOS host, when connecting from Ubuntu Client.





PLANK is a low-latency remote-workstation system with Linux and macOS Hosts
and Clients. This repository builds independently of private infrastructure.

The project is in late integration and production hardening. The supported
Linux baseline is currently a Rocky Linux 9.7 host with NVIDIA graphics and an
Ubuntu 26.04 client. Hardware-sensitive behavior—including exact-format video,
Wacom input, display topology, packet-loss recovery, and session takeover—must
pass the repository's qualification gates before release.

## Repository map

| Path | Purpose |
| --- | --- |
| `apps/host/linux/` | Host capture, encoding, authentication, display, and input services |
| `apps/host/macos/` | Native macOS capture, VideoToolbox encoding and session services |
| `apps/client/` | Client decoding, presentation, input, toolbar, and connection UI |
| `protocol/` | PLANK-owned transport, schemas, feature negotiation, and protocol documentation |
| `packaging/<product>/<os>/` | Product/platform installation integration |
| `artifacts/packages/` | Ignored packages grouped by version and operating system |
| `tests/` | Focused automated tests grouped by subsystem |
| `probes/` | Hardware and network qualification tools |
| `scripts/` | Reproducible build, packaging, and validation entry points |
| `docs/` | Architecture, security, build, and qualification documentation |
| `third_party/` | Pinned external source required by PLANK components |

The Linux Host and shared cross-platform Client retain their upstream Git
histories and license notices as submodules. macOS targets macOS 27 and Apple
Silicon; its qualification gates are separate from Linux. Windows is future
work, not a currently supported product. See the
[platform matrix](docs/development/platforms.md).

## Start here

- [Documentation index](docs/README.md) and [contributor guide](CONTRIBUTING.md).
- [Building a fork from source](docs/development/build/from-source.md), including macOS signing.
- [Package catalog layout](artifacts/README.md).
- [`docs/development/acceptance-criteria.md`](docs/development/acceptance-criteria.md) defines the
  current Linux product acceptance gates.
- [`protocol/`](protocol/) and the focused documents under [`docs/`](docs/)
  define the current subsystem contracts and architecture.
- [`HANDOFF.md`](HANDOFF.md) records the exact current source, artifacts,
  builder state, completed validation, and next test.
- [`docs/development/build/release-build-runbook.md`](docs/development/build/release-build-runbook.md) is mandatory
  reading before producing a candidate package.
- [`docs/development/build/builder-vm-bootstrap.md`](docs/development/build/builder-vm-bootstrap.md) defines the
  canonical Host and Client builder environments.
- [`AGENTS.md`](AGENTS.md) contains repository-specific engineering rules.

Host RPMs and Client DEBs are built on separate, dedicated builder VMs. Do not
infer build paths or dependencies from an arbitrary checkout; use the path
contract and pinned inputs documented in the builder bootstrap and release
runbook.

## Qualification

The repository qualification build and automated test suite is:

```bash
source ~/.config/plank-builder/paths.env
qualification_build="$PLANK_WORK_ROOT/qualification"
cmake -S . -B "$qualification_build" -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build "$qualification_build" --parallel
ctest --test-dir "$qualification_build" --output-on-failure
```

Hardware tests and package acceptance require the additional procedures and
qualified machines documented in the release runbook.

## Licensing

PLANK contains components with different upstream histories and licenses.
Preserve the license and attribution files in each maintained fork and vendored
dependency. The PLANK transport boundary is AGPL-3.0-or-later.
