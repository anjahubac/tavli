# Contract: daily meals as a list, with snacks

**Status**: proposal for review (Trello #38, spec 019 FR-002, FR-101, FR-103).
Nothing here is implemented yet.
**Author**: Dev 2 | **Reviewers**: Dev 1 (`lib/domain/shopping_source.dart`,
plan entries sync), Dev 4 (Početna and month view consume the meal list)
**Date**: 2026-11-18 | **Builds on**: [AI response contract](../../014-ai-response-contracts/contracts/ai-response-contract.md)
decision D5 (snacks are an additive change to `plan-outline.v1`)

## Purpose

A plan day gets up to five meals: breakfast, morning snack, lunch, afternoon
snack, dinner. The user picks which ones when creating the plan. A locked meal
is never changed by the rules or by “Ponovo predloži”.

## What already exists (dev `9fe5345`)

The current model is already list-based; only the meal vocabulary is fixed to
three values.

| Card requirement | Existing code | Remaining work |
| --- | --- | --- |
| Day is a list, not three fixed fields | `MealPlans.mealTypesJson` is a list; entries are rows keyed by date + `meal_type`; the day view iterates `plan.slots` (`plan_screen.dart`) | none |
| User picks the meals | `plan_setup_screen.dart` shows a chip per `MealType.values` | two more chips |
| Locked meal survives “Ponovo predloži” | `isLocked` column, `setLocked`, regenerable slots skip locked and cooked meals (`meal_plan.dart`, `meal_plan_repository.dart`) | an acceptance test with snacks |
| Snacks | missing | this contract |

## Meal types

| Wire (`MealType.name`) | UI | Order |
| --- | --- | --- |
| `breakfast` | Doručak | 0 |
| `morningSnack` | Užina pre podne | 1 |
| `lunch` | Ručak | 2 |
| `afternoonSnack` | Užina posle podne | 3 |
| `dinner` | Večera | 4 |

The wire value stays `MealType.name`, as for the existing three. The Dart enum
is reordered to the day order; the index is never stored, only the name.

## Changes by consumer

| Consumer | File (owner) | Change |
| --- | --- | --- |
| Domain | `lib/domain/meal_plan.dart` (Dev 2) | two enum values, day order |
| Plan setup | `lib/features/planning/plan_setup_screen.dart` (Dev 2) | five chips; default stays {Ručak}; wraps on phone with 2× text |
| Outline prompt and parser | `lib/ai/meal_plan_prompts.dart`, `meal_plan_ai.dart` (Dev 2) | `meal` enum gets the two values; one line: a snack is a small, light dish (fruit, yoghurt, sandwich), never a cooked meal. Full placement rules stay in #39. |
| Stored plan reader | `lib/data/meal_plan_repository.dart` (Dev 2) | an entry with an unknown `meal_type` is skipped instead of shown as lunch (today `?? MealType.lunch`) |
| Pantry allocation order | `mealOrder` in `lib/domain/shopping_source.dart` (Dev 1) | five-step order matching the table; unknown stays last |
| Shopping list labels | `shopping_list_view.dart` | none, uses `MealType.label` |
| Labels contract | recipe-labels-contract.md (PR #54) | both snack slots use the `snack` suitability |
| Početna “današnji obroci”, month view | Dev 4 (#83, #79) | read the same list; no fixed three |

## Data

No schema change. `meal_plans.meal_types` (jsonb) and
`meal_plan_entries.meal_type` (text) have no value constraint on the server, and
the drift columns are text. No drift version, no migration, no sync change.

## Compatibility

| Case | Result |
| --- | --- |
| Plans saved before #38 | Only the old three values; shown exactly as today. |
| Old client reads a plan with snacks | Today an unknown `meal_type` is read as **lunch**, so a snack appears as a second “Ručak”, and regenerating on the old client can treat a locked snack as a locked lunch. |
| Mitigation | Before #38 merges, confirm with Dev 4 that no build outside the team uses `tavli-dev` or production; team builds update after merge. The skip-unknown reader ships in the same PR so later meal types do not repeat this. If an external build exists, #38 waits for a minimum app version check (not in this contract). |

## AI cost

Five meals for a month is 155 slots instead of 93 with three. The outline and
summary calls grow by about two thirds. The per-user daily text limit proposed
in the 015 gateway contract (150 calls) must be checked against a five-meal
monthly plan before the gateway slice sets defaults.

## Acceptance

- A plan with and without snacks can be created; the setup count updates.
- A plan saved before #38 shows the same meals and order.
- A locked snack and a locked lunch keep their dish after “Ponovo predloži”;
  only open slots change.
- An AI response with an unrequested snack slot is rejected (existing rule).
- An entry with an unknown `meal_type` is not shown as lunch.
- Shopping lists include snack ingredients; pantry allocation follows the day
  order.

Estimate: about 1 day plus review, one PR, after Dev 1's #16 (calendar dates)
is merged, as the card states.

## Decisions

| # | Question | Proposal | Owner |
| --- | --- | --- | --- |
| S-D1 | Wire names | `morningSnack`, `afternoonSnack` (`MealType.name`) | Dev 2, review Dev 1 |
| S-D2 | Server value check on `meal_type` | none now; the app validates; a check constraint would need every client updated first | Dev 2 + Dev 1 |
| S-D3 | Old builds | team-only today (to be confirmed by Dev 4); no version gate in #38 | Dev 4 |
| S-D4 | Snack guidance in the prompt | one line now; rules in #39 | Dev 2 |
