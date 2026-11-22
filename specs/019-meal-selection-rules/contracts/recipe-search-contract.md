# Contract: on-device recipe search

**Status**: first slice implemented on `feat/recipe-search-filters` (Trello
TRELLO-102), pending review.
**Author**: Dev 2 | **Reviewer**: Dev 4 (Recipes screen)
**Date**: 2026-11-20 | **Builds on**: [recipe labels](recipe-labels-contract.md)
**Consumers**: the Recipes list now; plan from saved recipes (TRELLO-45, 019
FR-007) and the pantry suggestion (TRELLO-103) later.

## Function

`lib/domain/recipe_search.dart`:

```dart
List<Recipe> searchRecipes(Iterable<Recipe> recipes, RecipeFilter filter);

class RecipeFilter {
  final String query;               // part of the title
  final MealSuitability? meal;      // recipe label
  final DishWeight? weight;         // recipe label
  final DishKind? dishKind;         // recipe label
  final int? maxPrepMinutes;        // Recipe.prepMinutes <= value
}
```

- All set conditions must match. `null` means the condition is off.
- The title match ignores case and diacritics (`cevapi` finds “Ćevapi”,
  `djuvec` finds “Đuveč”) and matches any part of the title.
- A recipe whose label or preparation time is unknown does not pass a
  condition that is on. With no condition on, every recipe is returned.
- Order is preserved; the caller sorts.

It runs in memory over recipes already read from the local drift cache, so it
works offline. The test with 500 recipes and four conditions finishes well
under 300 ms. No FTS5 index or schema change is needed at this size; revisit
only if a measured library is too slow.

## Recipes screen

A **Filteri** icon button sits next to the search field (phone) or in the page
header (wide). It opens a bottom sheet with one chip row per condition, each
with **Sve** to turn it off: **Obrok**, **Težina**, **Vrsta jela**, **Vreme
pripreme** (*Do 15 min*, *Do 30 min*, *Do 60 min*). Choices apply at once;
**Očisti filtere** turns all off and **Prikaži recepte** closes the sheet. The
button shows the selected state and reads “Filteri (N)”. With no match the
list shows “Nema recepata za izabrane filtere.” and **Očisti filtere**. The
search text and filters survive layout changes.

**Canvas patterns used** (the filter UI itself is not drawn; UI standard,
“Design source”): the button is a header icon button
(`TavliIconButton` with its selected state); the sheet is the
standard bottom sheet (`showTavliSheet`, radius 24, title and drag handle);
each condition is the filter-chip row from Nabavka (“Nedelja 1”,
“Nedelja 2”, “Ceo plan”: `TavliChoice.chips`, height 36, radius 10) under a
`TavliSectionHeader`; the actions are the paired secondary and primary
buttons from the canvas dialogs (`TavliButtonRow`). No new measurement or
token is introduced.

## Labels in the manual form

Filters only find labelled recipes. AI recipes are labelled automatically
(TRELLO-37); a manual recipe had no labels until the person opened **Izmeni
oznake**. The manual form now shows the same chips (**Oznake**: Obrok, Težina,
Vrsta jela) as the labels sheet, shared through `RecipeLabelsPicker`.

| Case | Result |
| --- | --- |
| New recipe, labels chosen | saved with source `user` |
| New recipe, nothing chosen | no labels, as before |
| Edit, labels changed | saved through `RecipeRepository.setLabels` with source `user`; not a recipe version. If only the labels changed, no version is added, so Undo is not spent on an empty change |
| Edit, labels untouched | existing labels and source stay (AI labels stay `ai`) |

Existing unlabelled recipes are not backfilled in this slice.

## Not in this slice

| Condition | Waits for |
| --- | --- |
| Contains / does not contain a catalog food | ingredient links (Dev 1, TRELLO-21) |
| Without selected allergens | allergen groups (008 member planning inputs, Dev 3) |

These add fields to `RecipeFilter`; existing callers keep working.

## Evidence

- `test/domain/recipe_search_test.dart`: each condition, all together, title
  without diacritics, unknown labels, filter state, 500 recipes under 300 ms.
- `test/features/recipes/recipes_screen_test.dart`, group *filteri*: chips
  narrow the list, empty result and clearing, title plus filter, phone and
  wide at 2× text, dark theme and reduced motion without overflow.
- `test/features/recipes/recipe_form_screen_test.dart`, group *oznake u
  ručnoj formi*: new recipe with and without labels, edit with changed and
  untouched AI labels, phone and wide at 2× text, dark theme and reduced
  motion without overflow.

## Open for design review

- The **Filteri** button and sheet are not on the canvas; they reuse the
  canvas patterns listed under Recipes screen and need Dev 4's confirmation.
  If Dev 4 wants another layout, only `recipes_screen.dart` changes;
  `searchRecipes` and `RecipeFilter` stay.
- `RecipeLabelsPicker` keeps Material `FilterChip` and `ChoiceChip` from the
  labels sheet (TRELLO-37): Tavli has no multi-select chip yet, and
  `TavliChoice.chips` cannot turn a choice off. Dev 4 decides between a
  multi-select variant in `tavli_ui` (with gallery section and golden image)
  and accepting the Material chips until then.

## Acceptance matrix (UI standard)

| Check | Result |
| --- | --- |
| Widths 320, 400, 1200 | widget tests: filter sheet and manual-form labels without overflow |
| Light/dark, text 1×/2×, reduced motion | widget tests at 2× text, dark theme, reduced motion |
| States | populated, filtered, no results with “Očisti filtere”; loading and read error unchanged from the Recipes screen |
| Desktop | Windows debug build checked by hand (filters, form labels); macOS not run |
| Not checked | keyboard focus order and screen readers (TalkBack, VoiceOver), Android, iOS and macOS devices, 719/720 and 999/1000 widths (no shell or pane change) |
