# Specification: Catalog-based shopping and supply reconciliation

**ID**: 020-catalog-shopping | **Feature key**: SHOPPING-FOODS
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 1 | **Proposed independent reviewer**: Dev 4

## Scope and source

Implements the SHOPPING-FOODS portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

At `origin/dev` `28fa253`, both shopping modes exist. With recipe items and
no plan, shopping opens “Po receptu”. Explicit selection remains available and
survives navigation within the account session. The code has switch regression
tests for touch and mouse input. Source details are accessible by long press
or a screen-reader action. The visible source action and fixed transfer bar
remain planned.

## Requirements and source traceability

- **FR-001**: Deliver **Split shopping code by responsibility**. Source D1-004; Dev 1; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Aggregate shopping by ingredient identity**. Source D1-012; Dev 1; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-003**: Deliver **Add manual shopping items from the catalog**. Source D1-013; Dev 1; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-004**: Deliver **Account for pantry stock in shopping**. Source D1-014; Dev 1; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-005**: Deliver **Fix the shopping-mode switch regression**. Source D4-004; Dev 4; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Fix the Po receptu → Po planu switch regression with reproduction evidence independently of the later catalog migration.
- **FR-102**: Group by canonical food and compatible unit; preserve original/unresolved text, approximate marker and unknown quantity instead of guessing.
- **FR-103**: Repeat Add changes only the delta; different recipes share supply once; bought/manual rows remain through reconciliation.
- **FR-104**: Known pantry stock reduces numeric demand; unknown presence stays visible with a check-quantity note, not full coverage.
- **FR-105**: Manual item input prefers catalog search but permits visibly unresolved text; month/weekly list boundaries and standalone preparation identity remain unchanged.
- **FR-106**: Give generated items with source details a visible “Za koje obroke” action reachable by touch, pointer and keyboard. Opening it preserves the checked state. On wide screens the source details may sit beside the list. Keep “Prebaci u ostavu” reachable on compact screens above navigation when there are eligible purchases.

## User scenarios and acceptance

- **US1 / SC-001**: Add one missing item, unmark a second available item, add again: exactly one new need is created.
- **US2 / SC-002**: Demand 300 g, pantry 100 g, purchase 200 g, transfer: coverage is still 300 g; increasing demand to 400 g adds only 100 g.
- **US3 / SC-003**: Switching recipe/plan mode twice preserves selection and displays the correct list after navigation/restart.
- **US4 / SC-004**: Starting with a standalone recipe and no plan, add missing ingredients and open the resulting recipe list. Switch modes and return without losing that list. In either mode, where source details are available, open them by keyboard without marking the item bought. With a saved plan, reach weekly shopping in at most two actions.

For [Trello #26](https://trello.com/c/Cs2TrwS4), the
[manual-item fixture](fixtures/manual_catalog_shopping_test.dart.txt) supplies
three shopping rows. The 200 g recipe row and 100 g manual catalog selection
share a food ID and yield one 300 g total. The 50 g manual entry with the same
display name and no food ID stays separate. The fixture exercises totals after
item entry. The eventual input flow must also save explicit free text without
assigning a food ID, even when the text matches a catalog name.

The fixture passed on prototype `f74d08e` with 41 existing repository tests.
To rerun it there, copy it to `test/data/manual_catalog_shopping_fixture_test.dart`
and run `flutter test test/data/manual_catalog_shopping_fixture_test.dart`.
Team `dev` currently groups these rows by text and has no shopping-row
`foodId` field. The prototype's manual write also resolves matching names
automatically, so this run verifies aggregation from stored rows only.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Preserve existing shopping sources/contributions/allocations, integer micros and receipt provenance. Catalog migration is additive with legacy unmapped fallback; refactor by responsibility without changing semantics.

## Exact UI copy carried forward

“Po planu”, “Po receptu”, “Proveri količinu”, “Imaš u ostavi, proveri”,
“Za koje obroke”, “Prebaci u ostavu”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [017](../017-kitchen-unit-conversion/spec.md), [018](../018-ingredient-catalog/spec.md)

- **Q1** (Dev 1 with reviewer): Agree split boundaries before overlapping edits; capture the switch bug on the reported build/device; resolve legacy mapping and quantity display semantics.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.

## PR #49 correction acceptance — 2026-11-19

The FR-005/FR-101 review slice must satisfy:

- Wait for both plan and recipe-shopping data before choosing the initial mode.
  An initial load failure displays an error and retry, never an empty state.
- With recipe items and no plan, open “Po receptu”. A subsequently arriving plan
  does not change the selected mode; explicit switching remains available.
- Failed plan items, recipe items or preparation metadata display a recoverable
  error rather than an empty list. Retrying restores the appropriate content.
- At phone and wide widths with text at 2×, segment labels retain that scale
  without overflow. Existing shared button styling remains unchanged.
- “Poništi”, “Vrati” and “Otvori” remain usable after five seconds when accessible
  navigation is enabled; normal navigation retains the five-second timeout.

Exact additional/reused UI copy: “Nabavka trenutno ne može da se prikaže.”,
“Pokušaj ponovo”, “Još nemaš plan”,
“Nabavka po planu nastaje iz sačuvanog plana obroka.”, “Napravi plan”,
“U „Po receptu“ te čeka {broj stavki} za kupovinu.”,
“Sve iz nabavke po receptu je kupljeno.” The existing plural formatter supplies
`{broj stavki}`. The mode control itself provides the route to “Po receptu”; there
is no duplicate “Otvori po receptu” action in the no-plan state.
