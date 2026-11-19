# Contract: Edge Function `ai-gateway`

**Status**: proposal for review (TRELLO-36, spec 015 FR-002, Q1). Nothing here
is implemented yet. Revised 2026-11-19 after Dev 4 review: atomic quota
reservation with minute, concurrency and shared limits; quota and platform
`401` handling in `AIRouter`; per-model deadlines shared by gateway and client.
Second revision: quota pauses scoped to account and request kind, shared count
kept after account deletion, client timeout before the gateway answers, and
how the chain reaches `openai/default`.
**Author**: Dev 2 | **Reviewer**: Dev 4 (TRELLO-36: request and error format)
**Date**: 2026-11-17 | **Builds on**: [spike-photo-timing.md](../spike-photo-timing.md)
(decision A), [AI response contract](../../014-ai-response-contracts/contracts/ai-response-contract.md)

## Purpose

Built-in AI keys are compiled into the app today (`BuiltInKeys` from
`--dart-define-from-file`), so anyone with the app can extract them and spend
the shared quota or, with a paid key, the team's money. After this change the
built-in keys exist only as Supabase Edge Function secrets. A signed-in app
sends built-in AI requests to `ai-gateway`, which checks the caller and the
limits, makes one provider call and returns the model's text.

Keys a user enters in settings (BYOK) are unchanged: the app keeps calling the
provider directly with them, never through the gateway.

## Request

`POST /functions/v1/ai-gateway` with `Authorization: Bearer <user access token>`
(`functions.invoke`), `verify_jwt = true`, JSON body:

```jsonc
{
  "task": "recipe_from_image",          // see Tasks
  "model": "gemini/gemini-flash-lite-latest", // "<provider>/<model>", see Models
  "system": "You are the cooking assistant…",
  "prompt": "Read the recipe from this image…",
  "images": ["data:image/jpeg;base64,…"], // vision tasks only, at most 1
  "temperature": 0.1                     // optional, 0–1
}
```

The app keeps building prompts (`lib/ai/prompts.dart`,
`lib/ai/meal_plan_prompts.dart`) and keeps validating responses with the 014
validator; the gateway does not parse recipes.

### Tasks

| `task` | Kind | Caller today |
| --- | --- | --- |
| `recipe_from_image` | vision | `RecipeAI.fromImage` |
| `recipe_from_name` | text | `RecipeAI.fromDishName` |
| `recipe_refine` | text | `RecipeAI.refine` |
| `plan_outline` | text | `MealPlanAI` outline |
| `recipe_summaries` | text | `MealPlanAI` summaries |

Any other value is `400 bad_request`. A new AI feature adds its task here first.

### Models

The gateway has a fixed allowlist of `<provider>/<model>` ids matching
`ChainConfig.defaults`, each with the same per-model timeout as its
`ModelSpec.timeout` (30 s by default, 60 s for Gemini Pro; see Deadlines), plus `openai/default` once that key exists (D3). The
gateway resolves `openai/default` to the model named in the `OPENAI_MODEL`
secret, so the model changes without an app release. A
provider is available only when its secret is set; otherwise its models return
`503 model_unavailable` and the router skips them. This is how `tavli-dev` can
run on free keys while production uses a paid key, with the same code.

Provider base URLs live in the gateway; the request never contains a URL, a key
or a provider endpoint (spec 015 SC-001).

## Behaviour

1. `POST` only; otherwise `405`.
2. Resolve the caller with `auth.getUser(token)`; no user → `401`.
3. Validate the body: known `task`, allowlisted `model`, model kind matches the
   task kind, size limits below → else `400` or `413`. No provider call.
4. Reserve quota atomically (see Reservation) → `429 quota_exceeded` or
   `429 busy`, with no provider call. A request rejected in steps 1–3 does
   not count.
5. Exactly one provider call, `max_tokens` capped at 4096, aborted at the
   model's deadline (see Deadlines). No retry and no fallback inside the
   gateway (decision A): the app's `AIRouter` stays the single retry/fallback
   owner (FR-103).
6. Release the reservation (`finished_at`), whatever the outcome, then return
   the model's text or a typed error.

## Responses

| Status | Body | App mapping (`AIError`) | User sees |
| --- | --- | --- | --- |
| 200 | `{"content": "<model text>", "model": "<provider>/<model>"}` | — | result after 014 validation |
| 400 | `{"error": "bad_request"}` | `BadRequestError`, next model | existing message |
| 401 | any body (see Gateway errors in `AIRouter`) | `GatewayAuthError`: refresh session once and retry; then skip the gateway | “Sesija je istekla. Prijavi se ponovo.” (006 copy) |
| 413 | `{"error": "too_large"}` | `BadRequestError`, stop | existing message |
| 429 | `{"error": "quota_exceeded", "limit": "daily", "kind": "vision" or "text", "retryAfterSeconds": n}` | `GatewayQuotaError`: pause the gateway for this account and kind until `n`; user keys continue | “Limit je trenutno potrošen. Pokušaj malo kasnije.” |
| 429 | `{"error": "quota_exceeded", "limit": "minute" or "global", "retryAfterSeconds": n}` | `GatewayQuotaError`: pause the gateway for this account, both kinds, until `n`; user keys continue | same as above |
| 429 | `{"error": "busy", "retryAfterSeconds": n}` | `GatewayQuotaError` (too many calls at once): same as `minute` | same as above |
| 429 | `{"error": "provider_rate_limited", "retryAfterSeconds": n?}` | `RateLimitError` for this model, next model | — |
| 502 | `{"error": "provider_error"}` | `TransientError`, next model | — |
| 503 | `{"error": "model_unavailable"}` | `ModelNotFoundError`, next model | — |
| 504 | `{"error": "timeout"}` | `TransientError(isTimeout: true)`, next model | — |
| 500 | `{"error": "internal"}` | `TransientError`, next model | — |

Error bodies never contain provider responses, prompts, keys or stack traces
(012). Any response whose body is not one of the typed bodies above (for
example a platform error returned before the function runs) maps by status:
`401` as above, everything else to `TransientError`, next model.

### Gateway errors in `AIRouter`

Today `AIRouter` treats every `RateLimitError` as a per-model limit (it pauses
that model and tries the next) and every `AuthError` as a bad key. Both are
wrong for the gateway, so the client slice adds two `AIError` subtypes that
only the gateway path throws:

- `GatewayQuotaError(retryAfter, kind?)`: the router pauses the gateway (every
  model with `KeyOrigin.builtIn`) until `retryAfter`, keyed by the **signed-in
  account id** and the **request kind** (`vision` or `text`, from
  `AIRequest.kind`). A `daily` limit carries the kind from the body and pauses
  only that kind, so a used-up photo limit does not block text recipes or
  plans; `minute`, `global` and `busy` pause both kinds. The pause is
  device-local and survives an app restart, but it never applies to another
  account signed in on the same device, and signing out does not clear it for
  the account that hit it. Today's `ModelStatuses` table is per device and per
  model, so the client slice stores these pauses separately (account id, kind,
  until) with its own drift migration and test; per-model cooldowns stay where
  they are. It does not pause any user key. The loop continues, so models with
  a user key (BYOK) are still tried; if none exists,
  `AllModelsExhausted.nextAvailableAt` reports the quota reset.
- `GatewayAuthError`: Supabase can reject the token with `401` before the
  function runs, with a platform body instead of
  `{"error": "unauthorized"}` ([auth headers](https://supabase.com/docs/guides/functions/auth-headers)),
  so the client decides on the status alone. It refreshes the session once and
  repeats the same call; a second `401` skips the gateway for the rest of this
  run without marking a key invalid. User keys continue. If every model fails,
  the user sees the session message.

Existing per-model handling (`provider_rate_limited`, `model_unavailable`,
timeouts) is unchanged.

### Model chain and `openai/default`

The client slice adds `openai/default` to `ChainConfig.defaults` as the
**last** model of both chains (vision and text, `supportsVision: true`,
timeout 60 s). It has only a built-in (gateway) credential: the app has no
OpenAI client and no user key field for it (D3). Putting it last keeps the
existing rule that a user's own key goes first: for each model the router
tries the user key before the built-in one, so a user key on an earlier model
is always used before the paid model.

- **OpenAI-only deployment** (production with only `OPENAI_API_KEY`): the free
  built-in models answer `503 model_unavailable`. That check is in step 3,
  before the reservation, so it costs no quota and no provider call. The
  router already remembers `ModelNotFoundError` per model and credential for
  the rest of the app session, so only the first request after start walks
  the chain; later requests go straight to `openai/default`.
- **`tavli-dev` with free keys only**: `openai/default` answers `503` once and
  is skipped; the free models work as today.
- A newly set or removed provider secret is picked up on the next app start,
  because availability is remembered per session.

### Deadlines

Each allowlisted model has one timeout, the same value on both sides: the
gateway aborts the provider call at that timeout and answers `504 timeout`;
the client waits that timeout plus 15 s (function start, network, upload of a
photo) before it gives up and moves on. In the normal case the gateway
answers first, so the router does not start a fallback while the gateway's
attempt is still running; the client-first case is covered below. With the
current models the longest wait is 60 + 15 = 75 s,
under the 150 s Edge Function limit measured in the spike. Changing a model's
timeout changes `ChainConfig` and the gateway allowlist in the same PR.

If the client still times out first (a slow network or a stalled upload), it
treats the call as `TransientError(isTimeout: true)` and moves to the next
model, as today; it does not retry the same model. The gateway call keeps
running until its own deadline: it has already reserved its quota row, so it
counts as one call, and it releases the row when it finishes (or the 90 s
expiry applies). Its answer is discarded, never shown or saved. The
abandoned call and the next model's call can be in flight together, which is
why the per-user in-flight limit is 2 and not 1.

## Limits (Q1 proposal)

| Limit | Value | Why |
| --- | --- | --- |
| Body size | ≤ 1.5 MB | client downscales photos to ≤ 383 KB JPEG (spike) |
| Images | ≤ 1, `image/jpeg` or `image/png` data URL, vision tasks only | photo import sends one |
| `system` + `prompt` | ≤ 40 000 characters | refine sends the whole recipe; outline sends ≤ 60 library titles |
| Output | `max_tokens` ≤ 4096 | largest answer is 3 recipe summaries |
| Per user per UTC day | 30 vision + 150 text provider calls | a monthly plan is about 12 text calls, ×2 with retries |
| Per user per minute | 20 calls | stops loops and scripts |
| Per user at once | 2 calls in flight | a plan runs its calls one after another; more means a loop or script |
| All users per UTC day | 2 000 provider calls | shared cost ceiling for the paid key, whatever the number of users |

Every provider call counts, including one the router retries, because each
one costs. The numbers are environment settings (`AI_DAILY_VISION_LIMIT`,
`AI_DAILY_TEXT_LIMIT`, `AI_PER_MINUTE_LIMIT`, `AI_CONCURRENT_LIMIT`,
`AI_GLOBAL_DAILY_LIMIT`) with these defaults, so they can change without a
deploy. The cost ceiling counts calls, not money: with one paid model and
`max_tokens` capped, calls × the largest request bounds the daily cost, and
the provider's own spending limit stays the last line of defence.

### Reservation

Every limit is checked and consumed in one database transaction before the
provider call, so parallel requests cannot all pass the check and then all
spend:

- Table `ai_calls`: `id`, `user_id` (nullable, see account deletion),
  `kind` (`vision` or `text`), `started_at`, `finished_at` (null while in
  flight). One row per provider call; no prompt, model output or model name.
- `ai_reserve(user_id, kind)`, `security definer`, executable by
  `service_role` only. It takes a transaction-scoped advisory lock, counts the
  user's rows started in the last minute, today (UTC) for that kind and still
  in flight, plus all rows started today, and either inserts the row and
  returns its id, or returns which limit failed and when it frees up
  (`retryAfterSeconds`). A failed reservation inserts nothing.
- `ai_release(id)` sets `finished_at`. A row still in flight 90 s after
  `started_at` (longest deadline plus margin) no longer counts as in flight,
  so a crashed function cannot block the user; it still counts toward the
  minute and day limits.
- The lock is global, so reservations run one at a time. Each is a few index
  reads and one insert, which is fine at team scale; per-user locks plus a
  separate global counter are the upgrade if it ever becomes a bottleneck.
- Rows older than 2 days are deleted by the reservation function itself; no
  scheduled job is needed.

**Account deletion.** `delete_account_data` does not delete the account's
`ai_calls` rows; it sets their `user_id` to `null` (the foreign key is
`on delete set null`). The rows then hold no personal data (kind and times
only), still count toward the shared daily limit, and disappear with the
normal 2-day cleanup. Deleting an account therefore cannot reset the shared
count. A new account gets fresh per-user limits; that is accepted, because the
shared limit still bounds the total cost.

`authenticated` gets no access to the table or the functions. They are created
in a later slice with RLS enabled, explicit grants and a pgTAP test: two
accounts, each limit, parallel reservations past the limit, an expired
in-flight row, and account deletion keeping the shared count while removing
the user id.

## Secrets (set manually, never in the repo or chat)

Dev 4 (Anja) sets them in the Supabase dashboard, project → Edge Functions →
Secrets, first for `tavli-dev`, later for production. Agents never set, read or
print them.

| Name | Needed for | `tavli-dev` | Production |
| --- | --- | --- | --- |
| `GEMINI_API_KEY` | Gemini models | yes (free key, testing) | optional |
| `GROQ_API_KEY` | Groq models | if available (free) | optional |
| `OPENROUTER_API_KEY` | OpenRouter models | if available (free) | optional |
| `OPENAI_API_KEY` | OpenAI models (D3) | optional | yes, once bought |
| `OPENAI_MODEL` | model behind `openai/default` (D3) | with the OpenAI key | yes |

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` come from the platform, as for
`delete-account`. Rotation: replace the secret in the dashboard; no deploy or
app release. Emergency stop: remove the provider's secret (its models return
`503`), or set `AI_GATEWAY_DISABLED=1` (every call returns `503`).

## Privacy and logging

The gateway never logs tokens, prompts, images, model output or keys. It may
log the task, model, status and duration. `ai_calls` holds only user id, kind
and start/finish times, loses the user id when the account is deleted, and is
deleted after 2 days.

## Client changes (later slice)

- A built-in credential no longer carries a key; the chat client sends the
  request to `ai-gateway` instead of the provider. User keys keep the direct
  path. User model order, per-model cooldowns and the 014 validator are
  unchanged. `ChainConfig.defaults` changes in one way: `openai/default` is
  added as the last model of both default chains (vision and text).
- `GatewayQuotaError` and `GatewayAuthError` with the router handling in
  Gateway errors in `AIRouter`, the per-account, per-kind pause store, the
  gateway deadline from Deadlines, and `openai/default` in both default
  chains (see Model chain and `openai/default`).
- Cutover (FR-104): built-in keys are removed from `BuiltInKeys`,
  `secrets.example.json` and the build; a check proves the built app contains
  no provider key.

## Delivery slices

1. This contract (docs only), approved by Dev 4.
2. `ai_calls` migration + `ai_reserve`/`ai_release` + pgTAP test.
3. `ai-gateway` function with tests using a fake provider, and its deploy line
   in `deploy-supabase.yml`.
4. Client: gateway path in the chat client, the two gateway errors and their
   router handling, tests with the fake adapter (quota with and without a user
   key, `401` with a platform body, refresh then success, deadline).
5. Cutover: remove built-in keys from the app, docs and release checklist.

Local limits: this machine has no Docker or Deno, so slices 2–3 need a
teammate's local stack (`supabase test db`, `supabase functions serve`) or a CI
job for function tests; hosted runs happen only through
`deploy-supabase.yml`.

## Decisions

| # | Question | Proposal | Owner |
| --- | --- | --- | --- |
| D1 | Who builds prompts | The app sends `system`/`prompt`; the gateway checks task, model, size and quota. Server-side prompt templates would stop arbitrary prompts but move all prompt code to TypeScript; deferred. Accepted risk: a signed-in user can send any prompt within their quota. | Dev 2, review Dev 4 |
| D2 | Limits | Values in Limits above | Dev 2 + Dev 4 |
| D3 | Paid provider and model | OpenAI as `openai/default`, one model for vision and text, resolved from `OPENAI_MODEL` on the server. Choice: a fast small (mini-class) multimodal model, picked by running the TRELLO-35 photo set, a few dish-name recipes and one plan through 2–3 candidates once the key exists (errors, time, cost per request). Reasoning models only at their lowest effort, because of the 60 s deadline. The app needs no OpenAI client, because only the gateway calls it. | team (2026-11-17), model pick pending the test |
| D4 | Free keys | Stay available for testing as gateway secrets on `tavli-dev`; removed from the app build at cutover | team (2026-11-17) |
| D5 | Sync vs queue | Synchronous, one model attempt per call (spike decision A) | team (Q2) |
