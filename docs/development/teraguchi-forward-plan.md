# Teraguchi forward plan

Updated 2026-09-17. Current milestone: one reproducible, integrated Mac
pilot based on Alan Latteri's frozen PLANK source, with a clear qualification
record. This review changes no installed software or machine configuration.

## Current upstream baseline

The candidate now incorporates PLANK 1.0.124 and its replacement Quit lifecycle
and captured Command-Q guard. The focused clipboard PR stack is rebased onto
upstream root `20ee198b` / Client `86682b5b`; the published Teraguchi development
line preserves history through a merge. Prior frozen-baseline references below
record the original consolidation. Current pins and gates are in HANDOFF.

## Recommendation

Keep PLANK as the engine and Teraguchi as the Flame-focused product layer.
Consolidate existing work before adding features. The immediate problem is
source integration and evidence tracking: main, the product development branch,
the clipboard safety branch, and the installed pilot describe different states.
The integration candidate now consolidates the reviewed product and safety
changes; production acceptance remains open.

Continue toward Apple Silicon client / Rocky NVIDIA Flame host. Preserve the
native ten-bit, HEVC RExt 4:4:4 ten-bit, hardware encode/decode contract. Qualify
one and two displays separately. Windows, new transport work, a renderer rewrite,
Mac hosting expansion, and new infrastructure provisioning remain outside this
milestone. Existing paused machine work remains paused pending a scoped session.

## Branch guide and current review

| Branch | Purpose | What to do with it |
|---|---|---|
| `codex/teraguchi-integration` | One current development candidate | Continue product work here through root [PR #7](https://github.com/thedepartmentofexternalservices/teraguchi/pull/7) and Client [PR #4](https://github.com/thedepartmentofexternalservices/teraguchi-client/pull/4). |
| `main` | Preserved baseline | Advance only after candidate review and the applicable acceptance gates. |
| `codex/assignment-refresh` | Earlier broad product work | Retain as history/recovery; its name understates its contents. |
| `codex/clipboard-safety` | Earlier clipboard repair line | Retain as history/recovery; its fixes are included in integration. |
| `upstream/clipboard-sync` | Small shared clipboard contribution | Keep separate from Teraguchi product UI; rebased on Alan's freeze. |
| `upstream/macos-quit` | Separate native Quit contribution in Client | Keep separate; Command-Q policy still needs native verification. |
| `codex/pre-integration-*` | Recovery pointers | Keep until the integrated candidate is accepted. |

Branch names exist independently in the root and nested Client/Host repositories.
A root commit records the exact nested commits; it does not require identical
branch names in each repository. Use the root PR as the review entry point.
No old branch was deleted, and no installed software was replaced.

## What the initial source review established

- Local main is `04edc2d`. It includes macOS 26 target support, VideoToolbox
  hardware attestation, upstream reconnect/Retina changes, early clipboard work,
  and the Flame UI origin boot helper. Its overview docs lag those changes.
- Main records Client `3ba987a2` and Host `9329784a`. The working submodules
  are clean internally but checked out at newer Client `2b2983e6` and Host
  `434b8def`. Preserve these revisions; a root-only checkout is not this state.
- `codex/assignment-refresh` at `22d1565` is the broad product development
  lineage. Despite its narrow name, it contains the workstation picker,
  onboarding, assignments/trust, Mac input, strict video policy, dual-output
  work, support/reporting, and pilot preparation. Its source and historical
  tests do not establish current production acceptance.
- `codex/clipboard-safety` at `48b2d13` contains later clipboard lifecycle
  repairs, pinning Client `36a9bbe5` and Host `1ad746b6`. It has a separate
  worktree. Its handoff explicitly withdraws package-candidate acceptance of
  the earlier prototype and requires fresh live testing. Do not transfer the
  prototype's copy/paste result to these newer sources.
- Strict Teraguchi admission and the fuller artist UI exist in product branch
  history, not current main. They must be reconciled with current upstream,
  not recreated from the outdated main overview.
- The attested decode probe already has recorded M2 Ultra hardware results.
  Those short synthetic decode runs do not prove native host capture, physical
  display precision, end-to-end color, or a sustained dual-display session.
- Product history records a rejected pen-cursor candidate because of visible
  lag, plus an unresolved Flame tablet-margin alignment problem. Preserve the
  rollback; a passing renderer fixture does not override that operator result.
- The earlier roadmap is retained at `d26d192` on `codex/product-roadmap`.
  The P3/P4 checklist in `22d1565` is a useful backlog, but its completed
  checkboxes need exact-candidate validation after integration.

This is a cross-project source, history, and evidence review, not an exhaustive
security audit or live hardware qualification. No installed binary was inspected.

## 1. Rebase the focused upstream contributions — implemented

Alan explicitly froze PLANK at
`413594743d110d6a9965e639068f132379e82ab2` and requested rebases:
[root discussion](https://github.com/instinctual/plank/pull/3#issuecomment-5704435469).
That source has been fetched. It includes the published 1.0.120 source lineage,
accepted native fullscreen changes, and all-product dependency caching. Its
Client pin is `95060dee`; its Linux Host remains `9329784a`.

Preserve current branch tips and submodule pins before changing history. Use
isolated integration worktrees and rebase the contribution branches, leaving
published main and the installed pilot intact. Explicit fetch plus controlled
rebase is preferable to an unqualified pull in the current mixed checkout.

Reconcile common-c wire definitions, Host and Client implementations, and root
transport definitions as a coordinated stack. Build against the complete stack;
publish dependency commits before root gitlinks and verify clean-clone fetches.
Keep native Quit separate from clipboard and keep Teraguchi product UI out of
Alan's focused PRs. Include the later clipboard safety repairs after verifying
their dependency and test coverage; do not rebase only the old prototype.

Alan also asks whether the Quit change allows Command-Q during a session:
[Quit question](https://github.com/instinctual/plank-client/pull/1#issuecomment-5702932012).
Recommended behavior: explicit application-menu Quit disconnects and exits
cleanly; remote keyboard ownership must not accidentally quit the local client.
Inspect the complete menu/shortcut/event route and demonstrate menu Quit,
Command-Q, focus changes, reconnect, and idle Quit before giving a definitive
answer. The bridge alone does not prove how Command-Q is dispatched.

Exit: focused rebased diffs, dependency provenance, passing affected tests, and
an evidence-backed reply draft. No GitHub replies were posted in this review.

## 2. Establish one Teraguchi integration candidate — implemented, validating

Use a fresh `codex/` integration branch based on the frozen upstream source.
Bring forward the reviewed product changes and clipboard fixes in bounded
slices. Preserve attribution and distinguish shared engine changes from product
policy. Resolve upstream native fullscreen against Teraguchi's dual-output,
input, and menu-bar behavior explicitly rather than choosing an entire file
from either branch.

Retain these invariants throughout integration:

- macOS 26 client target and dependency minimum-OS checks; separate Mac Host policy;
- strict video admission, attested hardware, and no silent source/format fallback;
- signed workstation trust, assignment expiry/revocation, PAM, and seat ownership;
- ordered keyboard/pen input, release-all cleanup, and accepted cursor behavior;
- clipboard bounds, Unicode validation, focus policy, session generations, and teardown;
- dependency cache isolation, package provenance, signing, and private-data boundaries.

Run the affected existing native, protocol, input, UI, trust, and packaging
suites, plus clean hosted product builds where applicable. Record skipped live
checks explicitly. Do not promote unqualified Linux input-library changes merely
to make the branch look complete.

Exit: one exact root plus all recursive dependency pins; one retained candidate;
one current handoff and support matrix. Archive old branches only after their
useful changes and rollback references are accounted for. Main becomes the
accepted integration point after review and validation, not an experimental
scratch branch. Short-lived feature branches feed it; upstream PR branches stay
small and separate.

## 3. Close daily-work blockers and prove the picture/input path

First complete Flame UI side selection across picker, launch validation, Host
supervisor, applied topology, persistence, and exact restoration. The boot helper
alone does not deliver the feature. Update both peers and protocol vectors.

Then qualify the integrated candidate in a scoped, recoverable operator session:

1. Native ten-bit capture through encoding, hardware decode, Metal and physical
   display; distinguish native levels from NvFBC eight-bit up-conversion.
2. Clipboard both directions, focus loss, disconnect/reconnect, stale traffic,
   and invalid/oversized payloads against the hardened candidate.
3. Pen pressure, tilt, eraser, hover, buttons, modifiers, cursor alignment and
   tablet margins; trace the first divergence without reintroducing rejected lag.
4. Single/dual-display selection, Flame UI side, mapping, focus, fullscreen,
   unplug, reconnect, and session-end restoration.
5. Login/logout, Ask/Keep Waiting/Disconnect, native Quit, outage, definitive
   authentication rejection, exclusive seat, and input/resource cleanup.
6. Changing Flame footage and audio: 30-minute working session, then inherited
   two-hour A/V and eight-hour stability gates, with failures retained privately.

Exit: reproducible outcomes tied to the exact candidate. A successful short
pilot does not close the full gate matrix. If one display passes before two,
an explicitly narrowed release can be proposed; never silently downgrade a
two-display request.

## 4. Prepare a controlled artist pilot, then release

Set stable bundle/product identity before clean-Mac permission tests. Complete
signed/notarized packaging, trusted setup delivery, clean install, repair,
certificate/setup rotation, update and rollback. Reuse the existing distribution
work; evaluate a manual verified installer before expanding custom updater scope.

Verify external assignment isolation, certificate trust, PAM denial, seat denial,
and revocation separately. Then run representative artist WAN routes, direct and
relay labels, random/burst loss, outage recovery, and real Flame workloads.
Retain the existing planned five eight-hour single-display and five eight-hour
dual-display shifts before claiming both production-ready, unless the operator
explicitly revises release scope. Measure input-to-picture latency independently;
toolbar RTT is network round-trip time.

Exit: supported hardware/OS/profile matrix, exact release provenance, practical
support and rollback procedures, and the applicable acceptance evidence. Roll
out to a small group first. Windows feasibility follows the Mac production gate.

## Current results and next gate

The September 17 update implements Alan's four Client and four Host clipboard
findings in both the focused upstream stack and consolidated candidate. The
native Client suite reports 19 passing results; the Host Xvfb suite reports nine
passing cases and four failing-baseline negative controls. See the
[review follow-up](clipboard-review-followup.md). PR approval and live paired
clipboard/handoff acceptance remain open. Native Quit PR #1 has merged upstream;
its approval does not establish native runtime qualification.

The focused root and Client PRs have been rebased on Alan's frozen commits. The
Host base was unchanged; its safety repairs are published. Both common-c header
branches are represented in the upstream stack. Product integration restores the
full Client lineage and reconciles reconnect, assignment trust, native fullscreen,
dual-output behavior, and clipboard focus. See [HANDOFF](../../HANDOFF.md) for
exact pins and validation results.

Upstream review links: [root clipboard](https://github.com/instinctual/plank/pull/3),
[Client clipboard](https://github.com/instinctual/plank-client/pull/2),
[Host clipboard](https://github.com/instinctual/plank-host-linux/pull/1),
[Host headers](https://github.com/instinctual/plank-common-c/pull/1),
[Client headers](https://github.com/instinctual/plank-common-c/pull/2), and
[native Quit](https://github.com/instinctual/plank-client/pull/1).

PLANK 1.0.124 replaces the earlier Quit bridge. The current candidate imports
its explicit application-exit ownership and captured Command-Q guard, plus the
native regression suites. Combined Teraguchi physical input/session acceptance
remains open.

The local arm64 Mac build and isolated product suites pass. Hosted builds check
fresh source retrieval and platform compilation separately. These results do not
qualify native capture, physical pen input, two-display color, or live clipboard
recovery. The next product work is section 3; machine work remains paused until
a scoped operator session. Main should not be promoted merely because CI is green.
