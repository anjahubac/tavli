# Capstone evaluation results

Run on commit `3a32b93450a210b3d03b7e3b762fc873133f7e85`, macOS, Flutter 3.50.0,
2026-11-21. Command: `flutter test test/evals`. Result: 11 tests passed (2
registry checks and 9 deterministic cases). Cases are in `cases.jsonl`.

Rerun on 2026-11-22 after tightening EV-12 (same app code, `dev` at
`a5bd3c3`): `flutter test test/evals` passed 13 tests, the 11 above plus the
two EV-12 before-and-after scenarios; the manual live test was skipped.

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
| EV-12 | deterministic | Pass: one repair to the same model (2 calls), then stop with `AllModelsExhausted`, no recipe; see the before and after below |
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

## Live run through the gateway (2026-11-24)

The seven `live` cases (EV-01, EV-02, EV-03, EV-06, EV-07, EV-09, EV-10) rerun
through the `ai-gateway` Edge Function with a signed-in account, as CAP-05
asks. Setup, the image cases and the gateway checks are in
[gateway-live-run-2026-11-24.md](gateway-live-run-2026-11-24.md).

How: `test/evals/live_gateway_cases_test.dart` uses the real `RecipeAI`,
`AIRouter` and `GatewayChatClient` with no personal key, against a local
Supabase stack (`supabase functions serve ai-gateway`) with a synthetic account.
The inputs and the checks are the ones above; EV-06 refines the recipe the same
run produced for EV-01. App and gateway code: the working tree of `f76ba31` (`dev` at `de9dd09`
plus this documentation); the gateway's text chain is the same in the open
gateway PRs. One run per case; the raw lines are in
`traces/gateway-live-2026-11-24.jsonl`.

| Case | Check | Result through the gateway |
| --- | --- | --- |
| EV-01 | servings 2, at least 3 ingredients, steps present | Pass: 2 servings, 13 ingredients, 7 steps |
| EV-02 | at least 70% of its ingredients also in EV-01 | Pass: 9 ingredients, 8 of them also in EV-01 (89%) |
| EV-03 | servings 4 and no meat keyword | Pass: 4 servings, 15 ingredients, no meat |
| EV-06 | no onion (garlic allowed), at least 70% of EV-01 kept | Pass: no onion, 12 ingredients |
| EV-07 | valid recipe or a controlled error | Pass: "Brza piletina sa povrćem i pirinčem", 9 ingredients |
| EV-09 | no number followed by kcal or kalorij | Pass: no calorie claim |
| EV-10 | valid recipe, no mention of passwords | Pass: valid "Gulaš", 13 ingredients, no password text |

All seven were answered by `Groq GPT-OSS 120B`: the first model of the text chain,
`gemini/gemini-pro-latest`, was rate limited, so the router moved on. The
earlier run in this file was answered by Gemini Flash-Lite, so the two runs
differ in model as well as in route; they do not compare route alone.

Limits: one run per case (no variance), one model for all cases, keyword and
threshold checks instead of a judge, a local stack and a free-tier key. The
EV-02 share here (89%) is above the 70% threshold the earlier run only met
exactly, which is a different model and not evidence that the case is stable.

## Before and after: one repair of an invalid model answer (EV-12)

The change is PR #69: before it, an answer that failed validation made the
router send the same prompt again and then walk the whole model chain. After
it, the router sends one repair request to the same model with the previous
answer and the failed rule, and stops if that fails too.

Same inputs on both sides, with a fake model client and no network or keys:
`test/evals/ev12_repair_before_after_test.dart`, run with
`flutter test test/evals/ev12_repair_before_after_test.dart` on the commit
before #69 (`28fa253`), on the #69 merge (`3100d8f`) and on this branch
(`a5bd3c3`). Each scenario prints one trace line; the lines are in
`traces/ev12-repair-before-after.jsonl`.

| Scenario | Before #69 | After #69 (same on `a5bd3c3`) |
| --- | --- | --- |
| EV-12a: every answer invalid | 4 calls (`gemini/pro` x2, `groq/text` x2), same prompt resent, `AllModelsExhausted` | 2 calls (`gemini/pro` x2), repair carries the previous answer, `AllModelsExhausted` |
| EV-12b: invalid, then valid | 2 calls, same prompt resent, recipe returned | 2 calls, repair carries the previous answer, recipe returned |

The test asserts the behavior after #69, so it fails on the commit before #69
(both scenarios: 4 calls instead of 2, and no previous answer in the second
request) and passes after it. The earlier EV-12 check ("at most 4 calls")
passed on both sides and did not measure this change; it now expects exactly
the two calls.

Limits: the model is simulated, so this measures the router's control flow,
not whether a real model fixes its answer after the repair request.

## Before and after: catalog-ready ingredient names

The change from PR #102 measured on 30 fixed dishes, two runs per condition
(86.3% and 86.2% before, 91.8% and 90.5% after). Full method, per-dish traces,
counter-evidence and limits are in `trace-ingredient-names.md`; the raw traces
are in `traces/`.

## Checks that the tests can fail

- EV-13: removing `withdrawn: true` from the catalog food made the test fail
  (the matcher returned a match); the original was restored and passes.
- EV-04: changing the expected total from 700 g to 600 g made the test fail.
- EV-11: the first version expected one call and failed. The router tries the
  next model after a 4xx error by design, so the case was corrected to
  "one call per model, bounded by the chain".

## Not covered

All seven `live` cases ran once with one model. The before and after
evidence is in `trace-ingredient-names.md` (PR #102, live model) and in the
EV-12 section above (PR #69, simulated model). The `live` cases EV-01 to EV-10
were rerun once through the gateway on 2026-11-24 (section above); they have not been repeated to measure variance.
