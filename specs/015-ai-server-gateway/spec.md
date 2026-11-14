# Specification: Authenticated gateway for built-in AI

**ID**: 015-ai-server-gateway | **Feature key**: AI-GATEWAY
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
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
- **FR-104**: Release cutover removes built-in provider values from client builds, retains BYOK and includes operator disable/rotation procedure.

## User scenarios and acceptance

- **US1 / SC-001**: Invalid token, forged uid or arbitrary provider URL produces zero provider calls.
- **US2 / SC-002**: A valid bounded request succeeds; concurrent quota exhaustion returns a safe retryable limit without duplicate expensive retries.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Built-in provider credentials live server-side after cutover. BYOK stays device-secure. Gateway validates identity without accepting client-supplied ownership.

## Exact UI copy carried forward

“Limit je trenutno potrošen. Pokušaj malo kasnije.”, “Otkaži”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [012](../012-security-baseline/spec.md), [014](../014-ai-response-contracts/spec.md)

- **Q1** (Dev 2 with reviewer): Concrete quota/size/time budgets, service plan limits, rotation/cutover and key-free artifact verification?
- **Q2** (Dev 2 with reviewer): Does image processing fit synchronous limits or need a queued job? Decide from the spike.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
