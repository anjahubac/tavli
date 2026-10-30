# Implementation Plan: Recipe screens

**Branch**: `003-recipe-screens` | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-recipe-screens/spec.md`

## Summary

Replace the "Recepti" placeholder with a list (search, newest first, empty
state), a detail screen, three ways to add a recipe (dish name, photo, manual),
an AI chat that proposes changes, and version history with undo/restore.
Persistence goes through a new `RecipeRepository` over the existing drift
`Recipes`/`RecipeVersions` tables; `RecipeVersions` gains `changeKind` and
`changedBy` (schema v3). Photos are downscaled to JPEG (≤ 1600 px, q85) in an
isolate and stored under the app documents directory, referenced by a relative
path. AI goes through the existing `RecipeAI` (`fromDishName`, `fromImage`,
`refine`) and therefore `AIRouter`. Wide windows show list and detail side by side.

## Technical Context

**Language/Version**: Dart ≥ 3.13, Flutter
**Primary Dependencies**: existing (flutter_riverpod, go_router, drift, image_picker, path_provider) + `image` (new, see below)
**Storage**: drift — `RecipeVersions` + `changeKind`, `changedBy`; `schemaVersion` 2 → 3. Photo files in `<documents>/recipe_photos/`
**Testing**: flutter_test; `NativeDatabase.memory()`, `FakeAdapter` for AI, fake `PhotoPicker`, temp-dir photo store
**Target Platform**: Android, iOS, macOS
**Project Type**: mobile/desktop app (single Flutter project)
**Performance Goals**: search filters 500 recipes per keystroke without jank (in-memory filter on a stream of rows)
**Constraints**: offline for everything except AI; stored photo ≲ 1 MB; no recipe content in logs
**Scale/Scope**: 7 screens/sheets, 1 repository, 1 schema bump

### New dependency

- `image` — pure-Dart JPEG decode/resize/encode; `image_picker` ignores `maxWidth`/`imageQuality` on macOS, and Flutter cannot encode JPEG itself.

## Constitution Check

*GATE: passed before Phase 0, re-checked after Phase 1.*

| Principle | Status |
|---|---|
| I. Serbian UI | ✅ all copy listed in the spec (quoted strings) |
| II. Offline-first | ✅ recipes, versions and photos local; schema v3 with migration + test |
| III. AI only via AIRouter | ✅ screens call `RecipeAI` only; errors via `aiErrorText` |
| IV. Secrets never committed | ✅ tests use fake built-in keys (`BuiltInKeys` override) and `InMemoryKeyStore` |
| V. Test-first | ✅ domain formatting/search/JSON, repository, migration, resize tested first; widget tests per flow |
| VI. Responsive | ✅ list–detail ≥ 840 px content width; widget tests at 400×800 and 1200×800 |
| VII. Small commits | ✅ commit per phase (domain, data, list/detail, AI add, chat, manual) |
| VIII. One spec branch | ✅ `003-recipe-screens` |
| IX. Best practices & guardrails | ✅ one justified dependency, migration + test, check.sh before commits |

## Project Structure

### Documentation (this feature)

```text
specs/003-recipe-screens/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/recipe-repository.md
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
lib/domain/recipe.dart                   + copyWith, toJson/fromJson (storage), newRecipeId
lib/domain/recipe_version.dart           RecipeVersion, ChangeKind (new)
lib/domain/recipe_format.dart            formatQuantity, groupByCategory, matchesQuery, formatDateTime (new)
lib/ai/recipe_ai.dart                    uses newRecipeId
lib/data/database.dart                   RecipeVersions.changeKind/changedBy, schema v3
lib/data/recipe_repository.dart          RecipeRepository (new)
lib/data/recipe_photo_store.dart         RecipePhotoStore (new)
lib/data/photo_resize.dart               downscaleToJpeg (new)
lib/features/recipes/recipe_providers.dart  repository, streams, photo picker/store providers
lib/features/recipes/photo_picker.dart   PhotoPicker interface + image_picker impl
lib/features/recipes/recipes_screen.dart list + search + wide split
lib/features/recipes/recipe_detail_screen.dart
lib/features/recipes/recipe_view.dart    shared recipe body (detail, previews, proposals)
lib/features/recipes/recipe_photo.dart   photo/thumbnail widget
lib/features/recipes/add_recipe_sheet.dart
lib/features/recipes/from_name_screen.dart
lib/features/recipes/from_photo_screen.dart
lib/features/recipes/ai_preview.dart     preview + Sačuvaj/Pokušaj ponovo/Odbaci
lib/features/recipes/recipe_form_screen.dart  manual add/edit + ingredient dialog
lib/features/recipes/recipe_chat_screen.dart
lib/features/recipes/versions_sheet.dart
lib/app/router.dart                      recipe routes
test/domain/recipe_format_test.dart, test/domain/recipe_test.dart (+)
test/data/recipe_repository_test.dart, test/data/migration_test.dart, test/data/photo_resize_test.dart
test/features/recipes/*_test.dart, test/helpers/test_app.dart
```

**Structure Decision**: single Flutter project; new `features/recipes/`, data access in `lib/data/`, pure logic in `lib/domain/`.

## Complexity Tracking

None.
