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

1. Find it on the canvas and take its measurements from the UI standard. If the
   canvas does not show it, add it there or to the feature spec first and get
   Dev 4 review.
2. Put it under `lib/src/<area>/` and export it from `lib/tavli_ui.dart`.
3. No business data, repositories or Supabase imports; the screen passes data in.
   No free style or color parameters; variants are named.
4. Use minimum heights, never fixed sizes; check 320 px, 1200 px and 2× text.
   Hit areas are at least 48×48 and icon-only buttons have a Serbian label.
5. Add light/dark values for all three palettes (Bosiljak, Šafran, Borovnica).
6. Add widget tests and, once the gallery exists, a gallery section and golden
   images (compared on Linux as in CI).
7. All team members review PRs that touch this package.
