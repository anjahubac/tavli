# Specification: Home, adaptive navigation and cooking

**ID**: 021-home-and-cooking | **Feature key**: EVERYDAY-UX
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 4 | **Proposed independent reviewer**: Dev 2 and Dev 1

## Scope and source

Implements the EVERYDAY-UX portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Standardize components in the current repository**. Source D4-002; Dev 4; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Introduce five-tab navigation with central Home**. Source D4-003; Dev 4; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-003**: Deliver **Use camera/gallery on phone and file selection on desktop**. Source D4-005; Dev 4; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-004**: Deliver **Provide the monthly plan view**. Source D4-006; Dev 4; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-005**: Deliver **Keep mobile primary actions above navigation**. Source D4-007; Dev 4; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-006**: Deliver **Align meal cards and show accessible cooked status**. Source D4-008; Dev 4; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-007**: Deliver **Provide the shared cooked/undo operation**. Source D4-009; Dev 4; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-008**: Deliver **Show today's meals on Home**. Source D4-010; Dev 4; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-009**: Deliver **Show one prioritized notice on Home**. Source D4-011; Dev 4; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-010**: Deliver **Provide a readable cooking mode**. Source D4-012; Dev 4; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-011**: Deliver **Add a recipe to a selected plan slot**. Source D4-013; Dev 4; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Five tabs ordered Plan, Nabavka, Početna, Recepti, Ostava; Home initial after auth/name; preserve existing deep links and avatar settings.
- **FR-102**: Today shows next uncooked meal, Kuvaj/Skuvano, tomorrow titles and at most one notice: allergen, missing shopping, plan ending; without plan show one make-plan action.
- **FR-103**: Week/month switches and primary actions retain location/size; mobile fixed actions above navigation/safe areas; wide content uses current adaptive layout.
- **FR-104**: Existing visual language stays. Equal-height ordinary cards adapt at 2× text; cooked state uses green circular check plus text/semantics and muted surface.
- **FR-105**: Cooking has readable step navigation, ingredients and existing wake-lock choice; add-to-plan picks date/slot and confirms replacement.
- **FR-106**: Phone camera/gallery and desktop file picker retain cancellation/error paths; source recipe image remains distinct from dish photo.

## User scenarios and acceptance

- **US1 / SC-001**: After sign-in, Home highlights the next meal; Cooked removes only that meal's shopping demand and Undo restores it once.
- **US2 / SC-002**: At phone width and 2× text, the last ingredient and fixed action remain reachable above navigation/keyboard.
- **US3 / SC-003**: Opening an existing recipe deep link still reaches the correct recipe after five-tab migration.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Home is a projection of approved plan data, not another store. Shared cooked/undo operation stays in existing domain/repository boundaries; pantry and intake extend its versioned contract in 022/023.

## Exact UI copy carried forward

“Početna”, “Napravi plan”, “Kuvaj”, “Skuvano”, “Poništi”, “Dodaj u plan”, “Prethodni”, “Sledeći”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: Existing baseline; no new producer feature required for the first slice.

- **Q1** (Dev 4 with reviewer): Finalize Home route, shared cooked operation identity/ownership and manual pantry edit interaction before dependent feature integration.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
