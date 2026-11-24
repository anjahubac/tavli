# Specification: Authenticated gateway for built-in AI

**ID**: 015-ai-server-gateway | **Feature key**: AI-GATEWAY
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Implementation in progress. Quota reservation, the Edge Function and
the Flutter transport are merged to dev ([PR #124](https://github.com/anjahubac/tavli/pull/124),
[PR #127](https://github.com/anjahubac/tavli/pull/127)). Durable client quota pauses,
verification on dev and production rollout are pending.
**Lead**: Dev 2 | **Proposed independent reviewer**: Dev 3

## Scope and source

Implements the AI-GATEWAY portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Spike: send an image request through the gateway**. Source D2-003; Dev 2; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Move built-in AI credentials behind the server**. Source D2-004; Dev 2; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: First spike an image request through a local gateway with fake/provider-independent timing data; evaluate deployed limits through authorized setup before choosing sync versus queued transport.
- **FR-102**: Allowlist tasks/models/destinations and enforce request size, token/cost, user quota and concurrency budgets before provider work.
- **FR-103**: Preserve AIRouter/facade APIs, cancellation, retry-after and bounded fallback; designate one retry owner across client/server.
- **FR-104**: Release cutover removes built-in provider values from client builds, retains BYOK and includes operator disable/rotation procedure. The Flutter app sends the signed-in user's Supabase access token on built-in requests.
- **FR-105**: The gateway advertises the ordered list of available shared models for text and photo input. Gemini, Groq and OpenRouter are the initial providers. Once explicitly enabled in an environment, OpenAI is the first shared model for both kinds, with the remaining models as fallbacks. BYOK keeps precedence and uses the direct path.
- **FR-106**: Every built-in completion identifies its task explicitly, including schema repair. A provider rate limit permits fallback. A gateway quota stops shared attempts for the affected account and kind, while eligible user keys remain available. An authentication failure can trigger one session refresh and one replay for the same account.

## User scenarios and acceptance

- **US1 / SC-001**: Invalid token, forged uid or arbitrary provider URL produces zero provider calls.
- **US2 / SC-002**: A valid bounded request succeeds; concurrent quota exhaustion returns a safe retryable limit without duplicate expensive retries.
- **US3 / SC-003**: A signed-in build with only Supabase configuration generates a recipe by name, imports a recipe from a photo and generates a meal plan. Request evidence shows the expected task IDs and a gateway destination. Direct traffic occurs only when a user key is selected.
- **US4 / SC-004**: Model discovery consumes no provider quota. OpenAI is absent from both shared model lists before opt-in and first in both lists after opt-in. A rejected OpenAI attempt can fall back to the remaining models. The client handles this change without recompilation.
- **US5 / SC-005**: Cancellation or account switch prevents further attempts and suppresses results from the old run. An expired session retries at most once. A daily text quota persists across restart without blocking photo input, other accounts or BYOK.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

- **Privacy**: Recipe prompts and an optional photo go to the selected provider for generation or extraction. The gateway keeps them out of logs and quota records. The local quota pause is device-only and account-scoped.
- **Abuse**: The gateway validates the authenticated caller, allowlisted task and model, payload size and configured budgets before provider work. Dev 2 owns the kill switch and quota policy.
- **Credentials**: Shared provider keys live in Edge Function Secrets; app builds have none. BYOK stays device-secure. Flutter sends the session token to Supabase and sends a personal AI key only to its configured provider.
- **Files**: Photo import sends one bounded image in the request body. Gateway storage writes, image generation, photo paths and new file retention are out of scope. Generated recipe artwork is tracked separately on [Trello 130](https://trello.com/c/te8lAjwG/130-ai-slike-recepata-server-red-%C4%8Dekanja-prikaz-i-zamena).
- **Deployment**: Deploy the reviewed server to `tavli-dev` before switching builds. Verify a key-free client and an operator rollback before production. Record evidence through [033](../033-release-operations/contracts/release-evidence.md).

## Exact UI copy carried forward

“Limit je trenutno potrošen. Pokušaj malo kasnije.”, “Sesija je istekla. Prijavi se ponovo.”,
“AI trenutno nije dostupan.”, “Zahtev nije uspeo. Pokušaj ponovo.”, “Otkaži”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [012](../012-security-baseline/spec.md), [014](../014-ai-response-contracts/spec.md)

- **Q1** (Dev 2 with reviewer): Concrete quota/size/time budgets, service plan limits, rotation/cutover and key-free artifact verification?
  The [base contract](contracts/ai-gateway-contract.md) was approved in
  [PR #47](https://github.com/anjahubac/tavli/pull/47). Dev 4 requested
  OpenAI opt-in as the first built-in model for text and vision on 2026-11-22.
  Production model selection and release evidence remain pending.
- **Q2** (Dev 2 with reviewer): Does image processing fit synchronous limits or need a queued job? Decide from the spike.
  Spike 2026-11-17: [spike-photo-timing.md](spike-photo-timing.md). One attempt fits (slowest success 15.4 s,
  limit 150 s); the full fallback chain can exceed it. Proposed: synchronous gateway with one model attempt per
  call, client `AIRouter` keeps fallback. Accepted by the team (option A, TRELLO-35).

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
