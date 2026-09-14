# Attribution

## PLANK and Alan Latteri

Teraguchi is derived from [PLANK](https://github.com/instinctual/plank), created
by [Alan Latteri](https://github.com/alatteri) and published by
[Instinctual](https://github.com/instinctual).

PLANK supplies the foundation for Teraguchi's remote-workstation stack,
including host/client integration, capture and video processing, transport,
authentication, packaging, and qualification tooling. Alan's engineering and
work on 4:4:4 video, 10-bit precision, and testing are central to this foundation.
Original Git authorship and history are preserved.

The initial Teraguchi fork retains root commit
[`d40f5587aea130cd967a426da60026859e820994`](https://github.com/instinctual/plank/commit/d40f5587aea130cd967a426da60026859e820994)
and its pinned companion repositories.

## Inherited projects and components

PLANK also builds on other contributors' work. Alan's credit does not replace
their authorship or license notices.

- **Sunshine:** host technology maintained in
  [PLANK's Linux Host fork](https://github.com/instinctual/plank-host-linux).
  Its original authorship and license notices remain in `apps/host/linux/`.
- **Moonlight:** client technology maintained in
  [PLANK's Client fork](https://github.com/instinctual/plank-client).
  Its original authorship and license notices remain in `apps/client/`.
- **Kyber-derived components:** retained through
  [PLANK's kymux repository](https://github.com/instinctual/plank-kymux), pinned
  at `third_party/kyber-kymux/`, with their own authorship and license notices.
- **Other dependencies:** the source and build inputs retain their respective
  copyright, license, and attribution files, including vendored components.

The companion paths above are Git submodules. Their notices are in the pinned
repositories even when the local submodules have not been initialized.

## Teraguchi maintenance

The Department of External Services (DXS) maintains Teraguchi's branding,
studio-specific integration, and any platform work it undertakes. Reusable
fixes and tests are intended for contribution back to PLANK where appropriate.
Teraguchi support and release claims are DXS's responsibility. This fork does
not imply an endorsement or support commitment from Alan or other upstream
maintainers.

## Licensing

This attribution file does not replace or relicense any component. Preserve
all existing copyright notices, license texts, and required notices when
modifying or distributing the software.

The retained Host and Client repositories include GPL version 3 license texts.
The PLANK transport crate declares `AGPL-3.0-or-later` in
[`protocol/plank-transport/Cargo.toml`](protocol/plank-transport/Cargo.toml).
Consult each component's source notices and license for its terms; this summary
is not a blanket license grant for every file in the repository.
