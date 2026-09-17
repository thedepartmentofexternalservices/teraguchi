# Teraguchi integration handoff

## Current candidate

`codex/teraguchi-integration` is the single development line. Review through
[root PR #7](https://github.com/thedepartmentofexternalservices/teraguchi/pull/7)
and [Client PR #4](https://github.com/thedepartmentofexternalservices/teraguchi-client/pull/4).
Main, prior feature branches, and the installed pilot remain preserved. This is
an unqualified development candidate; machine testing and installation are paused.

The candidate combines the full Teraguchi product lineage with Alan's frozen
PLANK root `413594743d110d6a9965e639068f132379e82ab2` and Client
`95060dee8fa63e0da98dfa83e7ddd8185731a837`, plus hardened clipboard handling.
The former product-root clipboard pin omitted the larger UI/input lineage;
this integration restores it and reconciles upstream fullscreen and reconnect.

## Exact source provenance

The following implementation snapshot passed the local checks below. Subsequent
overview-document changes do not change these component pins.

| Component | Commit |
|---|---|
| Root implementation | `5bcb53934a601e00d328c05fe430c710f36d157a` |
| Client | `d8b655bbbc30fb08e6e18fb7770ed7a6d08bd7d2` |
| Client common-c | `390774c58043d6af6d516251afcaab5aa4ed6028` |
| Client qmdnsengine | `b7a5a9f225d5e14b39f9fd1f905c4f505cf2ee99` |
| Linux Host | `1ad746b626f31f43ec564f49d5e78ce14ab7a68e` |
| Host common-c | `2ad9d89a41428601c5f36001a5a7c9ab5359a274` |
| Kyber/Kymux | `912ece5c64787997f978673ca60d313898a3548c` |

The retained Mac dependency profile uses Qt 6.10.2, Rust 1.89.0, SDK 26.5,
and deployment target 26.0. Its bootstrap recipe fingerprint matches this
candidate. Full Git history and nested gitlinks retain the other Host dependency
pins; those Linux build dependencies were not initialized for local Mac testing.
Hosted builds perform their own source retrieval and dependency preparation.

Focused upstream root is `6b97b7dcfdee84f8d7619761608bf053d098c7e6`, with
Client `f566064008fcb7b61952701f04091fa145712868` and the same safety Host.
The separate Quit contribution is `c56b0a11506eb4ce5eb1c3c868d3c230934a0531`.
See the [forward plan](docs/development/teraguchi-forward-plan.md) for all PR links.

## Local validation

- Full arm64 Mac Client build passes, version `1.0.120-teraguchi-integration`.
  Native Qt suites report 20 topology, 24 toolbar, 7 desktop/reconnect, and
  12 clipboard results. Clipboard fixtures use a private named pasteboard.
- Existing isolated decode-contract, strict-video, pen, keyboard, display binding,
  assignment/provider, signed setup, TLS trust, support, release verification,
  and workstation UI suites pass. UI tests report 166 results; the native pen
  suite reports 16,439 assertions, without its optional common-c wire archive.
- Eight native Quit bridge scenarios pass, including a negative control against
  the earlier broken bridge. This is not physical Command-Q acceptance.
- All five root CTest suites pass, plus 41 CI policy tests, eight Mac target
  tests, four minimum-OS tests, 14 reconnect guards, and five fullscreen guards.
- Six portable Host clipboard protocol tests and the header-only Host gate pass.
  No local Linux Xlib runtime or hardware qualification is implied.
- An isolated blank-settings workstation smoke test passes. It does not connect
  to a studio host. Source whitespace and documentation-link checks pass.

The local application is a development build, not a signed/notarized distributable.
Its executable SHA-256 is
`ff5914db470b0f1af9d448ef49a15325f935046007bfa82c6503562863fe84ed`.
Private logs, synthetic screenshots, and local build receipts remain outside Git.

Hosted runs for the exact implementation snapshots:
[integration](https://github.com/thedepartmentofexternalservices/teraguchi/actions/runs/35165386855)
and [focused upstream](https://github.com/thedepartmentofexternalservices/teraguchi/actions/runs/35165388598).
The focused upstream run passed all four products. The first integration run
passed Mac Host and compiled both Mac Client targets, but exposed two stale test
assumptions: a literal toolbar offset and AppKit test startup. Those are repaired
in root `0331dd9bd81e825785c67bfb4b9027de90a8cd0d` (Linux preflight) and
`387b697c102e9edfc4631ccd0b056143f1e14b5a` (Mac fixture). Product component
pins and application code are unchanged. The Mac keyboard suite passes locally
with the fixture repair.

Targeted follow-up runs are [Linux Client](https://github.com/thedepartmentofexternalservices/teraguchi/actions/runs/35166162032)
and [Mac Client targets](https://github.com/thedepartmentofexternalservices/teraguchi/actions/runs/35166298981).
These follow-ups and the first integration Linux Host job were still running at
this update. Signing was not requested. Treat final job conclusions as authoritative;
a dispatched run is not a passing build.

## Preserved sources and evidence boundaries

Product root `22d1565` and full product Client `94f3bf49` remain retained, along
with clipboard safety root `48b2d13`, Client `36a9bbe5`, and Host `1ad746b6`.
Original main `04edc2d`, working Client `2b2983e6`, and working Host `434b8def`
are unchanged. Root recovery branches use the `codex/pre-integration-` prefix.

Earlier short pilot observations and synthetic tests do not qualify this merged
candidate. The prior clipboard prototype was rejected as a package candidate;
new lifecycle fixes require repeated live tests. Keep the immediate native pen
cursor behavior; the host-mapped cursor candidate was rejected for visible lag.
Flame tablet-margin alignment remains unresolved. Private installed-binary
receipts and recovery procedures remain outside Git.

## Next work

Finish hosted build validation and review the candidate. Then complete Flame UI
side selection through the client, protocol, Host topology, persistence and
restoration. Schedule a scoped operator session for picture, pen, one/two outputs,
clipboard, reconnect, Quit, audio and recovery only when machine work resumes.
Alan's Quit bridge handles any Qt Quit event; it adds no Command-Q binding and
does not distinguish shortcut-origin events. Native session testing must settle
Command-Q behavior before describing the fix as safe for remote keyboard ownership.

Signed distribution, clean install/rollback, native ten-bit picture, sustained
physical input, WAN, and stability gates remain open. Main is not ready for
promotion based solely on source tests or hosted compilation.
