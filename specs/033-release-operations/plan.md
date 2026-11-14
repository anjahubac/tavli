# Implementation plan: Release, operations and repository collaboration

**Status**: scoped proposal; runtime implementation not started by this revision.
**Spec**: [requirements](spec.md) | **Lead/review**: Dev 3 / Anja
**Baseline**: dev 207c94c; every implementing branch starts from then-current origin/dev.

## Existing boundaries and proposed files

- `.github/workflows/`
- `.github/pull_request_template.md`
- `.githooks/`
- `docs/development/team-workflow.md`
- `GitHub repository/environment settings (external)`

Items marked new/proposed/external do not exist at baseline. Verify exact existing
files and consumers before editing; new files remain in current feature/domain/
data/AI/account/sync layers. Shared providers and schema versions are coordinated.

## Contract and data plan

Repository permissions, review policy and environment separation are operational configuration, not app data. Verify actual GitHub handles and plan capabilities; no fictional CODEOWNERS.

Producer dependencies: Existing baseline; no new producer feature required for the first slice.

Use [shared boundaries](../011-team-development/contracts/shared-boundaries.md)
and the [contract template](../../.specify/templates/contract-template.md).
Before implementation, record typed fields, validation, identity/units/CivilDate,
error/retry/undo, ownership, compatibility and producer/consumer fixtures. If data
changes, add data-model.md with current→target columns and a reviewed migration;
allocate drift version only after preceding schema merges. New SQL is additive
where possible, with RLS/grants and local two-account tests. Applied SQL is immutable.
If no schema change is needed, explicitly record that decision in the slice PR.

## Delivery slices

1. Resolve only blocking decisions; map each source requirement to existing code,
   identify work already present and record remaining effort. Never redo completed
   behavior simply because a source ticket is unassessed.
2. Merge the agreed contract/fixtures first; no consumer branch stacks on an
   unmerged producer. Independent research/tests may proceed in separate worktrees.
3. Implement one source task vertically through affected layers with test-first
   logic/parsing and ownership review. Keep phase boundaries in tasks.md.
4. Integrate consumers after producer merge, preserving offline/replay and previous
   UI/quantity behavior. Run relevant 012/013 gates and update real evidence.

## Constitution check (3.0.0)

| Gate | Required response before implementation |
| --- | --- |
| I | English docs; exact Serbian Latin UI/copy for changed screens |
| II | Preserve outbox/account scope; explicit personal/device/reference classification |
| III | Any AI through AIRouter and validated task contract; N/A documented if none |
| IV | No real secrets/logged private content; apply 012 trust-boundary controls |
| V | Test-first logic/parsing; local SQL/Edge tests when backend changes |
| VI | Phone/wide/text/motion/keyboard proof for UI; N/A for technical-only slice |
| VII | Reviewable task slices; generated files via generator only |
| VIII | This canonical spec, owned dev-based branch/task IDs, no stacking |
| IX | Existing paths/interfaces; justify dependencies and migration decisions |
| X | Named human reviewer, producer/consumer contract and schema coordinator |

These are design obligations, not executed pass results. Any violation blocks Ready
until resolved under governance. No dependency is added by this documentation;
implementer records each proposed package/service with a reason before adoption.

## Verification, rollout and risks

Use [testing 013](../013-testing-strategy/spec.md), its journey matrix, and
[security 012](../012-security-baseline/spec.md). Tests must prove the scenarios
in spec.md and source task outcomes using synthetic data/fake AI. Default Flutter
tests do not contact a network; explicit guarded integration uses local services.
No speculative hosted deployment or publication. Record old-client/snapshot
compatibility, pending-outbox migration, failure/undo and forward recovery for
state changes. No destructive reset as a migration. Platform/source/legal/retention
limits from open questions remain release gates. UI checks use current theme/
motion components; do not redesign screens or extract a package incidentally.

## Release implementation slices

Use [release contract](contracts/release-evidence.md). Dev 3 owns workflow and
backend safety; Dev 4/Anja owns signed platform artifacts/distribution; Dev 1
owns schema compatibility and restore fixtures; Dev 2 owns AI service budget/
disable integration. Record real support/rollout choices before automation.

Additional paths: pubspec.yaml version metadata, Android/iOS/macOS build/signing
settings (secrets external), future windows/, reviewed release workflow and
redacted release evidence under docs/releases/ (proposed). Do not create a
placeholder publishing pipeline with access to production secrets.

Same-SHA CI gate is implemented once with 012 T007/T008 and 013 T010. Platform
runner work remains in 013/028. Namespace migration remains 012 T011/T012.
This spec owns the release sequence and evidence, avoiding parallel competing
implementations. Validate on local/synthetic infrastructure; actual production
release or credential operations require explicit authorization.
