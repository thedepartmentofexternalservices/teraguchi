# Teraguchi integration handoff

## Current work

The operator authorized consolidation and upstream rebases on 2026-09-16.
This candidate combines the preserved Teraguchi product lineage with Alan's
frozen PLANK root `413594743d110d6a9965e639068f132379e82ab2` and Client
`95060dee8fa63e0da98dfa83e7ddd8185731a837`, plus hardened clipboard handling.
The integration branch is `codex/teraguchi-integration`. Original branches and
the installed pilot remain intact. Qualification is in progress; do not deploy.

## Preserved sources

- Product root `22d1565`; full product Client `94f3bf49`. The later product-root
  clipboard pin omitted the larger UI/input lineage; this integration restores it.
- Clipboard safety root `48b2d13`, Client `36a9bbe5`, Host `1ad746b6`.
- Original main `04edc2d`; original working Client `2b2983e6`, Host `434b8def`.
- Backup root branches use the `codex/pre-integration-` prefix.

## Evidence boundaries

Earlier short pilot observations and synthetic tests do not qualify this merged
candidate. The prior clipboard prototype was rejected as a package candidate;
new clipboard lifecycle fixes require repeated live tests. Keep the native pen
cursor rollback; the host-mapped cursor candidate was rejected for visible lag.
Flame tablet-margin alignment remains unresolved. Private installed-binary
receipts and recovery procedures remain outside Git.

## Remaining work

Finish integrated builds and affected regression suites, retain exact root and
recursive dependency provenance, and verify clean-clone fetches. Update the
focused upstream PRs independently of product UI. Alan's Command-Q question
requires an honest distinction between the Quit event bridge and shortcut policy.
Then complete Flame UI side selection and schedule an operator qualification
session for picture, pen, displays, clipboard, recovery, and audio. No production
hardware or WAN gate is waived, and machine testing remains paused.
