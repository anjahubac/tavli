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

## Verified baseline — 2026-11-20

At `origin/dev` `28fa253`, the five destinations, default `/home`, profile
placement and responsive shell exist. Home is a placeholder. The local
`tavli_ui` gallery contains shell components that the app has yet to adopt.
Plan already has week/month views and a wide list/detail layout. The current
Plan meal detail can change the cooked flag. The shared event producer is
work in progress on `021-cooked-meal-operation`. Home's meal cards, dedicated
cooking mode and the end-to-end mark/undo journey remain open.

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

- **FR-101**: Preserve default `/home` after auth/name gates and existing deep links. Bottom order is Plan, Nabavka, Početna, Recepti, Ostava, with the profile avatar above. Side order is Početna, Plan, Nabavka, Recepti, Ostava, with Profil at the bottom. Verify narrow-window navigation against the [UI standard](../../docs/development/ui-standard.md) before adopting the gallery shell.
- **FR-102**: Today shows next uncooked meal, Kuvaj/Skuvano, tomorrow titles and at most one notice: allergen, missing shopping, plan ending; without plan show one make-plan action.
- **FR-103**: Week/month switches and primary actions retain location and size. Keep mobile actions above navigation and safe areas. Support a six-week month, selected-day meals and a day-list alternative when the compact grid cannot fit readable labels and 48×48 targets. Wide layouts can place calendar and details beside each other.
- **FR-104**: Existing visual language stays. Equal-height ordinary cards adapt at 2× text; cooked state uses green circular check plus text/semantics and muted surface.
- **FR-105**: Cooking has readable step navigation, ingredients and existing wake-lock choice; add-to-plan picks date/slot and confirms replacement.
- **FR-106**: Phone camera/gallery and desktop file picker retain cancellation/error paths; source recipe image remains distinct from dish photo.
- **FR-107**: Give “Kuvaj” priority for the next uncooked meal and reach saved steps in at most two actions from Home. For planned meals, “Skuvano” and “Poništi” use the shared operation from Home, Plan and cooking mode. Offer immediate undo and keep it available in the meal detail after the message expires. Keep recipes without saved steps usable for ingredients and shopping.
- **FR-108**: Distinguish no plan from a planned day with all meals cooked and from a read failure. Show “Napravi plan” in the no-plan state. Show the all-cooked message when applicable and preserve the one-notice priority in FR-102. Allow retry on failure and show cached meals offline.

## User scenarios and acceptance

- **US1 / SC-001**: After sign-in, Home highlights the next meal; Cooked removes only that meal's shopping demand and Undo restores it once.
- **US2 / SC-002**: At phone width and 2× text, the last ingredient and fixed action remain reachable above navigation/keyboard.
- **US3 / SC-003**: Opening an existing recipe deep link still reaches the correct recipe after five-tab migration.
- **US4 / SC-004**: At 320 logical pixels and 2× text all five destinations are identifiable and reachable. Resize a window across 720 and 1000 while viewing a selected plan day or recipe. The route, selection and scroll context survive. Keyboard focus moves to the equivalent control or to a logical fallback.
- **US5 / SC-005**: On Home, open saved steps via “Kuvaj”, finish the meal, and select “Skuvano”. Observe cooked status in Home and Plan, the changed demand for that meal and any applicable pantry consumption. After the immediate undo message expires, reopen the meal detail and select “Poništi”. Repeat offline, then reconnect and verify the same final state, with no duplicate consumption or reversal. Preserve unrelated meals, manual shopping entries and later pantry counts. A failed local mark or undo leaves the prior state visible and provides a retry.
- **US6 / SC-006**: On a narrow screen at 2× text, select a date in a six-week month through the accessible day list. The correct meals appear and the last meal and fixed actions remain reachable.
- **US7 / SC-007**: With an all-cooked day, show the completion message and retain undo. With both an applicable allergen warning and a shopping notice, show the allergen warning in the single notice slot. With a failed read, show retry instead of the no-plan state.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Home is a projection of approved plan data, not another store. Shared cooked/undo operation stays in existing domain/repository boundaries; pantry and intake extend its versioned contract in 022/023.

## Exact UI copy carried forward

“Početna”, “Napravi plan”, “Kuvaj”, “Skuvano”, “Poništi”, “Dodaj u plan”,
“Prethodni”, “Sledeći”, “Izaberi dan”, “Svi današnji obroci su skuvani.”,
“Pokušaj ponovo”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: Existing baseline; no new producer feature required for the first slice.

- **Q1** (Dev 4 with reviewers): Keep the implemented `/home` route. Confirm
  consumer behavior against the shared cooked-operation contract before
  integration and resolve the manual pantry edit interaction under 022.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.

## Narrow navigation slice — 2026-11-20

Owner: Dev 4. Proposed independent reviewer: Dev 2. This covers the compact
navigation follow-up to FR-101 (D4-002/D4-003, T002–T005). The shared app
shell is coordinated by Dev 4. Dev 2 reviews changes to the Plan and Recipes
layouts. In the app, test `lib/app/home_shell.dart`,
`lib/features/planning/plan_screen.dart` and
`lib/features/recipes/recipes_screen.dart` with the matching widget tests.

- At 320 logical pixels and 2× text, all five labels are visible at system
  scale and each destination has its own at least 48×48 target. Početna stays
  centered. Existing Serbian labels are reused. The accessibility group is
  named “Glavna navigacija” and exposes the active destination.
- Keep the bottom bar below 720, the rail from 720 and the extended rail
  from 1000. Keep the rail scrollable when height is limited. Across those
  widths, preserve the tab, Plan day and scroll position, and the recipe list's
  search, focus and scroll. If focused navigation is replaced, return focus
  to the active content.
- Existing post-auth routes, private repository access and data stay unchanged.
  No dependency, schema, migration, file access, credentials, abuse surface or
  deployment change. Validate using synthetic fixtures.

Device-level keyboard and assistive technology validation follows the
[UI standard](../../docs/development/ui-standard.md). Runtime acceptance needs
independent review and a merged PR.
