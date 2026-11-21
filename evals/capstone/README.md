# Capstone evaluation cases (CAP-05)

Sixteen fixed cases (EV-01 to EV-16) for the photo/dish-name to recipe to
shopping flow. They are defined in `cases.jsonl`; each has an input, the
expected outcome and the reason it exists.

| Cases | Mode | How it runs |
| --- | --- | --- |
| EV-04, EV-05, EV-08, EV-11 to EV-16 | `deterministic` | `flutter test test/evals`: real `RecipeAI`, `AIRouter`, `AliasFoodMatcher`, shopping totals and outline validation with a scripted model. No network or keys. |
| EV-01 to EV-03, EV-06, EV-07, EV-09, EV-10 | `live` | Need a real model. Run them by hand against the free-tier chain and record the result in `results.md`. |

## Running the live cases

1. Pass your own key through `--dart-define-from-file` as described in the
   README. Never put a key in this folder, in a test or in a commit message.
2. Run each `live` input through the app or `RecipeAI` and write the actual
   outcome, the model that answered and the commit under test in `results.md`.
3. After a prompt or code change, rerun the same inputs and record the new
   result next to the old one. If a case itself had to change, say so.

## Before and after evidence

PR #102 measured the ingredient-name prompt change on 30 dish names through
`RecipeAI.fromDishName`, checking each ingredient with `AliasFoodMatcher`
against the legacy food reference: 87.1% (230/264) with the base rules and
90.7% (244/269) with the "name the kind" and "no brand" rules. That run is
the candidate "one reasoned change, measured on the same inputs" for CAP-05.
It still needs a saved trace and a committed, repeatable run.

## Limits

The deterministic cases prove the app-side decisions with a scripted model.
They do not prove model quality, and a fake cannot prove server-side checks.
