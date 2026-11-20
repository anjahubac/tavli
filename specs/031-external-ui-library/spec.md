# Specification: Tavli UI component library (local package)

**ID**: 031-external-ui-library (directory name kept for existing links) | **Feature key**: UI-PACKAGE
**Created**: 2026-11-14 | **Revised**: 2026-11-19 (team decision: one repository)
**Status**: In progress; delivered card by card in the order below.
**Lead**: Dev 4 | **Reviewers**: all team members review PRs that touch `packages/tavli_ui`

## Scope and source

Implements the UI-PACKAGE portion of the [accepted product plan](../../docs/product-plan.md).
The visual source is the canonical design canvas linked from the
[UI standard](../../docs/development/ui-standard.md); this library is how the app
reaches that design, not a redesign of a released look. Existing behavior is
documented in [architecture](../../docs/architecture.md). Preserve inherited 010
quantity, snapshot, offline and account invariants.

## Decisions (2026-11-19)

- **D1 One repository**: the library is the local package `packages/tavli_ui`
  in this repository, a path dependency. No separate repository, version numbers
  or releases. A component and the screen that first uses it may land in one PR.
- **D2 Checks**: the existing `scripts/check.sh`, pre-commit hook and CI cover
  the package. App code imports only `package:tavli_ui/tavli_ui.dart`.
- **D3 Gallery**: debug-only screen Profil > Komponente (route `/components`),
  reachable without sign-in in debug builds; release builds do not register it.
  Every component adds a gallery section and golden images.
- **D4 Look**: one branded look on Android, iOS, macOS and Windows as drawn on
  the canvas, with native behavior through `TavliPlatform` (Apple dialogs and
  action sheets, context menus, shortcuts, hover, density, desktop menu bar).
  No `macos_ui` or `fluent_ui`. Components take no free style or color
  parameters.
- **D5 Parallel work**: phases 1–2 run in parallel with meal plan work.
- **D6 Canvas over the earlier standard** (Anja): where the two differed, the
  canvas wins. A secondary button stays 48 high beside a 56 primary button
  ("Skuvano" beside "Kuvaj"), button labels are 15/700, and the checkbox radius
  is 6.

## Delivery order (Trello "UI biblioteka 1–14")

| Phase | Cards |
| --- | --- |
| 1 Foundation | 1 package and theme; 2 gallery and checks |
| 2 Base components | 3 shell and navigation; 4 buttons, fields and choices; 5 cards, lists and notices; 6 dialogs and a trial move of sign-in |
| 3 Screen moves | 7 Account; 8 Recipes; 9 Nabavka; 10 Plan |
| 4 Apple | 11 Apple behavior |
| 5 Windows | 12 Windows look |
| 6 Polish | 13 polish; 14 component tracker |

Local shell adoption follows the [021 priorities](../021-home-and-cooking/plan.md#priority-delivery). The gallery already exists on dev ([#71](https://github.com/anjahubac/tavli/pull/71)).

## Requirements and source traceability

- **FR-001**: Deliver **the Tavli UI package** (source D4-024; Dev 4; originally
  phase 4, started 2026-11-19 by team decision). Completion must satisfy the
  behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Components match the canvas exactly (measurements, typography,
  colors, icon style) as recorded in the UI standard; deviations are listed in
  the PR.
- **FR-102**: No fixed sizes: layout widths come from available space, control
  heights are minimums, and every component works at 320 px, 1200 px and 2× text.
- **FR-103**: Preserve light/dark for all three palettes, reduced motion, focus
  and semantics, and 48×48 hit areas.
- **FR-104**: The package exports one Tavli icon set in the canvas style; screens
  stop referencing Material `Icons` directly as they move to the library.
- **FR-105**: Components hold no business data, repositories or Supabase
  dependencies; screens pass data in.
- **FR-106**: Each screen move replaces its widgets with library components one
  screen per PR, keeping behavior and tests.

## User scenarios and acceptance

- **US1 / SC-001**: A component renders the same in the gallery and in the app,
  matches its canvas board, and passes golden tests for each palette, light/dark
  and 2× text.
- **US2 / SC-002**: A moved screen keeps its routes, behavior and tests, and its
  PR shows the canvas comparison and the UI standard acceptance matrix.

## Data and privacy

No business data or Supabase dependencies in reusable visual components.

## Exact UI copy carried forward

Gallery copy is Serbian Latin. Screen copy follows the canvas and each feature spec.

## Dependencies and open decisions

Producer specs: [021](../021-home-and-cooking/spec.md) for the Home screen route.

- **Q1** (Dev 4): source of the icon set: drawn in-house to the canvas geometry,
  or an open-source outline set with the same geometry (licence recorded).
