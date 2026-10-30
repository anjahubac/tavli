# Data model: Recipe screens

## Recipe (domain, existing)

Adds `copyWith`, `toJson()`/`Recipe.fromJson()` (full storage form: id, title,
servings, prepMinutes, ingredients, steps, source, imagePath, answeredBy,
createdAt ISO-8601). `fromJson` throws `FormatException` on missing title/ingredients.

## RecipeVersion (domain, new)

| Field | Type | Notes |
|---|---|---|
| id | int | row id |
| recipeId | String | |
| recipe | Recipe | state *before* the change |
| kind | ChangeKind | `ai`, `manual`, `restore` |
| instruction | String? | AI request text (kind = ai) |
| changedBy | String? | model label that made the change (kind = ai) |
| createdAt | DateTime | when the change was made |

UI labels: ai → "AI izmena", manual → "Ručna izmena", restore → "Vraćena verzija".

## Drift `RecipeVersions` (schema v3)

Existing: `id`, `recipeId` → Recipes, `recipeJson`, `instruction`, `createdAt`.
New: `changeKind TEXT NOT NULL DEFAULT 'ai'`, `changedBy TEXT NULL`.
Migration `from < 3`: `addColumn(changeKind)`, `addColumn(changedBy)`.

## Rules

- Versions per recipe ≤ 30 (oldest dropped on insert).
- Deleting a recipe deletes its versions and ratings, clears `MealPlanEntries.recipeId`, and deletes its photo file.
- `Recipes.updatedAt` is set on every change; list order is `createdAt DESC`.
