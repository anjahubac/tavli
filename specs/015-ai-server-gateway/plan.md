# Implementation plan: Authenticated gateway for built-in AI

**Status**: quota migration merged. The Edge Function, deploy wiring and Flutter
gateway route are in the local implementation. Durable client quota pauses,
integration review and release verification remain open.
**Spec**: [requirements](spec.md) | **Lead/review**: Dev 2 / Dev 3
**Baseline**: dev 207c94c; every implementing branch starts from then-current origin/dev.

## Existing boundaries and proposed files

- **Server**: `supabase/functions/ai-gateway/`, `supabase/config.toml`,
  `.github/workflows/deploy-supabase.yml` (Dev 3 with Anja for release). Reuse
  `ai_reserve` and `ai_release` from merged PR #124.
- **Flutter transport**: new `lib/ai/gateway_chat_client.dart`; existing
  `lib/ai/ai_models.dart`, `recipe_ai.dart`, `meal_plan_ai.dart`,
  `repair_prompt.dart`, `ai_errors.dart`, `ai_router.dart`, `chain_config.dart`
  and `key_store.dart` (Dev 2). Dev 2 coordinates `lib/providers.dart` wiring
  with Dev 3 for session lifecycle and Anja for the client rollout.
- **Local storage**: `lib/data/database.dart` and generated
  `lib/data/database.g.dart`, with the next drift version coordinated by Dev 1.
  Extend `test/data/migration_test.dart`; see [data model](data-model.md).
- **Settings and cutover**: `BuiltInKeys` and `builtInKeysProvider` are removed
  from the client, its tests and the shared fixture, with the built-in AI build
  parameters ([PR #157](https://github.com/anjahubac/tavli/pull/157)). Release inputs still need a check.

## Contract and data plan

Built-in provider credentials live server-side after cutover. BYOK stays device-secure. Gateway validates identity without accepting client-supplied ownership.

Producer dependencies: [012](../012-security-baseline/spec.md), [014](../014-ai-response-contracts/spec.md)

Use [shared boundaries](../011-team-development/contracts/shared-boundaries.md)
and the [contract template](../../.specify/templates/contract-template.md).
Before implementation, record typed fields, validation, identity/units/CivilDate,
error/retry/undo, ownership, compatibility and producer/consumer fixtures. If data
changes, add data-model.md with current→target columns and a reviewed migration;
allocate drift version only after preceding schema merges. New SQL is additive
where possible, with RLS/grants and local two-account tests. Applied SQL is immutable.
If no schema change is needed, explicitly record that decision in the slice PR.

## Delivery slices

1. Resolve only blocking decisions; map each source requirement to existing code,
   identify work already present and record remaining effort. Never redo completed
   behavior simply because a source ticket is unassessed.
2. Merge the agreed contract/fixtures first; no consumer branch stacks on an
   unmerged producer. Independent research/tests may proceed in developers' existing
   checkouts, with one active writer per checkout; no automatic extra worktrees.
3. Implement one source task vertically through affected layers with test-first
   logic/parsing and ownership review. Keep phase boundaries in tasks.md.
4. Integrate consumers after producer merge, preserving offline/replay and previous
   UI/quantity behavior. Run relevant 012/013 gates and update real evidence.

## Flutter integration

1. Add a typed task to `AIRequest` and set it at the five facade call sites:
   `recipe_from_image`, `recipe_from_name`, `recipe_refine`, `plan_outline`
   and `recipe_summaries`. Preserve that task when `repairRequest` copies the
   request. Keep request building and the 014 validator on the device.
2. Add a fakeable adapter backed by the existing Supabase client and signed-in
   session. Call GET for ordered shared model IDs and POST for one model attempt.
   Use the session JWT and pass `task`, model ID, prompts, temperature and optional
   data URL. The adapter maps typed errors and applies the per-model deadline
   plus the transport allowance. Keep `OpenAICompatibleClient` for BYOK and
   its settings model checks. No new package is required.
3. Route personal keys directly in the existing user model order and shared
   attempts through the gateway in the order returned for the request kind.
   Represent shared availability without an API key value. Reuse the same
   router for model fallback and one schema repair on the same route. Unknown
   advertised model IDs are ignored until the client supports them. A failed
   discovery leaves eligible BYOK attempts available.
4. On a gateway 401, refresh and replay at most once per run while the same
   account is active. A provider 429 pauses that model and allows fallback.
   A gateway quota records a pause for the account with the applicable scope
   and skips shared attempts during that pause. Recheck cancellation and the
   original account after awaited operations before retries and before parsing
   or returning results. Route terminal failures to safe Serbian UI copy.
5. Remove `BuiltInKeys.fromEnvironment` and its legacy consumers in the
   cutover (removed in [PR #157](https://github.com/anjahubac/tavli/pull/157); artifact check still open). Update test overrides and eval fixtures to use fake transports or
   explicitly supplied personal credentials as appropriate. Preserve provider
   key management for user-entered keys. Build with the Supabase URL and public
   client key, then verify that shared provider credential defines and values
   are absent from the release artifact.

## Constitution check (3.0.0)

| Gate | Required response before implementation |
| --- | --- |
| I | English docs; exact Serbian Latin UI/copy for changed screens |
| II | Preserve outbox/account scope; explicit personal/device/reference classification |
| III | Any AI through AIRouter and validated task contract; N/A documented if none |
| IV | No real secrets/logged private content; apply 012 trust-boundary controls |
| V | Test-first logic/parsing; local SQL/Edge tests when backend changes |
| VI | Phone/wide/text/motion/keyboard proof for UI; N/A for technical-only slice |
| VII | Reviewable task slices; generated files via generator only |
| VIII | This canonical spec, owned dev-based branch/task IDs, no stacking |
| IX | Existing paths/interfaces; justify dependencies and migration decisions |
| X | Named human reviewer, producer/consumer contract and schema coordinator |

These are design obligations, not executed pass results. Any violation blocks Ready
until resolved under governance. No dependency is added by this documentation;
implementer records each proposed package/service with a reason before adoption.

## Verification, rollout and risks

Use [testing 013](../013-testing-strategy/spec.md), its journey matrix, and
[security 012](../012-security-baseline/spec.md). Tests must prove the scenarios
in spec.md and source task outcomes using synthetic data/fake AI. Default Flutter
tests do not contact a network; explicit guarded integration uses local services.
No speculative hosted deployment or publication. Record old-client/snapshot
compatibility, pending-outbox migration, failure/undo and forward recovery for
state changes. No destructive reset as a migration. Platform/source/legal/retention
limits from open questions remain release gates. UI follows the design canvas and the
UI standard; do not invent layouts or move components into the package incidentally.

Local server evidence on baseline `cd29e6b` plus the gateway diff: seven Deno
tests, type checking, lint and a simulated Auth → quota RPC → provider →
release smoke passed. Authenticated integration on an ephemeral local Supabase
stack and manual dev-device smoke remain open. After the server merge, verify a
dev build with only Supabase configuration on recipe name, photo import and meal
plan. Use fake services for automated suites. Record the real manual dev result,
key-free artifact evidence and rollback procedure in [033](../033-release-operations/contracts/release-evidence.md).
