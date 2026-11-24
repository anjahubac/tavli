# Live run through the AI gateway (CAP-02, CAP-04, CAP-06)

The cases in `results.md` were recorded with a personal key through `RecipeAI`.
This run goes through the path a signed-in user takes: the app has no provider
key, the request carries the user's JWT to the `ai-gateway` Edge Function, and
the function holds the provider key as a function secret.

Runner: `test/evals/live_gateway_flow_test.dart` (tag `live`, skipped unless
`GATEWAY_LIVE=1`). It uses the real `GatewayChatClient` and `AIRouter` with an
empty own-key store, so the only way to a model is the gateway. Trace lines
(no tokens, keys or recipe text beyond ingredient names) are in
`traces/gateway-flow.jsonl`; `label` marks one pass (`before-N` = prompt
before this change, `after-N` = prompt after it).

## Setup

- Local stack: `supabase start`, then `supabase functions serve` with the
  provider key supplied as a function secret from a file outside the repo.
- A synthetic local user (email and password created on the local stack only).
- `GATEWAY_LIVE=1 GATEWAY_LABEL=<label> SUPABASE_URL=… SUPABASE_ANON_KEY=… GATEWAY_TEST_EMAIL=… GATEWAY_TEST_PASSWORD=… flutter test test/evals/live_gateway_flow_test.dart`
- Fixtures are synthetic images in `fixtures/`: a readable recipe card, a
  card that is blurred beyond reading, and a card with one unreadable
  ingredient line.

## Cases

| Case | Input | Expected | Result |
| --- | --- | --- | --- |
| GW-01 | Readable recipe card, signed in | Gateway answers, recipe passes client validation, confirmed recipe reaches the shopping totals | Pass in 3 passes (`before-1`, `before-2`, `after-1`). 500 g of flour from the recipe is in the totals. A manual item "Brašno" 200 g and the recipe's "pšenično brašno" 500 g stay as two totals (200 g and 500 g): the names do not match, so they are not summed. |
| GW-02 | Card too blurred to read | Controlled `NotARecipeException`, nothing saved | **Before: fail.** The model invented a six-ingredient recipe and marked quantities "procena" (`before-3`). **After: pass**, `NotARecipeException` in both passes that ran it (`after-1`). |
| GW-03 | Raw requests: no token, forged token, 1.6 MB body, unknown task, model outside the list, extra field, invalid JSON | Rejected before any model call | Pass, identical in all 3 passes: 401, 401, 413 `too_large`, 400 `bad_request` x4. |
| GW-04 | Card with one unreadable ingredient line | Recipe kept, that ingredient carries a note | **After: pass** (`after-1-gw04`): recipe kept, "mleko" has the note "nečitko na slici". **Before: not measured**, the provider quota ran out before the baseline pass. |

## What changed between before and after

One change, in `recipeFromImagePrompt` (`lib/ai/prompts.dart`): the old text
told the model to "make a sensible guess" for anything unreadable, which is
what produced the invented recipe in GW-02. The new text keeps the recipe and
adds a note when a single ingredient line is unreadable, and returns
`{"error": "not_a_recipe"}` when the image has no legible title and fewer than
three legible ingredient lines. The same inputs were rerun after the change.

## Limits

- Free-tier provider chain: the first model in the chain often answers with a
  transient error or a quota pause, and the answer comes from a lower model
  (`sent` in each trace line shows the attempts). Three further GW-04 runs hit
  the quota (`AllModelsExhausted`, `GatewayQuotaError`) and recorded no result;
  they say nothing about the prompt.
- GW-04 has a single successful pass and no baseline. GW-02 has one baseline
  pass and two after passes. This is a small sample, not a measured rate.
- The "before" GW-02 pass ran on the gateway before the server-side structure
  check of the model answer was merged; the "after" passes ran on current
  `dev`. The prompt is the only change in the client code under test.
- Runs are against a local stack with a synthetic user, not the hosted
  project. They do not prove hosted configuration.
- The runner calls `RecipeAI` and the shopping totals directly. A photo
  taken through the screens (photo, review with unconfirmed items marked, save,
  plan, shopping list) and the Serbian message for an unreadable photo in the
  running app are **not recorded**. The only run of the screens is the Windows
  run in [app-flow.md](../../docs/capstone/app-flow.md): it covers a recipe by
  dish name, not a photo, and per its recorder it used the hosted gateway,
  while this file is local only. A photo run through the app needs to be done
  and written down as its own case (GW-05) before it can be claimed.
