# Teraguchi integration handoff

## Current candidate

`codex/teraguchi-integration` remains the single development line, reviewed in
[root PR #7](https://github.com/thedepartmentofexternalservices/teraguchi/pull/7)
and [Client PR #4](https://github.com/thedepartmentofexternalservices/teraguchi-client/pull/4).
It preserves the full Teraguchi product lineage and Alan's upstream history.
Main, recovery branches and the installed pilot remain preserved. Machine
qualification and installation are paused; this is an unqualified candidate.

The September 17 clipboard follow-up implements the four Client and four Host
findings from Alan's changes-requested reviews. See the
[finding-to-test record](docs/development/clipboard-review-followup.md).
Passing compilation before these fixes did not close those findings. The PRs
remain under review; implementation and regression evidence are not approval.

## Exact source provenance

| Component | Commit |
|---|---|
| Root production snapshot (before fixture-only follow-up) | `be4007d248c296bf8c3d0061d007925844745a90` |
| Client | `38b9e3fa610ce6ea5fd45ec7a259ff1e0afc3dce` |
| Client common-c | `390774c58043d6af6d516251afcaab5aa4ed6028` |
| Client qmdnsengine | `b7a5a9f225d5e14b39f9fd1f905c4f505cf2ee99` |
| Linux Host | `950acf5f493a264ae846931502914a316f2e81f5` |
| Host common-c | `2ad9d89a41428601c5f36001a5a7c9ab5359a274` |
| Kyber/Kymux | `912ece5c64787997f978673ca60d313898a3548c` |

Host `950acf5f` changes only the test fixture: it observes the completed PRIMARY
claim before stealing ownership. Production Host code is identical to the
passing `77b0b62a` snapshot; current PR checks validate the corrected fixture.

The focused upstream parent is [PLANK PR #3](https://github.com/instinctual/plank/pull/3).
It has the same Host and clipboard fixes, with Client `139add9b` instead of the
Teraguchi product Client. The earlier parent PR #2 is closed. Native Quit
[Client PR #1](https://github.com/instinctual/plank-client/pull/1) was approved
and merged upstream; that approval did not establish native runtime acceptance.

The local Mac dependency profile remains Qt 6.10.2, Rust 1.89.0, SDK 26.5 and
macOS deployment target 26.0. Nested gitlinks retain exact dependency provenance.
Linux dependencies are prepared only on the authorized disposable/canonical
builders, not on this Mac or hardware-test workstations.

## Validation of this update

- Full arm64 Mac Client build passes with the component pins above. Its native
  suites report 20 topology, 24 toolbar, 7 desktop/reconnect and 19 clipboard
  results. Clipboard tests use a private named NSPasteboard.
- The reconnect test exercises the production SDL timer and clipboard bridge
  across stop/restart with focus unchanged. A source guard checks the Session
  teardown and success-only restart call sites. It is not a live network,
  renderer, PAM or desktop-handoff acceptance test.
- The production Host backend passes nine real-X11 regressions against Xvfb on
  a disposable Rocky 9.7 builder. Four negative controls reproduce the reviewed
  implementation's failures. [Run and logs](https://github.com/thedepartmentofexternalservices/teraguchi/actions/runs/35201206844).
- Fresh hosted platform builds are required for the updated parent heads.
  Consult the current PR checks for final conclusions; dispatch or partial job
  success is not an overall pass. No signing or installation was requested.

Earlier unchanged product suites passed on the preceding integration snapshot:
strict video/decode contracts, native pen and keyboard, display binding,
assignment/provider trust, signed setup, TLS trust, support, release verification,
workstation UI, native Quit bridge, root CTest and CI policy checks. Those results
remain historical evidence, not a substitute for the new review regressions or
physical acceptance. Private logs and build receipts remain outside Git.

## Preserved sources and evidence boundaries

Original main `04edc2d`, working Client `2b2983e6` and working Host `434b8def`
remain unchanged. Product root `22d1565`, product Client `94f3bf49`, and the
prior clipboard safety line remain retained. Root recovery branches use the
`codex/pre-integration-` prefix.

Earlier pilot observations and synthetic tests do not qualify this candidate.
Keep the immediate native pen cursor; the host-mapped candidate was rejected
for visible lag. Flame tablet-margin alignment remains unresolved. Installed
binary receipts and recovery procedures remain private.

## Next work

Complete review and the current hosted checks, then continue Flame UI side
selection through Client, protocol, Host topology, persistence and restoration.
Arrange a scoped operator session only when machine work resumes. Verify
clipboard in both directions, local A–B–A, disconnect into a different Host,
large text, active desktop handoff/reconnect without focus changes, picture,
pen/tablet margins, one/two outputs, native Quit, audio and recovery.

The Quit bridge handles any Qt Quit event and adds no Command-Q binding; it
cannot distinguish menu from shortcut-origin Quit. Native session testing must
settle Command-Q behavior before claiming remote-keyboard safety.

Signed/notarized distribution, clean install/rollback, native ten-bit picture,
sustained physical input, WAN and stability gates remain open. Main must not be
promoted solely because source tests or hosted compilation pass. macOS 26
support remains Teraguchi's separate qualification claim to earn.
