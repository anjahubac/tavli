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
| GW-05 | The same three cards through the screens in the running app, signed in, then plan and shopping list ([GW-05](#gw-05-through-the-screens-ios-simulator-local-stack)) | Recipe reviewed and saved; unreadable quantity marked, not invented; unreadable photo gives a controlled error and saves nothing; plan feeds the list | **Pass in one pass** on the iOS Simulator. Readable card: review and save. One unreadable line: "mleko (nečitka količina)" with no quantity. Blurred card: "Na slici nije pronađen recept.", library unchanged. Plan to list: brašno 500 g, and 1 kg after the same recipe is planned twice. Not shown: a total of mixed units such as 200 g + 0,5 kg. |

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
- The runner (GW-01 to GW-04) calls `RecipeAI` and the shopping totals
  directly. GW-05 below is the only run through the screens with a photo, and
  it is one pass on one platform. The Windows run in
  [app-flow.md](../../docs/capstone/app-flow.md) covers a recipe by dish name
  and, per its recorder, used the hosted gateway; GW-05 is local only.

## GW-05: through the screens (iOS Simulator, local stack)

Run on 2026-11-24 by hand, in one pass. It shows the path a person takes:
sign-up, photo, review, save, plan, shopping list, and the error for a photo
that cannot be read.

- **Build**: `flutter build ios --simulator --debug` on the checkout of branch
  `docs/capstone-ev-gateway-rerun` at `13721a2`. Its `lib/` and `pubspec.yaml`
  had no difference from `dev` at `9ba7758` (checked with `git diff`). The
  anon key of the local stack was passed with `--dart-define-from-file`, from
  a file outside the repository that was deleted afterwards.
- **Device**: iPhone 17 Pro simulator, iOS 26.5.
- **Backend: local, not hosted.** `supabase start`, with
  `supabase functions serve` run by the owner with the provider key as a
  function secret. The app held no provider key. A request to the function
  without a token answered 401 before the run.
- **Account**: a synthetic address on the local stack, with the code read from
  the local mail catcher (Mailpit). The hosted project was not used.
- **Photos**: the three synthetic cards in `fixtures/`, added to the
  simulator's photo library and picked with **Izaberi iz galerije**. They are
  not camera shots.

| Step | What the screen showed |
| --- | --- |
| Sign-up | **Napravi nalog** → "Proveri mejl" (confirm by link or the six-digit code) → "Kako da te zovemo?" → "Tvoje domaćinstvo" (name, default **Nastavi**) → **Početna** ("Danas", "Post i praznici", no plan yet). On first launch the sign-in screen showed "Sesija je istekla. Prijavi se ponovo."; the simulator may have held an older session, not investigated |
| Readable card | "Čitam recept sa slike…" for under half a minute, then the review: "Palačinke", 30 min, 4 porcije, ingredients by category (brašno 500 g, jaje 3 kom, mleko 750 ml, kisela voda 200 ml, so prstohvat, ulje 2 kašike), buttons **Odbaci**, **Proveri sastojke**, **Pokušaj ponovo**, **Sačuvaj**. After **Sačuvaj**: "Recept je sačuvan.", the recipe page with **Kuvaj**, **Dodaj u plan**, **Omiljeni**, **Oceni**, and the recipe in the library with the photo as its picture |
| Card with one unreadable line | The review lists "mleko (nečitka količina)" with no quantity; the other lines are as above. This recipe was discarded with **Odbaci**, not saved |
| Blurred card | The red message "Na slici nije pronađen recept." with **Izaberi drugu sliku**. Nothing was saved: the library still held one recipe |
| Plan | **Dodaj u plan**: Tuesday 24 November, Ručak, 4 portions → "Dodato u plan: utorak, ručak. Nabavka je osvežena." The day view shows "Ručak — Palačinke" |
| Shopping list | **Nabavka → Po planu**: jaje 3 kom, mleko 750 ml, brašno 500 g, so "Proveri količinu", ulje 2 kašike. After the same recipe was also planned for Tuesday's Večera: jaje 6 kom, mleko 1,5 l, brašno 1 kg |

### What GW-05 does not show

- A total of **mixed units** such as 200 g + 0,5 kg = 700 g. The manual field
  **Dodaj stavku** offered only a name, and the simulator tooling could not
  type "š" into it. The 500 g + 500 g = 1 kg and 750 ml × 2 = 1,5 l above are
  the same unit. The mixed-unit case is covered only by EV-04 in
  `test/evals/capstone_eval_test.dart`.
- The shopping effect of the unreadable line: the recipe with "mleko
  (nečitka količina)" was not saved or planned. "so" shows "Proveri količinu"
  for a quantity-less ingredient of the saved recipe.
- AI plan generation (**Predloži plan**), recipe by dish name, a second
  household member, and any platform other than the iOS Simulator.
- Which provider or model answered the photo requests: the photo review does
  not show it. One pass per card, so this is no measured rate.
- The hosted backend. The run says nothing about hosted configuration.

The screenshots (26) and no recording are kept outside the repository. No link
to them is recorded here yet.
