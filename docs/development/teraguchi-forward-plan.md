# Teraguchi forward plan

Reviewed 2026-09-16. Proposed next milestone: one reproducible, integrated Mac
pilot based on Alan Latteri's frozen PLANK source, with a clear qualification
record. This review changes no installed software or machine configuration.

## Execution update

The authorized consolidation has been implemented on `codex/teraguchi-integration`.
Use [root PR #7](https://github.com/thedepartmentofexternalservices/teraguchi/pull/7)
as the single review entry point, with [Client PR #4](https://github.com/thedepartmentofexternalservices/teraguchi-client/pull/4).
Both PRs are conflict-free. The current candidate root is
`6198e102143d12fe71c42b2b6dee99a6ff590972`.

The maintained version of this plan and current branch guide is on the
[integration branch](https://github.com/thedepartmentofexternalservices/teraguchi/blob/codex/teraguchi-integration/docs/development/teraguchi-forward-plan.md),
with its [candidate handoff](https://github.com/thedepartmentofexternalservices/teraguchi/blob/codex/teraguchi-integration/HANDOFF.md).
The development worktree is `/private/tmp/teraguchi-integration`. This original
checkout remains on preserved main; do not use its older nested checkouts as the
new candidate. The discussion below is the initial review, retained for context.

Upstream rebases are published, and all four focused upstream hosted products
passed. The consolidated candidate's local Mac build and isolated product suites
pass; hosted Linux packages, Mac Host, and both Mac Client builds/product suites
also passed. CI exposed and repaired additional preflight, AppKit fixture, and
cache-profile issues. The final hosted run for this commit
[35167409367](https://github.com/thedepartmentofexternalservices/teraguchi/actions/runs/35167409367)
and its PR merge check both passed all five product jobs. The original upstream
root PR was closed with a rebase handoff, so current upstream review is
[PLANK PR #3](https://github.com/instinctual/plank/pull/3). Alan merged the Quit
PR during this work and published 1.0.121; the focused clipboard stack is now
rebased onto that release. The Teraguchi candidate retains the requested frozen
baseline and already contains the identical Quit bridge. The replacement
upstream stack also passed all four hosted product builds at root `18b01a6`.
Main, recovery branches, and the installed pilot remain unchanged. No machine
installation or physical qualification was performed.

## Recommendation

Keep PLANK as the engine and Teraguchi as the Flame-focused product layer.
Consolidate existing work before adding features. The immediate problem is
source integration and evidence tracking: main, the product development branch,
the clipboard safety branch, and the installed pilot describe different states.
No single one currently represents every desired capability and accepted fix.

Continue toward Apple Silicon client / Rocky NVIDIA Flame host. Preserve the
native ten-bit, HEVC RExt 4:4:4 ten-bit, hardware encode/decode contract. Qualify
one and two displays separately. Windows, new transport work, a renderer rewrite,
Mac hosting expansion, and new infrastructure provisioning remain outside this
milestone. Existing paused machine work remains paused pending a scoped session.

## What the source review established

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

## 1. Rebase the focused upstream contributions

Alan explicitly froze PLANK at
`413594743d110d6a9965e639068f132379e82ab2` and requested rebases:
[root discussion](https://github.com/instinctual/plank/pull/2#issuecomment-5704435469).
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

## 2. Establish one Teraguchi integration candidate

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

## Checks performed during this review

Read local source/history, both main and product/safety handoffs, platform and
release gates, existing product plans, and Alan's GitHub issue/PR discussions.
Fetched PLANK upstream main, Teraguchi origin refs, and upstream Client main.
No rebase, merge, push, deployment, or branch deletion was performed.

On the original main working state, eight macOS target tests, four minimum-OS
tests, and 26 CI tests passed. These 38 tests validate those bounded areas only;
they are not qualification of the proposed integrated candidate.

## September 17 clipboard review follow-up

The current consolidated candidate is `codex/teraguchi-integration` at
`05660d3eac87bee2d81126bb0c59b206e080c4ac`, reviewed in
[PR #7](https://github.com/thedepartmentofexternalservices/teraguchi/pull/7).
Alan's four Client and four Host clipboard findings have code fixes and
regression tests in both the focused upstream PR stack and this candidate.
Native clipboard results: 19 passing. Host Xvfb: nine passing cases and four
negative controls against the reviewed baseline; the fixture now synchronizes
PRIMARY ownership before testing its loss. Updated platform checks are tracked
on the PR. Live paired-system acceptance and review approval remain open.

The active source and detailed handoff are in `/private/tmp/teraguchi-integration`.
This original checkout, main, recovery references and installed pilot remain
preserved. The earlier read-only review statements below describe the initial
planning stage, not the subsequent authorized implementation work.

Final branch validation: [all five Teraguchi products passed](https://github.com/thedepartmentofexternalservices/teraguchi/actions/runs/35203343953), and [all four focused upstream products passed](https://github.com/thedepartmentofexternalservices/teraguchi/actions/runs/35203335544). The separate PR merge run is tracked on PR #7. Alan’s re-review and live paired clipboard/handoff acceptance remain open.
