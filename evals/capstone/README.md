# Capstone evaluation cases (CAP-05)

Sixteen fixed cases (EV-01 to EV-16) for the photo/dish-name to recipe to
shopping flow. They are defined in `cases.jsonl`; each has an input, the
expected outcome and the reason it exists.

| Cases | Mode | How it runs |
| --- | --- | --- |
| EV-04, EV-05, EV-08, EV-11 to EV-16 | `deterministic` | `flutter test test/evals`: real `RecipeAI`, `AIRouter`, `AliasFoodMatcher`, shopping totals and outline validation with a scripted model. No network or keys. |
| EV-01 to EV-03, EV-06, EV-07, EV-09, EV-10 | `live` | Need a real model. Run them by hand against the free-tier chain, or through the gateway (below), and record the result in `results.md`. |

## Running the live cases

1. Pass your own key through `--dart-define-from-file` as described in the
   README. Never put a key in this folder, in a test or in a commit message.
2. Run each `live` input through the app or `RecipeAI` and write the actual
   outcome, the model that answered and the commit under test in `results.md`.
3. After a prompt or code change, rerun the same inputs and record the new
   result next to the old one. If a case itself had to change, say so.

## Before and after evidence

`trace-ingredient-names.md` records one reasoned change measured on the same
inputs: the ingredient-name rules from PR #102 against the `dev` prompt, on 30
fixed dishes (`dishes.json`), two runs per condition. Per-dish traces are in
`traces/`, and `python3 evals/capstone/analyze_catalog_names.py` summarizes
them. The runner is `test/evals/live_catalog_names_test.dart`; it is skipped
unless run by hand with a label and a key from a file outside the repo.

EV-12 also has a before and after on its own inputs: PR #69 (one repair of an
invalid model answer) measured with `test/evals/ev12_repair_before_after_test.dart`
on the commit before #69 and after it, without network or keys. The method and
table are in `results.md`; the trace lines are in
`traces/ev12-repair-before-after.jsonl`.

The live cases through the gateway (signed-in user, no key in the app) are
GW-01 to GW-04 in `test/evals/live_gateway_flow_test.dart`; the method, the
before and after of the photo prompt and the limits are in `gateway-flow.md`,
the trace lines in `traces/gateway-flow.jsonl`.

The seven `live` EV cases also have a run through the gateway with a signed-in
account: `test/evals/live_gateway_cases_test.dart` (real `RecipeAI`, no personal
key). It is skipped unless `EVAL_GATEWAY_URL`, `EVAL_ANON_KEY` and `EVAL_JWT` are
set in the process environment (see the header of the file); credentials and
provider keys never go into this folder. It is a separate runner from
`live_gateway_flow_test.dart` (GW cases). Its recorded pass is in `results.md`
and `traces/gateway-live-2026-11-24.jsonl`.

## Limits

The deterministic cases prove the app-side decisions with a scripted model.
They do not prove model quality, and a fake cannot prove server-side checks.
