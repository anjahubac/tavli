# Capstone evaluation results

Run on commit `3a32b93450a210b3d03b7e3b762fc873133f7e85`, macOS, Flutter 3.50.0,
2026-11-21. Command: `flutter test test/evals`. Result: 11 tests passed (2
registry checks and 9 deterministic cases). Cases are in `cases.jsonl`.

| Case | Mode | Result at this commit |
| --- | --- | --- |
| EV-01 | live | Not run: needs a real model |
| EV-02 | live | Not run: needs a real model |
| EV-03 | live | Not run: needs a real model |
| EV-04 | deterministic | Pass: 200 g + 0.5 kg gives one item, 700 g open, no unknown |
| EV-05 | deterministic | Pass: `Unresolved`, no food ID |
| EV-06 | live | Not run: needs a real model |
| EV-07 | live | Not run: needs a real model |
| EV-08 | deterministic | Pass: `NotARecipeException`, one call, no fallback to another model, no recipe |
| EV-09 | live | Not run: needs a real model |
| EV-10 | live | Not run: needs a real model |
| EV-11 | deterministic | Pass: one call per model, `AllModelsExhausted`, no recipe |
| EV-12 | deterministic | Pass: at most 4 calls for 2 models, `AllModelsExhausted`, no recipe |
| EV-13 | deterministic | Pass: withdrawn food is `Unresolved` |
| EV-14 | deterministic | Pass: unknown `recipeId` rejected with `FormatException` |
| EV-15 | deterministic | Pass: calls `gemini/pro`, `groq/text`, then `AllModelsExhausted` with 2 attempts and retry time 60 s after the clock |
| EV-16 | deterministic | Pass: no exception, salt flagged unknown, milk kept separate |

## Checks that the tests can fail

- EV-13: removing `withdrawn: true` from the catalog food made the test fail
  (the matcher returned a match); the original was restored and passes.
- EV-04: changing the expected total from 700 g to 600 g made the test fail.
- EV-11: the first version expected one call and failed. The router tries the
  next model after a 4xx error by design, so the case was corrected to
  "one call per model, bounded by the chain".

## Not covered

The eight `live` cases have no result yet. Before and after evidence for one
reasoned change (PR #102, 87.1% to 90.7% on 30 dish names) is described in
`README.md` and still needs a saved trace and a repeatable run.
