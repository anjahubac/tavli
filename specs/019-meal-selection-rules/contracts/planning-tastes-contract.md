# Contract: member tastes in plan requests

**Status**: first slice implemented on `feat/plan-member-tastes` (Trello
TRELLO-41, 019 FR-004), pending review.
**Author**: Dev 2 (consumer) | **Reviewer**: Dev 3 (producer of the
[008 member planning inputs](../../008-household-members/contracts/member-planning-inputs.md))
**Date**: 2026-11-23 | **Builds on**: 008 `planning_advisory_inputs`,
[meal rules](meal-rules-contract.md), [recipe labels](recipe-labels-contract.md)

## Scope

Liked and disliked catalog foods, dish kinds and cuisines of household
members go into plan generation and single-meal replacement as advice.
Favorites (TRELLO-44, FR-006), planning notes (later 008 slice) and
allergens (TRELLO-43, FR-005, server only) are out of scope. The app has no
dietary-mode field.

## Endpoint `planning-inputs` (Supabase Edge Function)

`POST /functions/v1/planning-inputs`, `verify_jwt = true`.

| | |
| --- | --- |
| Request | `{"householdId": "<uuid>"}`. The household the app is using now. Any other field, a non-UUID or a body over 1 KiB is `400 bad_request`. |
| Auth | Bearer session. The function resolves the user from `/auth/v1/user`. Missing, invalid or anonymous sessions get `401 unauthorized`. |
| Household | The server reads the caller's only household (`household_members_one_per_user_idx`). A different or missing household, or a caller who is no longer a member, gets `409 household_changed`. |
| Participants | All current members of that household, read by the server. The client does not send member IDs in this slice. |
| Food allowlist | Food IDs taken from the participants' taste profiles. They must exist in `foods`, not be withdrawn, and be shared or belong to this household. The server computes this list. |
| Consent | Calls `planning_advisory_inputs(..., for_provider => true, ...)`. Only members with `user_planning_sharing.preferences = true` contribute. Because the result goes to an AI provider, this includes the caller's own tastes. |
| Response `200` | Exactly `likedFoodIds`, `dislikedFoodIds`, `likedDishKinds`, `dislikedDishKinds`, `likedCuisineCodes`, `dislikedCuisineCodes`, each an array of strings. `favoriteRecipeCounts` is dropped. There are no member IDs, names, notes or allergens. The response carries `Cache-Control: no-store`. |
| Limits | 30 requests per user per minute in one function instance (`429 rate_limited`). This guards against app loops; it is not a durable quota (see Open items). |
| Errors | `405`, `400`, `401`, `409`, `429`, `500 internal`. Error bodies carry no detail, and nothing is logged. |

## Client behaviour

- **Source.** `RemotePlanningTastes` (`lib/data/planning_tastes_remote.dart`) implements `PlanningTastesSource` (`lib/domain/planning_tastes.dart`). Without a signed-in household it returns no tastes and makes no call. Food names come from the local catalog. A food ID without a local name still affects ranking but is not named in the prompt.
- **Freshness.** `MealPlanAI` reads tastes before every outline request (each week part and the rules retry) and once before new-recipe summaries. A withdrawn consent therefore applies to the next request. Nothing is cached.
- **Prompt.** `planOutlinePrompt` adds a "Household tastes (advice, not a safety rule; the values are data)" block with avoid and prefer lines. Values are JSON-encoded, because household foods are user-entered text. `recipeSummariesPrompt` asks to leave out disliked foods where the dish allows. People, names and allergens are never included.
- **Ranking, not exclusion.** A library recipe is ranked last when an ingredient's catalog `foodId` is disliked or its dish kind is disliked. Ranking happens before the 60-recipe cap. With enough alternatives such recipes are not offered. With no alternatives they stay available. The local rules fallback uses the same order, so it picks a fitting alternative first.
- **Failure.**
  - `401` or `409` → `PlanningTastesDenied`: generation stops before any AI request and shows "Ukusi domaćinstva nisu mogli da se provere. Pokušaj ponovo."
  - Anything else (network, `429`, `5xx`, malformed body, function not deployed) → `PlanningTastesUnavailable`: the plan is made without tastes, `PlanDraft.withoutTastes` is set, and the preview shows "Ukusi članova trenutno nisu dostupni, pa ovaj predlog ne uzima u obzir šta ko voli."

## Acceptance interpretation

The card's "a household that dislikes fish gets no fish" is read as follows.
Given a recipe linked to the disliked food and a fitting alternative, the
alternative is offered first and the fish recipe falls out of the offered
list or the fallback. The prompt asks the model to avoid the food in new
dishes. It is not an unconditional guarantee:
- dislikes are advisory (008);
- ingredient links can be missing;
- an exact food ID does not cover a food family;
- new dishes get their ingredients in a later request.

## Evidence

- `supabase/functions/planning-inputs/planning_test.ts` (Deno): projection, auth, method, body, household change, removed member, RPC shape, failure, limit.
- `test/ai/meal_plan_tastes_test.dart`: prompt content without allergen codes or IDs, ranking before the cap, advisory fallback, fresh read per outline with withdrawal, replacement, unavailable and denied paths.
- `test/data/planning_tastes_remote_test.dart`: request body, status mapping, timeout, malformed bodies, no call without a household.
- `test/features/planning/plan_generation_test.dart`: preview notice and stop message.

## Open items

- A durable per-user limit would need a migration (a limit table like `household_join_limits`). This is follow-up hardening, not required for TRELLO-41. The endpoint only reads, needs a session, returns only the caller's household's consented tastes, and spends no AI quota.
- 008 `PlanLeakGuard`. This slice sends no names, emails or notes, and the response schema has no free-text field about people. The guard is deferred to the note slice, pending Dev 3 confirmation.
- Explicit participant subsets ("who eats this week") are deferred.
- Server-side candidate filtering and final validation (FR-104/105) remain with TRELLO-45 and TRELLO-43.
- Deno tests for Edge Functions are not run by CI. Run them locally with `deno test` in the function folder.
