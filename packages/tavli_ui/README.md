# tavli_ui

Local UI library for the Tavli app: theme, palettes, tokens, platform helpers,
motion and (as the library cards land) shared components. It is a workspace
member of this repository with a path dependency, no versions and no releases.

## Design source and rules

- Build everything exactly as the canonical design canvas shows it. The canvas
  link, measurements, typography, icon style and the no-fixed-sizes rule are in
  [the UI standard](../../docs/development/ui-standard.md).
- Scope, decisions and delivery order are in
  [the UI library spec](../../specs/031-external-ui-library/spec.md).

## Using the package

- App code imports only `package:tavli_ui/tavli_ui.dart`, never `src/`;
  `scripts/check.sh` fails otherwise.
- Feature code uses tokens (`TavliSpacing`, `TavliRadius`, `TavliMotion`, palette
  colors) instead of number or color literals.

## Adding a component or token

A worked example is `TavliNextMealCard` (the highlighted next meal on Home),
added for card "UI biblioteka 13". Follow the same steps for any new piece.

1. **Find it on the canvas.** Take every measurement from the canvas artboards
   (phone and desktop) and the [UI standard](../../docs/development/ui-standard.md).
   If the canvas does not show it, stop: add it to the canvas or the feature
   spec first and get Dev 4 review. Never invent a layout.
2. **Check the catalog first.** Reuse or extend an existing component before
   adding a new one (for example `TavliMealCard` already covers Home and Plan
   meal cards). Add a variant only when the canvas shows a real difference.
3. **Pick the area and file.** `lib/src/shell/` (page frame, bars,
   navigation), `controls/` (buttons, fields, choices, rows), `content/`
   (cards, lists, notices, states), `overlays/` (dialogs, sheets, messages),
   `icons/`, `theme/`, `tokens.dart`. Export the file from `lib/tavli_ui.dart`;
   app code imports only that file.
4. **Write the API for screens, not for styling.**
   - The screen passes data (strings, lists, callbacks) and picks named
     variants (`card: true`, `wide: true`, `TavliCardVariant.highlighted`).
     No free color, size or text style parameters.
   - No business types, repositories, Riverpod or Supabase imports; map
     domain objects to plain values in the screen (`TavliUpcomingMeal`).
   - Document the canvas values in the class comment (Serbian, like the rest
     of the package), e.g. "radijus 20, razmak 18, naziv 20/800 na telefonu".
5. **Numbers live here, not in screens.** Sizes, spacing and radii from the
   canvas are written in the component or in `tokens.dart`. A value two
   screens share becomes a token (`TavliSpacing.cards`, `TavliWidth.readable`,
   `TavliColumns.meals`). Screens under `lib/features/` use tokens only;
   `scripts/check_ui_area.py` fails on raw Material widgets or number
   literals in files listed in `MIGRATED`. Counting, date and time rules are
   not UI: they go to `lib/domain/` (`countLabel`, `addWeeks`, `formatTime`).
6. **Make it responsive.** Minimum heights, never fixed heights; text wraps
   and button rows stack (`OverflowBar`, `TavliButtonRow`). Buttons in one
   row share one height (48). Check 320 px, 1200 px and 2× text. Hit areas are
   at least 48×48 and icon-only buttons need a Serbian `semanticLabel`.
7. **Colors and motion.** Take colors from `Theme.of(context).colorScheme`,
   `TavliColors` or `TavliStatusColors` so all three palettes (Bosiljak,
   Šafran, Borovnica) work in light and dark. Animate with `TavliMotion`
   durations; with reduced motion the duration is zero, so skip implicit
   size animations then (see `TavliExpandable`).
8. **Icons.** New icons are drawn in the canvas style (24 grid, stroke 2,
   round caps) as `TavliIconData` in `tavli_icons.dart` and added to
   `TavliIcons.all`; `test/icons_test.dart` checks they stay in the grid.
9. **Gallery and tests.** Add a gallery example in the matching
   `lib/src/gallery/*_sections.dart`, widget tests (behavior, semantics,
   2× text without overflow), then regenerate the golden images with
   `scripts/update-goldens.sh` (Linux container, same Flutter as CI) and
   review the changed images before committing.
10. **Use it and review.** Replace the screen code in the same PR as the first
    consumer, add the screen files to `MIGRATED`, and run
    `scripts/check.sh` and `flutter test`. All team members review PRs that
    touch this package.
