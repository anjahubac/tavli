# Implementation Plan: Meal plans and linked shopping

> Direction review, 2026-11-13: read the [current direction overlay](current-direction.md)
> before new work. This document retains the original 010 scope and acceptance
> history; implemented code and unchecked acceptance must be assessed separately.


**Branch**: `010-plan-and-shopping` (from latest `main`)
**Date**: 2026-11-02
**Spec**: [spec.md](spec.md)
**Status**: Planned; this change creates documentation only. No app/schema work is completed.

## Summary

Implement one connected Plan-first experience: propose a week/calendar month,
review/lock/save, derive weekly shopping, account for confirmed stock once,
shop and cook. Standalone recipe → ingredients → shopping is equally available
without a plan or forced library save. Product/UI decisions are in [product design](../../docs/product-design.md).
UI/UX usability is a release gate, not a final styling task: prototype and
test the core journey before schema/UI implementation, then validate the real app.

Preserve auth, recipe editing/history, existing sync/outbox, wake lock and
005 themes. The 005 branch must first land through main; do not stack on it.
008 invitations and 009 realtime are independent follow-ups, not blockers for
solo-household planning. Historical specs describe delivered behavior.

## Technical Context

**Language/Version**: project Dart SDK constraint ^3.13.7; Flutter/Material 3.
**Dependencies**: existing Riverpod, go_router, drift, dio, Supabase, wakelock_plus;
005's bundled font/theme after merge. No new dependency is planned.
**Storage**: drift account cache + outbox; Supabase EU with existing ownership model.
**Testing**: Dart domain/AI tests first, fake-backend widget/integration tests,
temporary-file migration tests, local-only pgTAP with two accounts, prototype usability.
**Targets**: Android, iOS, macOS; phone and wide navigation.
**Scale**: up to 31 days × 3 meal types; several saved plans; six calendar-week
periods within one month. Saved browsing/manual work remains offline.
**Performance**: local actions show feedback immediately; benchmark a seeded
93-entry plan with 1,000 ingredient contributions so local reconciliation
finishes within 1 s on the reference macOS test device. Record the device and
results rather than claiming timings now. Provider generation has progress,
cancel and retry, not an unrealistic fixed free-tier completion promise.

## Constitution Check

Pre-research and post-design checks pass at the documentation/design level.
Implementation gates below remain required; no test/build success is claimed here.

| Principle | Design and implementation gate |
| --- | --- |
| I Serbian UI | Exact copy in spec; every new label/error/semantic name Latin Serbian. |
| II Account-backed offline | Account-scoped repositories; row + outbox atomically; migration, registry, cleanup, RLS/grants and two-account tests. |
| III AI through router | MealPlanAI uses AIRouter text; parsing throws FormatException; existing fallback/error mapping retained. |
| IV Secrets | No real credentials/data in docs, fixtures, logs, tests or prototype. |
| V Test-first | Domain, parsers, quantity planning and migrations tested before implementation; AI/backend faked. |
| VI Responsive | 320/400/1200 px, text 2×; bottom navigation <720 and rail ≥720, extended ≥1000. |
| VII Small commits | Deliver tested story slices, generated code with its source; no unrelated refactors. |
| VIII Spec/branch | One connected planning/shopping feature on 010 from current main. |
| IX Guardrails | No new dependency; new migrations only; never reset user data or loosen lints. |

## Phase 0 — Research and UX decisions

[research.md](research.md) records inspected repository facts and decisions.
The current schema has plan/list foundations but not per-slot portions,
approved snapshots or quantity provenance. A recipe-name-only de-duplication
algorithm from 005 cannot meet repeated-recipe/portion requirements.

Build the connected low-fidelity prototype first: Plan empty/setup/preview,
weekly/monthly views, replacement/lock, weekly shopping, pantry confirmation,
purchase/undo, cooking and failure states, plus standalone recipe shopping
with no plan and an unsaved recipe preview. The setup uses one screen for period,
meal types and portions; optional preferences/pantry details are expandable.
Preview and confirmation are separate, with one primary action per screen.

Test five representative people on their first attempt. At least four must
complete both plan → shopping → cooking and standalone recipe shopping without coaching. Record
task success, wrong turns and hesitation, fix blocking issues and retest.
This is a target, not a completed usability result. Include phone/large-text
and one-handed shopping. Do not require pantry entry or preference onboarding
before someone can create their first plan.

## Phase 1 — Design, data and contracts

See [data-model.md](data-model.md), [app interfaces](contracts/app-interfaces.md)
and [UX contract](contracts/ux.md).

- Pure Dart calendar/quantity/provenance rules use injected clock and civil
  dates. Preserve approved entry snapshots and per-entry servings.
- MealPlanAI prepares in-session drafts through AIRouter; weekly batches and
  at most three new recipe summaries per detail request keep responses bounded.
  Existing saved recipes can be reused; missing cooking steps are completed
  only on request, with review. No network calls run inside DB transactions.
- Approval persists new recipe data, plan/entries and any existing shopping
  reconciliation in one scoped local transaction with ordered outbox entries.
  Discard is side-effect-free. A partial save is explicit.
- Canonical weekly lists feed the month aggregate. New normalized shopping
  contributions and supply allocations provide entry-level quantities and
  one-time pantry/purchase credit. No full inventory/payment subsystem is added.
- Additive schema changes are future work: bump the then-current drift version,
  migrate without rewriting applied SQL, regenerate, update every sync entity,
  legacy path and account cleanup. RLS/grants and cross-household FKs apply to
  all three new child tables. Extend tombstone triggers and deletion/account tests.
- Keep personal taste/ratings private. Plan creation uses current-user settings
  plus explicit requests; do not store a private profile dump on shared plans.

## Project Structure

### Documentation

```text
specs/010-plan-and-shopping/
  spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
  contracts/app-interfaces.md, contracts/ux.md
  checklists/requirements.md
```

### Planned application changes (not created by this documentation revision)

```text
lib/domain/meal_plan.dart, plan_calendar.dart, shopping_source.dart, shopping_demand.dart, supply_allocation.dart
lib/ai/meal_plan_ai.dart, meal_plan_prompts.dart
lib/data/meal_plan_repository.dart, shopping_repository.dart, pantry_repository.dart, taste_repository.dart
lib/features/planning/             setup, preview, calendar, providers
lib/features/shopping/             grouped list, period selector, source details
lib/features/pantry/               inventory, confirmation, expiry
lib/features/recipes/              add-to-plan and cooking; preserve existing edit/history
lib/app/                          Plan-first router/shell and avatar, theme tokens
lib/sync/                         mapping/order/deletions for new entities
test/                             mirrors implementation; fake backend extended
supabase/migrations/               new planning/shopping schema and policy migration
supabase/tests/                   two-account planning/shopping/personal isolation tests
```

Use the feature repository pattern and central wiring; do not expose DB/network
calls to widgets. New table/column names and state transitions are in data-model.

## Delivery and compatibility

1. Prototype, navigation contract and usability evaluation precede app changes.
2. Tests and additive data/sync foundation, including the shared source/demand/
   allocation reconciliation core, precede approval/edit transactions and feature writes.
3. US1 generation/approval → US2 review → US3 plan shopping deliver the planned
   journey; US4 standalone recipe shopping is a P1 slice that works without a plan.
4. US5 pantry/preferences and US6 cooking/feedback complete the loop; US7
   responsive/visual validation applies throughout, not only at the end.
5. The complete 010 release includes both week and month, their shopping, offline
   behavior and UX gates. A prototype or weekly-only slice is not "010 complete".

Maintain old /recipes, /profile, /shopping and auth return links. Initial
post-auth route becomes /plan; manual selection of another valid deep link is
respected. /plan opens the calendar even when no saved plan exists. Preserve
006a sign-out retention and 007 wake-lock choice. New fields accept old rows;
legacy purchases are never split into new weeks automatically.

Record-level last-write-wins/delete-wins remains until 009. Draft acceptance
re-reads affected local rows and checks a base fingerprint, rejecting known
stale edits; it does not claim cross-device serializable stock reservations.
Downloaded conflicts are surfaced for stock review. Do not weaken server RLS.

## Verification and completion

[tasks.md](tasks.md) maps every requirement and success criterion to work.
[quickstart.md](quickstart.md) is the future implementation validation guide.
Run formatting/check.sh, macOS build, local Supabase migration/RLS tests,
fake-backend round trips, the full seeded journey and five-person usability
evaluation before claiming implementation complete. No production calls from
tests/scripts; local credentials are handled by the developer, never read here.

## Complexity Tracking

No constitution exception. Three normalized child tables are justified by
preparation identity, per-source demand and stock allocation; JSON snapshots remain suitable for
approved recipe content. Standalone recipe shopping is in scope. Partial purchase UI, semantic ingredient aliases,
nutrition/budgeting and a full inventory ledger are outside this feature.
