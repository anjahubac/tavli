# Research: Recipe screens

## R1. Photo downscaling

- **Decision**: `image` package, `decodeImage` → `copyResize` (longest side 1600 px) → `encodeJpg(quality: 85)`, run with `compute` (isolate).
- **Rationale**: `image_picker` resize options are ignored on macOS; one code path on all platforms; testable in plain Dart tests. 1600 px keeps handwritten text legible for vision models and is ≈ 300–700 KB.
- **Alternatives**: `flutter_image_compress` (native plugin per platform, harder to test); `dart:ui` codec (can resize but only encodes PNG — large files).

## R2. Where photos live

- **Decision**: files in `<applicationDocuments>/recipe_photos/<id>.jpg`; the DB stores the relative path `recipe_photos/<id>.jpg`.
- **Rationale**: iOS changes the container path between installs/updates; relative paths survive. Files keep the DB small (best practices §6).
- **Alternatives**: BLOB column (bloats DB, slower list queries).

## R3. Version model

- **Decision**: a version row stores the *previous* recipe state plus the change that replaced it (`changeKind` ai/manual/restore, `instruction`, `changedBy`). Undo = apply newest version and delete it. Restore = save current as `restore` version, apply chosen one. Keep 30 newest.
- **Rationale**: one row per change, history and undo come from the same table; restore stays undoable.
- **Alternatives**: store every *new* state (needs the initial state too, duplicates the `Recipes` row); separate chat table (duplicates instruction data).

## R4. Schema change

- **Decision**: add `change_kind TEXT NOT NULL DEFAULT 'ai'` and `changed_by TEXT NULL` via `m.addColumn` (v3).
- **Rationale**: table is unused before this feature; adding columns keeps any rows.

## R5. Search

- **Decision**: watch all recipes (newest first) and filter in memory with a normalised title (lowercase, č/ć→c, š→s, ž→z, đ→dj).
- **Rationale**: SQLite `LIKE` cannot fold Serbian diacritics; a personal collection is hundreds of rows.

## R6. List–detail on wide windows

- **Decision**: `/recipes/:id` renders the split view (list + detail) when the content area is ≥ 840 px wide, without a transition; on narrower screens it renders the full-screen detail. The list's app bar never shows a back button.
- **Rationale**: one route per recipe works for both layouts and for "open after save".

## R7. Camera availability

- **Decision**: `PhotoPicker.canUseCamera` = `ImagePicker().supportsImageSource(ImageSource.camera)`; hide "Slikaj" when false (macOS).
