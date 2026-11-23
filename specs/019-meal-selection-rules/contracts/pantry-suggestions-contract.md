# Contract: what to cook from the pantry

**Status**: implemented on `feat/cook-from-pantry` (Trello TRELLO-103),
pending review.
**Author**: Dev 2 | **Reviewer**: Dev 4 (Ostava screen, router)
**Date**: 2026-11-23 | **Builds on**: 022 `PantryRepository.whatIHave`
(FR-110, `pantryStockProvider`), [recipe search](recipe-search-contract.md)

## Function

`lib/domain/pantry_suggestions.dart`:

```dart
typedef PantryFood = ({String name, String? foodId, double? quantity});
List<PantrySuggestion> suggestFromPantry(
  Iterable<Recipe> recipes,
  Iterable<PantryFood> pantry,
);
class PantrySuggestion { Recipe recipe; int have; List<String> missing; }
bool isPantryStaple(String name);
```

- **Matching.** A recipe ingredient is "had" when its catalog `link.foodId` is among the pantry food IDs. If there is no such link, its `ingredientKey(name)` must equal a pantry name key.
- **Presence only.** Quantities are not compared, because the pantry quantity is optional (022). A pantry food with quantity `0`, used up after cooking, does not count.
- **Staples.** So, biber, ulje and voda are matched by word, so "morska so" and "maslinovo ulje" count too. They are neither had nor missing.
- **Duplicates.** The same ingredient twice in a recipe counts once.
- **Result.**
  - Only recipes with at least one had ingredient are returned.
  - Order: fewest missing, then most had, then title.
  - `missing` keeps recipe order without repeats.
- **Offline.** It runs in memory over the local drift cache and needs no network or AI.

## Screen "Šta da skuvam?"

Route `/recipes/from-pantry` (`cookFromPantryPath`), registered before `:id`.

| Entry | Where |
| --- | --- |
| Recipes, phone | Icon button (`TavliIcons.cook`, label "Šta da skuvam?") beside Filteri |
| Recipes, wide header | The same icon button beside Filteri |
| Ostava, phone | The same icon button beside the search field (shown when the pantry has items) |
| Ostava, wide header | Secondary button "Šta da skuvam?" (shown when the pantry has items) |

The canvas does not draw this screen. It is assembled from existing parts: an app bar with back, an intro text and `TavliListRow` rows. Each row has a thumbnail, the recipe title and a second line, and a tap opens the recipe with `push`, so back returns to the suggestions. The status sits in the second line rather than at the right, because a right-side label overflowed at 320 px with 2× text.

UI copy (Serbian):

| Case | Text |
| --- | --- |
| Title / entry label | Šta da skuvam? |
| Intro | Iz onoga što imaš u ostavi. So, biber, ulje i voda se ne računaju. |
| Row, nothing missing | Imaš sve · 45 min · 4 porcije |
| Row, missing | Fali 2: kore, sir · Fali 4: krompir, meso, +2 |
| Empty pantry | Ostava je prazna · Dodaj šta imaš kod kuće, pa ćemo naći recept. · button Otvori ostavu |
| No recipe uses the pantry | Nema recepta od onoga što imaš · Nijedan sačuvan recept ne koristi namirnice iz ostave. |
| Error | Predlozi trenutno nisu dostupni · Pokušaj ponovo malo kasnije. |

## Not in this slice

- The optional AI explanation from the card. It would need the network, and the rest works offline. It can come later, limited to recipes from this list.
- Quantity-aware matching ("you have 200 g, the recipe needs 500 g").

## Evidence

- `test/domain/pantry_suggestions_test.dart`: the card case with a 10-food pantry, staples, ID and name matching, recipes without a pantry ingredient, an empty or used-up pantry, duplicates, and ordering.
- `test/features/recipes/cook_from_pantry_screen_test.dart`: the flow from Recipes to a recipe and back, the empty pantry, no match, the Ostava entries on phone and wide, and 320 px and wide with 2× text without overflow.
