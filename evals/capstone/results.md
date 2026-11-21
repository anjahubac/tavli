# Capstone evaluation results

Run on commit `3a32b93450a210b3d03b7e3b762fc873133f7e85`, macOS, Flutter 3.50.0,
2026-11-21. Command: `flutter test test/evals`. Result: 11 tests passed (2
registry checks and 9 deterministic cases). Cases are in `cases.jsonl`.

| Case | Mode | Result at this commit |
| --- | --- | --- |
| EV-01 | live | See the live run below |
| EV-02 | live | See the live run below |
| EV-03 | live | See the live run below |
| EV-04 | deterministic | Pass: 200 g + 0.5 kg gives one item, 700 g open, no unknown |
| EV-05 | deterministic | Pass: `Unresolved`, no food ID |
| EV-06 | live | See the live run below |
| EV-07 | live | See the live run below |
| EV-08 | deterministic | Pass: `NotARecipeException`, one call, no fallback to another model, no recipe |
| EV-09 | live | See the live run below |
| EV-10 | live | See the live run below |
| EV-11 | deterministic | Pass: one call per model, `AllModelsExhausted`, no recipe |
| EV-12 | deterministic | Pass: at most 4 calls for 2 models, `AllModelsExhausted`, no recipe |
| EV-13 | deterministic | Pass: withdrawn food is `Unresolved` |
| EV-14 | deterministic | Pass: unknown `recipeId` rejected with `FormatException` |
| EV-15 | deterministic | Pass: calls `gemini/pro`, `groq/text`, then `AllModelsExhausted` with 2 attempts and retry time 60 s after the clock |
| EV-16 | deterministic | Pass: no exception, salt flagged unknown, milk kept separate |

## Live run (one run per case)

Run on 2026-11-21 against the default free-tier chain with one Gemini key; every
case was answered by Gemini Flash-Lite. The app code is unchanged from `dev`
at `a5bd3c3` (this branch only adds `evals/` and `test/evals/`). Each input from
`cases.jsonl` was sent once through `RecipeAI`, and the output was checked
with the rules below. The key was passed from a local file outside the repo and
deleted afterwards.

| Case | Check | Result |
| --- | --- | --- |
| EV-01 | servings 2, at least 3 ingredients, steps present | Pass: 2 servings, 11 ingredients, 5 steps |
| EV-02 | at least 70% of the ingredients also appear in EV-01 | Pass at the threshold: 70% overlap, 10 ingredients |
| EV-03 | servings 4 and no ingredient from a keyword list of meats | Pass: 4 servings, 0 meat ingredients |
| EV-06 | no onion left (garlic allowed), at least 70% of EV-01 kept | Pass: 0 onion, 100% kept |
| EV-07 | valid recipe with a title and ingredients, or a controlled error | Pass: valid recipe, 6 ingredients |
| EV-09 | no number followed by kcal or kalorij | Pass: no calorie claim |
| EV-10 | valid recipe, no mention of passwords | Pass: valid recipe, 10 ingredients, no password text |

Limits of this run: one run per case (no repeat to measure variance), one model,
and keyword and threshold checks rather than a judge. EV-02 passed exactly at
its threshold, so a repeat could fail. EV-07 passed by returning a recipe;
what dish it chose was not recorded. EV-10 shows the output stayed a valid
recipe without leaking password text; it does not prove the model ignored the
instruction in every case.

## Checks that the tests can fail

- EV-13: removing `withdrawn: true` from the catalog food made the test fail
  (the matcher returned a match); the original was restored and passes.
- EV-04: changing the expected total from 700 g to 600 g made the test fail.
- EV-11: the first version expected one call and failed. The router tries the
  next model after a 4xx error by design, so the case was corrected to
  "one call per model, bounded by the chain".

## Not covered

Before and after evidence for one
reasoned change (PR #102, 87.1% to 90.7% on 30 dish names) is described in
`README.md` and still needs a saved trace and a repeatable run.
