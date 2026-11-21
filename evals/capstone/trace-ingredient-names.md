# Trace: catalog-ready ingredient names (CAP-05 before and after)

One reasoned change, measured on the same inputs: the ingredient-name rules
from PR #102 (`lib/ai/prompts.dart`, `lib/ai/meal_plan_prompts.dart`,
`ai_response_validator.dart`) against the prompt on `dev`.

## Criterion

At least 90% of the ingredients the AI returns link to the catalog without a
manual fix (the card's acceptance, TRELLO-40). The check is the existing
`AliasFoodMatcher` over `specs/018-ingredient-catalog/research/legacy-food-reference.csv`
(171 foods with aliases; not the accepted catalog).

## Method

- Inputs: the 30 dish names in `dishes.json`, each sent once per run through
  `RecipeAI.fromDishName` (same chain, all answered by Gemini Flash-Lite).
- Before: eval branch with the `dev` prompt. After: the same branch plus the
  head of #102 (merged into a local temporary branch), nothing else changed.
- Two runs per condition. Every run is saved in `traces/`; the first line of
  each file has the commit, and each following line is one dish with every
  ingredient, its note and the match result.
- Reproduce: `python3 evals/capstone/analyze_catalog_names.py` summarizes the
  traces; `test/evals/live_catalog_names_test.dart` documents the command that
  creates a trace.

## Result

| Run | Ingredients | Matched | Rate |
| --- | --- | --- | --- |
| before | 278 | 240 | 86.3% |
| before-2 | 282 | 243 | 86.2% |
| after | 280 | 257 | 91.8% |
| after-2 | 283 | 256 | 90.5% |

All 30 dishes were answered in every run. The two repeats differ by 0.1 points
before and 1.3 points after; the gap between the conditions is 4.3 to 5.6 points.

## Observation, cause, change

Observation: with the `dev` prompt the model names the food loosely, and the
matcher only accepts an exact name or alias. From the traces (before, then after):

| Dish | Before | After |
| --- | --- | --- |
| pita sa sirom | `kravlji sir`, no match | `beli sir`, matched to `beli sir` |
| gibanica | `kravlji sir`, no match | `beli sir`, matched |
| zeljanica | `sir`, no match | `beli sir`, matched |
| riblja čorba | `suva crvena paprika` and `ljuta paprika`, no match | `aleva paprika`, matched |

Cause: the `dev` prompt does not tell the model to give the base name as bought
or to name the kind. #102 adds those rules (base name in `name`, preparation and
state in `note`, one food per ingredient, name the kind such as `beli sir`, no
brands). Names that missed less often over the two runs include
`suvi biljni začin` (12 to 3), `kravlji sir` (4 to 0), `sir` (3 to 0) and
`mlevena crvena paprika` / `crvena mlevena paprika` (3 each to 0).

## Counter-evidence and what did not change

- Some names started missing: `svinjski but`, `suva svinjska rebra`, `koren peršuna`
  (catalog gaps, not prompt errors) and two corrupted names from the model,
  `juneći the` and `teleći meni`. The last two appear only after the change and
  are probably model noise, but this run cannot rule out the prompt.
- The change does not fix catalog gaps. Still missing in both after runs:
  `kore za gibanicu` (5), `svinjski file` (4), `paradajz pelat` (4).

## Limits

One model (Flash-Lite), two runs per condition and 30 dishes chosen for this
repo, so the numbers are not comparable with the 87.1% and 90.7% in #102. The
second after run is 90.5%, barely over the 90% target. The match rate is not a
significance test, and the reference is the legacy list, not the accepted
catalog. A first attempt ran three dishes in parallel and was discarded because
the free tier refused 16 of 30 answers; the runs above are sequential with a
wait after a rate limit.
