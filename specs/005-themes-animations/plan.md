# Implementation Plan: Themes and ingredient animations

**Branch**: `005-themes-animations` | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-themes-animations/spec.md`

## Summary

Replace the seed-colour theme with three hand-defined palettes ("Bosiljak",
"Šafran", "Borovnica") × light/dark. `buildTavliTheme(theme, brightness)` builds
a Material 3 `ThemeData` from an explicit `ColorScheme` plus a `TavliColors`
`ThemeExtension` (line, boxLine, tints, motif) and component themes that match
the mockup. The choice (`ThemeChoice`: theme + mode) is a pure-Dart value
stored as two rows in the existing `AppSettings` table through a small
`SettingsRepository`; a Riverpod `ThemeController` loads it at start and
`TavliApp` watches it. A new "Izgled" screen under Profil edits it.

Animations are `CustomPainter`s driven by `AnimationController`s, wrapped in a
shared `MotionLoop`/`MotionOnce` base that reads
`MediaQuery.disableAnimationsOf` and paints the static end frame instead of
ticking. They live in `lib/app/animations/` and are plugged into the intro
overlay, photo/name/chat AI waiting states, the recipes list refresh and the
Ostava/Kupovina empty tabs; the rest are shown in a debug-only gallery.

## Technical Context

**Language/Version**: Dart ≥ 3.13, Flutter 3.47
**Primary Dependencies**: existing only (flutter_riverpod, go_router, drift)
**Storage**: drift `AppSettings` (key/value) — keys `theme`, `theme_mode`; no schema change
**Testing**: flutter_test, `NativeDatabase.memory()`, `MediaQuery(disableAnimations:)` for reduced motion
**Target Platform**: Android, iOS, macOS
**Project Type**: mobile/desktop app (single Flutter project)
**Performance Goals**: animations at 60 fps with a single `CustomPaint` each; no image assets
**Constraints**: offline (font bundled); reduced motion honoured; no new packages
**Scale/Scope**: 1 theme module, 1 settings repository, 1 screen, 9 animation widgets, 1 gallery

### Assets (not a dependency)

- `assets/fonts/PlusJakartaSans-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf`
  (Google Fonts static instances, SHA-256 checked against the hashes pinned by
  the `google_fonts` package) + `OFL.txt`. Bundled instead of the `google_fonts`
  package so the font works offline and tests never fetch it.

## Constitution Check

*GATE: passed before Phase 0, re-checked after Phase 1.*

| Principle | Status |
|---|---|
| I. Serbian UI | ✅ all copy listed in the spec; semantic labels Serbian |
| II. Offline-first | ✅ choice in drift `AppSettings`, font bundled; no schema change |
| III. AI only via AIRouter | ✅ untouched; animations only wrap existing waiting states |
| IV. Secrets never committed | ✅ no keys involved |
| V. Test-first | ✅ `ThemeChoice` parsing and `SettingsRepository` tests first; widget tests for persistence, all 6 `ThemeData`, each animation incl. reduced motion |
| VI. Responsive | ✅ appearance screen and gallery constrained to 720 px; tested at phone and wide |
| VII. Small commits | ✅ spec, theme, screens restyle, animations, wiring, docs |
| VIII. One spec branch | ✅ `005-themes-animations` from latest `main` |
| IX. Best practices & guardrails | ✅ theme colours only, controllers disposed, no new dependency |

## Project Structure

### Documentation (this feature)

```text
specs/005-themes-animations/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
assets/fonts/                              Plus Jakarta Sans + OFL (new)
lib/domain/theme_choice.dart               TavliTheme, AppThemeMode, ThemeChoice (new)
lib/data/settings_repository.dart          AppSettings get/set, theme load/save (new)
lib/app/theme/tavli_palette.dart           6 palettes (tokens) (new)
lib/app/theme/tavli_colors.dart            TavliColors ThemeExtension (new)
lib/app/theme/app_theme.dart               buildTavliTheme (new)
lib/app/theme/theme_controller.dart        ThemeController Notifier (new)
lib/app/app.dart                           ConsumerWidget, theme/darkTheme/themeMode, intro overlay
lib/app/home_shell.dart                    bar with top line
lib/app/placeholder_screen.dart            + EmptyState (animated) for Ostava/Kupovina
lib/app/router.dart                        /profile/appearance, /profile/animations
lib/app/animations/motion.dart             reduced-motion aware loop/once bases (new)
lib/app/animations/intro_motif.dart        basil / saffron / blueberry painters (new)
lib/app/animations/intro_overlay.dart      launch intro (new)
lib/app/animations/photo_scan.dart         scan line + chips (new)
lib/app/animations/simmering_pot.dart      pot, steam, bubbles, rotating messages (new)
lib/app/animations/ingredient_check.dart   AnimatedCheckmark, flyChipToTarget, BumpBadge (new)
lib/app/animations/shopping_bag.dart       bag fills, bread peeks (new)
lib/app/animations/empty_fridge.dart       door opens, light flickers (new)
lib/app/animations/spoon_refresh.dart      SpoonRefresh (RefreshIndicator.noSpinner) (new)
lib/app/animations/plate_drop.dart         recipe lands on a plate (new)
lib/app/animations/egg_timer.dart          egg bobbing in boiling water (new)
lib/features/settings/appearance_screen.dart  "Izgled" (new)
lib/features/settings/animations_gallery_screen.dart  debug gallery (new)
lib/features/settings/profile_screen.dart  + Izgled, + Animacije (debug)
lib/features/recipes/*                     theme tokens, card tiles, AiBusy pot, photo scan, spoon refresh
test/domain/theme_choice_test.dart
test/data/settings_repository_test.dart
test/app/theme_test.dart                   6 ThemeData combos, tokens
test/features/appearance_screen_test.dart  choose + persist + restore
test/app/animations_test.dart              each animation: label, runs, static with reduced motion
```

**Structure Decision**: shared animation widgets sit in `lib/app/animations/`
because several features (recipes, shopping, pantry, plan) use them.

## Complexity Tracking

None.

## Owner revision — 2026-11-02

Integrate current main without replacing auth lifecycle or sync. Refine the existing palette and typography, add responsive recipe previews, serialize theme saves with rollback and Serbian feedback. No new dependencies or schema changes. Add regression tests for default/saved/system modes, failed and overlapping saves, 320 px at 2× text, all six palette contrasts, auth screens and account-scoped shopping/outbox after the existing v4 migration.

### Native startup regression

A local cache with the v4 structure but user_version 3 can result from opening it with an older app. Reopening must preserve UUIDs, ownership, profile ids and pending outbox references; reapplying the upgrade must not recreate an existing index. Detect already-migrated columns and wrap the upgrade in a transaction. No schema change, no dependency, no user data reset. Cover with a real temporary SQLite file and rerun all checks/build.


## UX refinement — 2026-11-02

Reuse the current branch and dependency set. Centralise short motion durations;
show IntroScreen only during real auth startup; remove refresh delay. Commit
shopping demo changes immediately, serialize interactions, then show an accessible
batch confirmation. Add a separate semantic status ThemeExtension and apply it
to ingredient/success feedback. Simplify nested preview borders, clarify empty
states and screen-on icon. Preserve data/schema/auth/sync contracts. Reduced
motion must stop active feedback; TickerMode pauses message timers. Add targeted
widget regressions, six-theme status contrast checks, phone/wide/2× visual QA,
then scripts/check.sh and macOS debug build. No new dependencies.

Constitution I–IX: Serbian copy above; no new user-data writes or schema changes;
AI routing untouched; no secrets; key flows covered by widgets; responsive checks;
scoped change on existing 005 branch; existing lints and checks retained.
