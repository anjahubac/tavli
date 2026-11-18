# Contract: AI response shapes `recipe.v1`, `plan-outline.v1`, `recipe-summary.v1`

**Status**: Draft (proposal for Q1) | **Spec**: [014](../spec.md), FR-001 / D2-001, Trello #33
**Producer / consumer / reviewer**: producer is the AI model behind `AIRouter`
(prompts in `lib/ai/`); consumers are `RecipeAI`, `MealPlanAI`, recipe review
screens, plan preview and, through saved snapshots, shopping. Lead Dev 2;
reviewers Dev 1 (catalog, units, shopping) and Dev 4 (app shell, pantry).

## Scope and existing behavior

This document fixes the JSON the app accepts from an AI model. It is the input
for #34 (strict validation, FR-002) and #40 (catalog matching). It adds no
runtime code, migration or sync change.

Current code (dev `928d655`):

| Shape | Prompt | Parser | Current gaps |
| --- | --- | --- | --- |
| `recipe.v1` | `lib/ai/prompts.dart` | `Recipe.fromAiJson`, `Ingredient.fromJson` (`lib/domain/recipe.dart`) | missing or bad `servings` silently becomes `2`; `quantity` accepts `"1/2"`, `"0,5"` and negative numbers; negative `prepMinutes` kept |
| `plan-outline.v1` | `planOutlinePrompt` (`lib/ai/meal_plan_prompts.dart`) | `parseOutline` (`lib/ai/meal_plan_ai.dart`) | already strict; this contract records it |
| `recipe-summary.v1` | `recipeSummariesPrompt` | `parseSummaries` | `servings` strict 1–20; ingredients share the recipe gaps |

**Shared readers (must not change behavior).** `Ingredient.fromJson` and
`Recipe.fromAiJson` also read data that is *not* an AI response:

- `Recipe.fromJson` → `Recipe.fromAiJson` for saved recipe versions
  (`lib/data/recipe_repository.dart:307`);
- `ingredients_json` of saved recipes (`lib/data/recipe_repository.dart:291`);
- recipe snapshots of shopping sources (`lib/domain/shopping_source.dart:55`);
- the manual ingredient dialog, which deliberately accepts `"0,5"` and `"1/2"`
  (`lib/features/recipes/recipe_form_screen.dart:338`);
- manual recipes allow 1–99 servings (`recipe_form_screen.dart:104`) and the
  `recipes.servings` column only requires `> 0`.

Therefore the rules below apply **only at the AI boundary**, as a validation
step before the existing readers. They must never be applied to stored rows,
synced snapshots or manual input; otherwise saved recipes would fail to load.

Out of scope: food identity (`food_id`) and catalog matching (#20/#40, Dev 1),
unit conversion factors (measure contract, spec 017, #23/#100, Dev 1), recipe
labels (see Decisions), retry policy (FR-003, #42) and the nutritionist plan
import shape (#52/#53: grams per item, “Proveri” flags, alternatives), which
gets its own versioned shape with #52 and reuses R5–R9 for its items.

Fixtures are plain JSON so the planned AI gateway (#36) can run the same cases
if validation also moves server-side.

## Interface

### Common rules

| ID | Rule |
| --- | --- |
| C1 | The response is one JSON object. Anything else is rejected. |
| C2 | Unknown fields are ignored, at every level. |
| C3 | Strings are trimmed. An optional string that is blank after trimming becomes `null`. |
| C4 | "Integer" means a JSON number without a fractional part (`4` and `4.0` pass, `4.5` and `"4"` fail). |
| C5 | Any rejection rejects the whole response (`FormatException`); nothing is saved or partly applied. The router may then retry (FR-003, #42); the rule ID gives the repair prompt a precise error description. |
| C7 | This contract covers shape only. Semantic plan rules applied after a valid response (meal-slot rules #39, allergens #43, candidate filtering #45) are a separate step and may re-request a single slot; they never relax these rules. |
| C6 | The version (`recipe.v1`, …) is known by the client from the prompt it sent; the model does not return it. |

Field classes: **strict** fields drive calculation or placement and reject on a
bad value; **fallback** fields are display-only or closed lists where a bad
value is harmless, so it is replaced by a safe value; **open** fields accept any
text and reject only on structure (wrong type, blank, too long).

### `recipe.v1` (create from photo, create from dish name, refine)

```jsonc
{
  "title": "Sarma",
  "servings": 6,
  "prepMinutes": 180,
  "ingredients": [
    {"name": "kiseli kupus", "quantity": 1, "unit": "glavica",
     "category": "konzerve i tegle", "note": null}
  ],
  "steps": ["Umotati sarme.", "Kuvati 3 sata."]
}
```

| ID | Field | Class | Accepted | Bad value → |
| --- | --- | --- | --- | --- |
| R1 | `title` | open | string, 1–120 characters | reject |
| R2 | `servings` | strict | integer 1–99 (matches manual recipes) | reject, including missing |
| R3 | `prepMinutes` | fallback | number > 0, rounded to integer; no upper bound (dough may rest 48 h) | `null`, never reject |
| R4 | `ingredients` | strict | list of 1–60 objects | reject |
| R5 | `ingredients[].name` | open | string, 1–80 characters, base name without quantity; preparation goes to `note` | reject |
| R6 | `ingredients[].quantity` | strict | number > 0, or `null`/missing ("po ukusu") | reject: `0`, negative, any string (`"1/2"`, `"0,5"`, `"malo"`) |
| R7 | `ingredients[].unit` | open + vocabulary | string ≤ 30 characters or `null`; matched against the unit vocabulary below | wrong type or too long → reject; unknown text → kept, marked unknown |
| R8 | `ingredients[].category` | fallback | one of `ingredientCategories` (`lib/domain/recipe.dart`) | `ostalo` |
| R9 | `ingredients[].note` | open | string ≤ 200 characters or `null` | wrong type or too long → reject |
| R10 | `steps` | open | list of strings, ≤ 40 items, each ≤ 1000 characters, blank items dropped, no numbering; missing or `null` → `[]` (summary recipe) | not a list, non-string item, too many or too long → reject |
| R11 | error object | — | `{"error": "not_a_recipe"}` from photo import only | outcome *not a recipe* (Serbian message), not a format error |

### `plan-outline.v1`

The client sends the slots to fill (`date` + `meal`) and a library of
`{id, title}`; the model returns one dish per slot.

```jsonc
{"meals": [
  {"date": "2026-11-17", "meal": "lunch", "recipeId": "r-123", "title": "Sarma"},
  {"date": "2026-11-17", "meal": "dinner", "recipeId": null, "title": "Pasulj"}
]}
```

| ID | Rule | Bad value → |
| --- | --- | --- |
| P1 | `meals` is a list of objects | reject |
| P2 | `date` is `YYYY-MM-DD` (a `CivilDate`, no time or zone) and `meal` is a `MealType` name; the pair must be one of the **requested** slots | reject |
| P3 | every requested slot appears exactly once; no extra, missing or repeated slot | reject |
| P4 | `recipeId` is `null` or an id from the sent library; for a library id the library title is used and the model's `title` is ignored | unknown id → reject |
| P5 | for `recipeId: null`, `title` follows R1 | reject |

`meal` values: `breakfast`, `morningSnack`, `lunch`, `afternoonSnack`,
`dinner` (`MealType`, day order). The two snacks were added by TRELLO-38
(2026-11-18) as an additive change: P2 only accepts requested slots, so a
prompt without snack slots never receives one.

### `recipe-summary.v1`

Summaries for new dishes from the outline (title and ingredients, no steps).

```jsonc
{"recipes": [
  {"title": "Pasulj", "servings": 4, "prepMinutes": 120,
   "ingredients": [{"name": "pasulj", "quantity": 500, "unit": "g",
                    "category": "suvi proizvodi", "note": null}]}
]}
```

| ID | Rule | Bad value → |
| --- | --- | --- |
| S1 | `recipes` is a list; each `title` matches a requested title (same `draftRecipeKey`) exactly once; no extra, missing or repeated recipe | reject |
| S2 | `servings` is an integer 1–20 (`minServings`/`maxServings`) | reject |
| S3 | `prepMinutes` follows R3; `ingredients` follow R4–R9; `steps` is ignored | as referenced |

### Unit vocabulary

Matching is case-insensitive after trimming, with listed plural and abbreviated
forms. The canonical form is stored next to the original text; the original is
never discarded. Factors for kitchen measures come from the measure contract
(spec 017, Dev 1) and are approximate.

| Dimension | Canonical | Also matches | Base amount |
| --- | --- | --- | --- |
| mass | `g`, `dkg`, `kg` | `gr`, `grama`, `kilogram` | 1, 10, 1000 g |
| volume | `ml`, `dl`, `l` | `mililitar`, `litar`, `litra` | 1, 100, 1000 ml |
| kitchen measure (≈) | `kašičica`, `kašika`, `čaša`, `šolja` | `kašičice`, `kašike`, `čaše`, `šolje` | ≈ 5, 15, 200, 250 ml |
| piece | `kom`, `glavica`, `čen`, `veza` | `kom.`, `komad`, `komada`, `glavice`, `čena`, `vezica` | count of that piece |
| package | `pakovanje`, `kesica`, `konzerva`, `tegla` | plural forms | count, not convertible |
| no measure | `prstohvat`, `null` | — | not summed |

An unknown unit is **accepted, kept and marked unknown**; shopping then shows
“Proveri količinu” instead of guessing (`docs/product-design.md`). Adding a unit
to the vocabulary never breaks stored data.

## State transitions

None. A validated response is still an unsaved draft: the user reviews it
(“Proveri predlog”) before anything is written, synced or added to shopping.
Rejection leaves local data, outbox and plan unchanged.

## Compatibility and tests

- This contract changes no prompt or parser. #34 implements it in one slice:
  the prompt schemas in `lib/ai/prompts.dart` and `lib/ai/meal_plan_prompts.dart`
  are aligned with these rules (integer servings, numeric quantity, unit
  vocabulary) together with the AI-boundary validator, so the model is asked
  for exactly what the validator accepts.
- No migration and no sync change: accepted values are a subset of what the
  existing columns and snapshots already store.
- Existing data: the local development database had no recipes or plans on
  2026-11-16. The hosted database was not inspected (project policy forbids
  calling it from scripts). Saved rows may hold anything the lenient readers
  accepted (for example servings up to 99, quantities from `"1/2"`), which is
  why these rules stay at the AI boundary only.
- Tests that encode today's lenient AI behavior and will change with #34:
  `test/domain/recipe_test.dart` (`"0,5"`, `"1/2"` and default servings `2`
  through `Recipe.fromAiJson`). They must move to the manual/stored reader or
  become rejection cases; they are not weakened.
- Acceptance fixtures: [fixtures/](fixtures/). Each file names the contract,
  the expected outcome (`accept`, `reject`, `not_a_recipe`), the rule and a
  reason; accepted fixtures list expected normalized values. #34 runs all of
  them through the validator.

## Decisions

| # | Question | Proposal | Owner |
| --- | --- | --- | --- |
| D1 | Contract format | Markdown plus JSON fixtures; no shared code until #34 | Dev 2 |
| D2 | Recipe `servings` bound | 1–99 for `recipe.v1` (same as manual recipes, so refining a saved recipe never fails); summaries keep 1–20 | Dev 2, review Dev 1 |
| D3 | Unknown unit | accepted and marked unknown, never rejected; card #34 says "nepoznata jedinica nikad ne stiže do baze" — propose product design wins | Dev 1 + Dev 2 |
| D4 | Recipe labels (#37: suitable meals, weight lagan/srednji/jak, dish type) | not in v1; #37 adds them as optional fields, which C2 makes backward compatible. They are fallback fields: an unknown value becomes `null` and the user edits it on the recipe; #39 must treat `null` as unknown, not as a rule violation | Dev 2 |
| D5 | Meal types | v1 has three; snacks arrive with #38 as an additive change | Dev 2, review Dev 4 |
| D6 | Food identity | no `food_id` in AI output; matching belongs to #40 | Dev 1 |

Accepted revision: pending approval by Dev 1 and Dev 4 on the #33 pull request.
