# Contract: meal placement rules

**Status**: implemented on `feat/meal-placement-rules` (Trello TRELLO-39, spec
019 FR-003, FR-102, FR-103), pending review.
**Author**: Dev 2 | **Reviewer**: Dev 4 (Plan UI consumer)
**Date**: 2026-11-20 | **Builds on**:
[recipe labels](recipe-labels-contract.md),
[daily meals with snacks](meal-slots-contract.md),
[`plan-outline.v1`](../../014-ai-response-contracts/contracts/ai-response-contract.md) (P6)

## Problem

The plan prompt never said what lunch or dinner is, so the model mixed them up
(a heavy dish for dinner, a salad for lunch). The app could not check the
result because a new dish had no weight.

## Rules

Fixed defaults in code (`lib/domain/meal_rules.dart`). The household setting
from the card text is out of scope for this slice.

| Rule | Breaks when |
| --- | --- |
| `lunchTooLight` | lunch has weight `light` (any dish kind is fine, including pasta) |
| `dinnerTooHeavy` | dinner has weight `hearty` |
| `snackNotLight` | a snack has weight `medium` or `hearty` |
| `snackCooked` | a snack has dish kind `cooked` or `soup` |
| `secondHearty` | a day has two `hearty` meals; the one that is not lunch breaks it |
| `repeated` | the same recipe appears twice within 3 consecutive days, or within 7 days for a household favorite (TRELLO-44, `favorites` argument); the later slot breaks it |

The same recipe means the same library id, or the same `draftRecipeKey` for
a new dish. An unknown label (`null`) never breaks a rule.

When a conflict involves a kept meal and a proposed one, the proposed slot
breaks the rule, so it can be fixed: a kept hearty breakfast makes a proposed
hearty lunch break `secondHearty`, and a kept Thursday recipe makes the same
recipe proposed on Wednesday break `repeated`.

These two rules replace the card and FR-102 wording, as recorded in the
[recipe labels contract](recipe-labels-contract.md#notes-for-meal-rules-39):
lunch is any `medium`/`hearty` dish (not only cooked or roast), and the
repeat rule applies to the same recipe, not the dish kind.

## Where the facts come from

| Meal | Weight and dish kind |
| --- | --- |
| New AI dish | `weight` and `dishKind` from the outline (P6) |
| Library recipe proposed by AI | the stored labels; the model's values only fill a missing stored label |
| Meal that stays in a saved plan | labels of its library recipe (`PlannedMeal.recipeId`); none for a meal without a recipe |

`PlanRequest.kept` carries the meals that stay: locked, cooked and past meals
for “Ponovo predloži”, and every other meal of the plan for “Zameni jelo”.
In an unsaved draft, the other proposals play the same role. Kept meals are
sent in the prompt as context and checked with the proposals, but they are
never changed.

## Fixing a plan

`MealPlanAI.propose` checks the slots it proposed in that call, after all
outlines and before the recipe summaries, and fixes them silently:

1. If lunch and dinner of the same day only need to swap places to pass,
   they swap.
2. Slots that still break a rule get **one** new outline request for those
   slots only, with the rejected titles.
3. If a slot still breaks a rule, the first saved recipe with a known weight
   that passes there without breaking any other slot is used.
4. Otherwise the dish stays. The user never sees a rule message.

A failed step 2 (network, quota, invalid answer) does not fail the plan; the
first proposal goes on to step 3. Cancellation still stops the plan.

When the person picks a library recipe themselves (“Iz mojih recepata”),
the rules do not apply.

## Saving

On approval, a new recipe from the plan is saved with labels source `ai`: the
meals it was planned for, and the outline's weight and dish kind. Later plans
then know it, and the person can correct it with **Izmeni oznake**. Library
recipes are not changed. No schema change: the columns come from the
recipe labels migration (TRELLO-37).

## Compatibility

| Case | Behaviour |
| --- | --- |
| Model omits `weight`/`dishKind` | the plan is accepted; that dish is unchecked |
| Older saved plans | meals without a labelled recipe are unchecked |
| Plan with only breakfast | only `secondHearty` and `repeated` can apply |

## Evidence

- `test/domain/meal_rules_test.dart`: every rule, unknown labels, the swap
  and facts from a saved plan.
- `test/ai/meal_plan_ai_test.dart`, group *pravila rasporeda*: prompt rules
  and library labels, swap without a new request, one retry for the bad slot
  only, library fallback, keeping the dish, a failed retry, stored labels
  winning over the model, kept meals in the check and the prompt, lenient
  labels.
- `test/data/meal_plan_repository_test.dart`: a new plan recipe gets AI
  labels; a library recipe is unchanged.
- `test/features/planning/plan_calendar_test.dart`: “Ponovo predloži” asks
  only for open slots and sends kept meals as context.
- Live check of 20 generated plans: pending a working provider key.
