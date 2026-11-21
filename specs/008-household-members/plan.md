# Implementation plan: Household, member preferences and personal choices

**Status**: scoped proposal; runtime implementation not started by this revision.
**Spec**: [requirements](spec.md) | **Lead/review**: Dev 3 / Dev 1 and Dev 2
**Baseline**: dev 207c94c; every implementing branch starts from then-current origin/dev.

## Existing boundaries and proposed files

- `lib/account/`
- `lib/domain/account.dart`
- `lib/features/account/`
- `lib/features/settings/`
- `lib/data/`
- `lib/sync/entities.dart`
- `supabase/migrations/`
- `supabase/tests/`

Items marked new/proposed/external do not exist at baseline. Verify exact existing
files and consumers before editing; new files remain in current feature/domain/
data/AI/account/sync layers. Shared providers and schema versions are coordinated.

## Contract and data plan

Household membership/invites are server-authorized; preferences, allergens, favorites and ratings are personal. The [member planning inputs contract](contracts/member-planning-inputs.md) specifies the proposed typed boundary, selected participants and fixtures. Planning receives only the agreed minimum aggregate. New grants/RLS and account-scope/outbox transitions require migration and denial tests.

The D3-001 contract PR is documentation and interface design only. Later slices implement personal tastes in the existing `taste_profiles` path, user/allergen-group and user/favorite relations, catalog food/group mappings with Dev 1, then the aggregate consumed by Dev 2. Document current-to-target columns in `data-model.md` before the schema slice; allocate the next drift version after earlier schema PRs merge. No new dependency is proposed.

Producer dependencies: Existing baseline; no new producer feature required for the first slice.

Use [shared boundaries](../011-team-development/contracts/shared-boundaries.md)
and the [contract template](../../.specify/templates/contract-template.md).
Before implementation, record typed fields, validation, identity/units/CivilDate,
error/retry/undo, ownership, compatibility and producer/consumer fixtures. If data
changes, add data-model.md with current→target columns and a reviewed migration;
allocate drift version only after preceding schema merges. New SQL is additive
where possible, with RLS/grants and local two-account tests. Applied SQL is immutable.
If no schema change is needed, explicitly record that decision in the slice PR.

## Recipe ratings data slice

D3-018 / FR-011 reuses the existing owner-only ratings table and sync outbox.
The server uses a unique user and recipe pair and keeps the existing server
ID when an offline write arrives from another device. The Drift v7 to v8
upgrade keeps the latest rating per pair and adds a local cache for the
household average and count. Dev 3 owns the ratings repository and SQL.
Coordinate changes to `lib/data/database.dart`, its generated output and
`lib/sync/` with Dev 1 before integration. The UI follows the agreed
[ratings contract](contracts/recipe-ratings.md) in a later slice.

The summary endpoint checks current membership and returns only recipe
identifiers, counts and averages, paged through the data layer. The average
uses one decimal place. In a small household, the count and average may allow
someone to infer a score. Private notes are available only to their authors.
Credential and file impacts are N/A. Deploy the migration through the
existing workflow before distributing a client that uses the new sync contract.

## Delivery slices

1. Resolve only blocking decisions; map each source requirement to existing code,
   identify work already present and record remaining effort. Never redo completed
   behavior simply because a source ticket is unassessed.
2. Merge the agreed contract/fixtures first; no consumer branch stacks on an
   unmerged producer. Independent research/tests may proceed in developers' existing
   checkouts, with one active writer per checkout; no automatic extra worktrees.
3. Implement one source task vertically through affected layers with test-first
   logic/parsing and ownership review. Keep phase boundaries in tasks.md.
4. Integrate consumers after producer merge, preserving offline/replay and previous
   UI/quantity behavior. Run relevant 012/013 gates and update real evidence.

## Constitution check (3.0.1)

| Gate | Required response before implementation |
| --- | --- |
| I | English docs; exact Serbian Latin UI/copy for changed screens |
| II | Preserve outbox/account scope; explicit personal/device/reference classification |
| III | D3-001 adds no AI call; later planner use remains through AIRouter |
| IV | No real secrets/logged private content; apply 012 trust-boundary controls |
| V | Test-first logic/parsing; local SQL/Edge tests when backend changes |
| VI | D3-001 is documentation-only; UI slices require phone/wide/text/motion/keyboard proof |
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
limits from open questions remain release gates. UI follows the design canvas and the
UI standard; do not invent layouts or move components into the package incidentally.
