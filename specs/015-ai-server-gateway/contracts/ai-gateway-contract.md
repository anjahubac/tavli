# Contract: Edge Function `ai-gateway`

**Status**: proposal for review (Trello #36, spec 015 FR-002, Q1). Nothing here
is implemented yet.
**Author**: Dev 2 | **Reviewer**: Dev 4 (card #36: request and error format)
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
`ChainConfig.defaults`, plus `openai/default` once that key exists (D3). The
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
4. Check and consume the caller's quota (see Limits) → `429 quota_exceeded`.
   A request rejected in steps 1–3 does not count.
5. Exactly one provider call, `max_tokens` capped at 4096, hard deadline 60 s.
   No retry and no fallback inside the gateway (decision A): the app's
   `AIRouter` stays the single retry/fallback owner (FR-103).
6. Return the model's text, or a typed error.

## Responses

| Status | Body | App mapping (`AIError`) | User sees |
| --- | --- | --- | --- |
| 200 | `{"content": "<model text>", "model": "<provider>/<model>"}` | — | result after 014 validation |
| 400 | `{"error": "bad_request"}` | `BadRequestError`, next model | existing message |
| 401 | `{"error": "unauthorized"}` | refresh session once and retry; then stop the chain | “Sesija je istekla. Prijavi se ponovo.” (006 copy) |
| 413 | `{"error": "too_large"}` | `BadRequestError`, stop | existing message |
| 429 | `{"error": "quota_exceeded", "retryAfterSeconds": n}` | `RateLimitError(isDaily: true)`; stop the chain (the quota is per user, not per model) | “Limit je trenutno potrošen. Pokušaj malo kasnije.” |
| 429 | `{"error": "provider_rate_limited", "retryAfterSeconds": n?}` | `RateLimitError` for this model, next model | — |
| 502 | `{"error": "provider_error"}` | `TransientError`, next model | — |
| 503 | `{"error": "model_unavailable"}` | `ModelNotFoundError`, next model | — |
| 504 | `{"error": "timeout"}` | `TransientError(isTimeout: true)`, next model | — |
| 500 | `{"error": "internal"}` | `TransientError`, next model | — |

Error bodies never contain provider responses, prompts, keys or stack traces
(012). The client timeout for a gateway call is the model timeout plus 10 s, so
the gateway's 60 s deadline answers first.

## Limits (Q1 proposal)

| Limit | Value | Why |
| --- | --- | --- |
| Body size | ≤ 1.5 MB | client downscales photos to ≤ 383 KB JPEG (spike) |
| Images | ≤ 1, `image/jpeg` or `image/png` data URL, vision tasks only | photo import sends one |
| `system` + `prompt` | ≤ 40 000 characters | refine sends the whole recipe; outline sends ≤ 60 library titles |
| Output | `max_tokens` ≤ 4096 | largest answer is 3 recipe summaries |
| Per user per UTC day | 30 vision + 150 text provider calls | a monthly plan is about 12 text calls, ×2 with retries |
| Per user per minute | 20 calls | stops loops and scripts |

Every provider call counts, including one the router retries, because each
one costs. The numbers are environment settings (`AI_DAILY_VISION_LIMIT`,
`AI_DAILY_TEXT_LIMIT`, `AI_PER_MINUTE_LIMIT`) with these defaults, so they can
change without a deploy.

Counting needs a small server table (`ai_usage`: user, UTC day, kind, count)
written only by the function through a `security definer` function executable
by `service_role`; `authenticated` gets no access. It is created in a later
slice with RLS, grants, a two-account pgTAP test and deletion through
`delete_account_data`.

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
log the task, model, status and duration. `ai_usage` holds only user id, day,
kind and count.

## Client changes (later slice)

- A built-in credential no longer carries a key; the chat client sends the
  request to `ai-gateway` instead of the provider. User keys keep the direct
  path. `ChainConfig`, user model order, cooldowns and the 014 validator are
  unchanged.
- Cutover (FR-104): built-in keys are removed from `BuiltInKeys`,
  `secrets.example.json` and the build; a check proves the built app contains
  no provider key.

## Delivery slices

1. This contract (docs only), approved by Dev 4.
2. `ai_usage` migration + quota function + pgTAP test.
3. `ai-gateway` function with tests using a fake provider, and its deploy line
   in `deploy-supabase.yml`.
4. Client: gateway path in the chat client and router mapping, tests with the
   fake adapter.
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
| D3 | Paid provider and model | OpenAI as `openai/default`, one model for vision and text, resolved from `OPENAI_MODEL` on the server. Choice: a fast small (mini-class) multimodal model, picked by running the #35 photo set, a few dish-name recipes and one plan through 2–3 candidates once the key exists (errors, time, cost per request). Reasoning models only at their lowest effort, because of the 60 s deadline. The app needs no OpenAI client, because only the gateway calls it. | team (2026-11-17), model pick pending the test |
| D4 | Free keys | Stay available for testing as gateway secrets on `tavli-dev`; removed from the app build at cutover | team (2026-11-17) |
| D5 | Sync vs queue | Synchronous, one model attempt per call (spike decision A) | team (Q2) |
