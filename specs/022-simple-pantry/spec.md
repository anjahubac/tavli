# Specification: Simple pantry and reversible consumption

**ID**: 022-simple-pantry | **Feature key**: PANTRY
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 4 | **Proposed independent reviewer**: Dev 1

## Scope and source

Implements the PANTRY portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

At `origin/dev` `28fa253`, the pantry repository and shopping receipt path
exist. The Ostava destination still shows a placeholder. Listing, edits and
accessible removal remain UI work.

## Requirements and source traceability

- **FR-001**: Deliver **List and add pantry ingredients**. Source D4-014; Dev 4; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Remove pantry ingredients with undo**. Source D4-015; Dev 4; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-003**: Deliver **Receive checked purchases into the pantry**. Source D4-016; Dev 4; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-004**: Deliver **Consume and edit pantry quantities with reversal**. Source D4-017; Dev 4; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Presence means available; show name and optional quantity, no redundant imam badge, expiry field or use-first subsystem.
- **FR-102**: Search/add from the catalog and group rows by category. Offer swipe on phones and a visible or discoverable row action labeled “Ukloni” on compact and wide layouts. The action must work with keyboard and assistive input. Expose “Poništi” and restore focus to a logical row or list control.
- **FR-103**: Checked purchases move only via explicit Prebaci u ostavu, once; purchase/receipt is a single supply credit.
- **FR-104**: Cooking consumes known quantities once without negative stock; undo restores once. Unknown quantity persists until user removes it; manual adjustments are possible.

## User scenarios and acceptance

- **US1 / SC-001**: Press transfer twice or replay after offline restart: stock/coverage does not double.
- **US2 / SC-002**: Cook/undo/undo for a recipe restores original known stock exactly once; unknown-presence items remain present.
- **US3 / SC-003**: Use the row action to remove a food without swiping. Undo restores the same food identity and quantity. Verify with touch on a compact view and with keyboard and screen reader on a wide view.
- **US4 / SC-004**: At 2× text, open a quantity edit from a grouped pantry row and reach both the input and save action with the keyboard visible. A row without a known quantity remains identifiable without an availability badge.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Household pantry item uses food identity and optional quantity, with idempotent purchase-receipt and cooking provenance. Preserve legacy data until a separate reviewed migration retires fields.

## Exact UI copy carried forward

“Ostava”, “Dodaj namirnicu”, “Prebaci u ostavu”, “Količina”, “Sačuvaj”,
“Ukloni”, “Poništi”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [018](../018-ingredient-catalog/spec.md), [020](../020-catalog-shopping/spec.md), [021](../021-home-and-cooking/spec.md)

- **Q1** (Dev 4 with reviewer): Agree zero-stock behavior, manual edit sheet/copy and concurrent adjustment-versus-undo policy; no legacy data deletion by inference.
- **Q1 partial decision (2026-11-19, Dev 4)**: zero-stock and
  adjustment-versus-undo follow the
  [cooked meal contract](../021-home-and-cooking/contracts/cooked-meal-contract.md):
  displayed stock floors at 0, a manual count wins over earlier cooking, undo
  restores only consumption not superseded by a later count. Edit sheet copy
  remains open.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
