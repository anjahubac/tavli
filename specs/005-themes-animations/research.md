# Research: Themes and ingredient animations

## Explicit ColorScheme vs fromSeed

- **Decision**: build `ColorScheme` by hand from the approved tokens; derive the
  roles the mockup does not define (secondary/tertiary = primary family,
  surfaceContainer* = mixes of bg and surface, error = Material defaults).
- **Why**: `fromSeed` shifts the approved hues; the owner approved exact colours.

## Where the extra tokens live

- **Decision**: `TavliColors extends ThemeExtension` with `line`, `boxLine`,
  `tints` (3), `motif` (`TavliTheme`). `outlineVariant` = line and
  `outline` = boxLine are also set on the `ColorScheme`, so Material widgets use
  them without the extension.

## Persistence

- **Decision**: existing drift `AppSettings` key/value table, keys `theme`
  (`bosiljak|safran|borovnica`) and `theme_mode` (`light|dark|system`).
- **Alternatives**: `shared_preferences` (new dependency, second store) — rejected.

## Font

- **Decision**: bundle five static Plus Jakarta Sans weights (OFL).
- **Alternatives**: `google_fonts` runtime fetching — breaks offline first run
  and throws in widget tests unless every test disables fetching.

## Reduced motion

- **Decision**: `MediaQuery.disableAnimationsOf(context)` (iOS "Reduce Motion",
  Android "Remove animations", macOS "Reduce motion"). Each animation exposes its
  end frame (`t = 1` or a chosen rest frame) and never starts its controller.

## Custom pull-to-refresh

- **Decision**: `RefreshIndicator.noSpinner` + `onStatusChange` gives drag/armed/
  refresh/done states without the Material spinner; a `SpoonPot` painter is
  stacked at the top while a status is active. No package needed.

## Branch base

- **Decision**: branch from the latest `origin/main` (git rules in `AGENTS.md`);
  it includes the recipe screens and the AI keys list.

## Tests and endless animations

- Looping animations keep `pumpAndSettle` from finishing. Widget tests that
  hold a waiting state use `pump(duration)`; the intro is off in
  `pumpTavli` (`TavliApp(intro: false)`) and covered by its own test.
