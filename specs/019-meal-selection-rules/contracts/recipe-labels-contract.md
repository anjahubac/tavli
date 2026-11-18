# Contract: recipe labels (meal suitability, weight, dish kind)

**Status**: proposal for review (Trello #37, spec 019 FR-001, Q1 for labels).
Nothing here is implemented yet.
**Author**: Dev 2 | **Reviewers**: Dev 1 (drift version, `lib/sync/entities.dart`,
server table), Dev 3 (spec 019 reviewer)
**Date**: 2026-11-18 | **Builds on**: [AI response contract](../../014-ai-response-contracts/contracts/ai-response-contract.md)
decision D4 (labels are optional fallback fields)

## Purpose

The plan rules (#39), the saved-recipe planner (#45) and recipe filters (#102)
need to know what a recipe is for. Each recipe gets three labels from closed
lists. AI fills them for new recipes, existing recipes are labelled once, and
the user can correct them on the recipe screen.

## Labels

| Label | Wire field (server / AI) | Values (wire → UI) | Cardinality |
| --- | --- | --- | --- |
| Suitable meals | `meal_types` / `meals` | `breakfast` Doručak, `snack` Užina, `lunch` Ručak, `dinner` Večera | 1–4 distinct values; “može više” means several are selected |
| Weight | `weight` / `weight` | `light` Lagan, `medium` Srednji, `hearty` Jak | one |
| Dish kind | `dish_kind` / `dishKind` | see Dish kinds below | one |

### Dish kinds

| Wire | UI | Examples |
| --- | --- | --- |
| `soup` | Čorba ili supa | pileća supa, teleća čorba |
| `cooked` | Kuvano jelo | pasulj, sarma, gulaš, rižoto |
| `baked_fried` | Pečeno ili prženo | musaka, piletina iz rerne, ćevapi, riba |
| `pasta` | Testenina | špagete, lazanje |
| `salad` | Salata | šopska, salata sa tunjevinom |
| `pie_pizza_sandwich` | Pita, pica ili sendvič | gibanica, pica, tost |
| `eggs_breakfast` | Jaja i doručak | kajgana, omlet, kaša |
| `cold` | Hladno jelo | namazi, hladna plata |
| `sweet` | Slatko | palačinke, kolač |

“Pečenje” alone was avoided because in Serbian it means a roast of lamb or
pork; the label covers oven, grill and pan.

`null` means **unknown**, never a rule violation (014 D4, spec 019 US3). Both
snack slots from #38 (“Užina pre podne”, “Užina posle podne”) use `snack`.

A fourth field, `labels_source` (`ai` | `user`, `null` = not labelled yet), says
who set the labels. AI never overwrites labels whose source is `user`.

## AI response (`recipe.v1`, additive)

`recipe.v1` and `recipe-summary.v1` get three optional fields. Under 014 C2 old
responses without them stay valid.

```jsonc
{
  "title": "Pasulj prebranac",
  "meals": ["lunch", "dinner"],
  "weight": "hearty",
  "dishKind": "cooked",
  // … existing recipe.v1 fields
}
```

| ID | Rule (lenient, never rejects the recipe) |
| --- | --- |
| L1 | `meals`: keep known values (trimmed, lowercase), drop unknown ones and duplicates; empty list or missing → `null`. |
| L2 | `weight`: a known value, otherwise `null`. |
| L3 | `dishKind`: a known value, otherwise `null`. |

The rules live next to R1–R10 in `lib/ai/ai_response_validator.dart` (#34).
Prompts (`lib/ai/prompts.dart`, `lib/ai/meal_plan_prompts.dart`) list the
values with one-line definitions, e.g. “hearty: a main meal that fills you up
(pasulj, sarma, pečenje)”.

## Labelling existing recipes (one pass)

- A recipe needs labels when `labels_source` is `null`: recipes saved before
  #37, manual recipes and AI recipes whose labels all came back `null`.
- After a successful download sync, when AI is available, the device sends up
  to 20 such recipes per request: id, title and ingredient names only (no
  steps, photos or notes). New text task `recipe_labels`, added to the gateway
  task list of the 015 gateway contract (PR #47) once that contract is merged.
- Response `{"labels": [{"id": "…", "meals": […], "weight": "…", "dishKind": "…"}]}`
  with L1–L3 per item. Ids not in the request are ignored, missing ids stay
  unlabelled.
- Each result is written through `RecipeRepository` (row + outbox, one
  transaction) with `labels_source = ai`, only if the row still has
  `labels_source = null` at write time, so a user edit made in between wins.
- Failure or no AI: nothing changes; the pass retries after the next sync, at
  most once a day per device (device setting, not synced). Two devices of one
  household labelling at once is harmless: both write `ai` labels, last write
  wins, a `user` label is never touched.

## Editing on the recipe screen

`lib/features/recipes/recipe_detail_screen.dart` shows a section **Oznake**
with the three labels, or “Nije označeno” for unknown. **Izmeni oznake** opens
a sheet: meals as multi-select chips, weight and dish kind as single-choice
chips, **Sačuvaj** and **Otkaži**. Saving sets `labels_source = user` and goes
through the outbox like any recipe edit. Works offline.

UI copy (new): “Oznake”, “Obrok”, “Težina”, “Vrsta jela”, “Nije označeno”,
“Izmeni oznake”, plus the value labels in the table above.

Refining a recipe with AI (`RecipeAI.refine`) may change labels only when
`labels_source` is not `user`. Restoring an older version keeps the current
labels; labels are not part of version history.

## Data

### Local (drift, Dev 1 coordinates the version)

`Recipes` gets four nullable text columns: `mealTypesJson` (JSON list as sent
by the server), `weight`, `dishKind`, `labelsSource`. `schemaVersion` goes up
by one (the next free number when the slice merges), with `m.addColumn` steps
and a case in `test/data/migration_test.dart`. Existing rows get `null`.

The columns keep the **raw server value**. The domain parses it for display;
a value this client does not know is shown as “Nije označeno” but is sent back
unchanged, so an older client cannot erase a label added by a newer one.

### Server (new migration file, never an edit of an applied one)

```sql
alter table public.recipes
  add column meal_types text[] check (
    meal_types is null or (
      cardinality(meal_types) between 1 and 4
      and meal_types <@ array['breakfast', 'snack', 'lunch', 'dinner'])),
  add column weight text check (weight in ('light', 'medium', 'hearty')),
  add column dish_kind text check (dish_kind in
    ('soup', 'cooked', 'baked_fried', 'pasta', 'salad', 'pie_pizza_sandwich',
     'eggs_breakfast', 'cold', 'sweet')),
  add column labels_source text check (labels_source in ('ai', 'user'));
```

RLS policies and the table-level grant on `public.recipes` already cover new
columns; no new grant. `delete_account_data` is unchanged (whole rows). A
pgTAP test checks that a member can set labels, that an unknown value is
rejected, and that another household still cannot update the row.

`RecipeEntity` (`lib/sync/entities.dart`, Dev 1) maps the four columns both
ways. Shopping snapshots (`shopping_source.dart`) do not change.

### Compatibility

| Case | Result |
| --- | --- |
| Old client edits a labelled recipe | Its upsert sends no label columns; PostgREST updates only sent columns, so labels stay. Covered by a fake-backend test. |
| Old client downloads a labelled recipe | Extra columns are ignored. |
| New client before the migration is deployed | Upload would fail on unknown columns, so the migration ships in the same PR as the client mapping; CI applies it on merge to `dev`, and the release deploys migrations before the app. |
| Newer value unknown to this client | Shown as unknown, stored and sent back unchanged. |
| Recipes saved before #37 | `null` labels, picked up by the one-time pass. |

## Consumers

| Consumer | Uses | Card |
| --- | --- | --- |
| Meal rules | weight, dish kind, meals; `null` = unknown | #39 |
| Planner from saved recipes | candidate filter by meals | #45 |
| Recipe filters | all three labels, by value not text | #102 |
| Cookbook “save as recipe” | must fill labels like any new recipe | #50 |

## Notes for meal rules (#39)

The labels are coarse: pasulj, sarma, gulaš and grašak are all `cooked`. Two
rules from card #39 and spec 019 FR-102 do not work with them and are proposed
to change when #39 starts (agreed with the Dev 2 owner, 2026-11-18):

1. “The same dish kind not on two consecutive days” together with “lunch is
   cooked or roast” would force lunches to alternate strictly between two
   kinds. Proposed: the repeat rule applies to the **same recipe** (for
   example not twice within three days), not to the dish kind.
2. “Lunch is a cooked dish or roast” excludes pasta, a normal Serbian lunch.
   Proposed: lunch is any recipe with weight `medium` or `hearty`; the dish
   kind is not restricted. Snacks stay light and exclude `cooked` and `soup`.

FR-102 and the #39 card text are updated when #39 is planned; this contract
only records the decision.

## Delivery slices (after #46 is merged)

1. This contract, reviewed by Dev 1 and Dev 3.
2. Domain + validator + prompts + drift and server columns + sync mapping, with
   tests (one PR, because the migration and the mapping must ship together).
3. Recipe screen section and edit sheet, then the one-time labelling pass.

Estimate: slice 2 about 1.5 days, slice 3 about 1.5 days, plus review.

## Decisions

| # | Question | Proposal | Owner |
| --- | --- | --- | --- |
| L-D1 | Values and wire names | As in Labels above | Dev 2, review Dev 1 + Dev 3 |
| L-D2 | Dish kind list | Nine kinds above (agreed with Dev 2 owner 2026-11-18); a dish that still fits none stays `null`; a new value needs a migration | Dev 2 |
| L-D3 | Labels in the manual recipe form | Not in the form; the one-time pass labels manual recipes and the user corrects them on the recipe | Dev 2 |
| L-D4 | When the one-time pass runs | Automatically after sync, in the background, batches of 20; no user-facing button, the user never has to think about it | Dev 2 |
| L-D5 | drift version number | Next free number at merge time, confirmed by Dev 1 | Dev 1 |
