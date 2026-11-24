# Contract: allergen-safe household plans

**Status**: implemented on `feat/plan-allergen-safe` (Trello TRELLO-43,
019 FR-005/FR-104/FR-105, and TRELLO-45, 019 FR-007), pending review.
**Author**: Dev 2 (planner) | **Reviewers**: Matija (008 contract owner,
product decision below), Dev 1 (catalog allergen data)
**Date**: 2026-11-24 | **Builds on**: [008 allergen protection](../../008-household-members/contracts/member-planning-inputs.md#allergen-protection),
[planning tastes](planning-tastes-contract.md), [meal rules](meal-rules-contract.md),
`foods.allergen_codes` (PR #162)

## Product decision (pending Matija's approval in the PR)

The strict rule applies **only when at least one household member has an
allergy** (a non-empty union of member allergen codes). Otherwise planning
works as before: every saved recipe is a candidate and the AI may propose new
dishes.

| Household | Candidates | New AI dishes |
| --- | --- | --- |
| No member allergy | All saved recipes with steps | Allowed, as before |
| At least one member allergy | Only server-verified safe saved recipes | Not allowed; the slot stays empty |

Why: until ingredient links exist (TRELLO-21), no recipe is fully linked. A
strict rule for every household would leave every plan empty while protecting
nobody. Accepted cost: a member can infer that someone in the household has
an allergy. 008 already accepts that members may know each other's
allergens.

## Endpoint: `planning-inputs` with `recipeIds`

The [planning tastes](planning-tastes-contract.md) endpoint accepts a second
request shape. Auth, household check (`409 household_changed`), participants
(all current members, read by the server), `Cache-Control: no-store`, and no
logging are unchanged.

| | |
| --- | --- |
| Request | `{"householdId": "<uuid>", "recipeIds": ["<id>", ...]}`. At most 1000 strings. IDs outside `[A-Za-z0-9_-]{1,64}` are dropped (unknown, so never safe). Any other field, a non-array or a body over 80 kB is `400 bad_request`. |
| Union | `planning_allergen_codes(actor, household, all members)` (service role). An unknown code is `500 internal` (fail closed). |
| Response, no allergy | `{"restricted": false}`. No recipe or food is read. |
| Response, allergy | `{"restricted": true, "safeRecipeIds": [...]}`: the requested recipes of **this household** that pass the rule below, sorted. No allergen codes, no members. |
| Limits | 60 requests per user per minute in one instance, shared with tastes. |

**Safe recipe** (`plan_eligibility.ts`): the ingredient list is non-empty and
**every** ingredient has a flat link (`foodId`, `matchedKey`, `linkSource`
`matched` or `confirmed`) whose `matchedKey` equals `ingredientKey(name)`. Each
linked food exists, is not withdrawn, is a shared catalog food with a review
(`allergen_codes` not null, `allergen_reviewed_at` set), has only known codes,
and none of them is in the union. Anything unknown is unsafe: an unlinked salt,
a renamed ingredient, a household food, an unreviewed food. `ingredientKey`
matches the Dart function; both sides test the shared fixture
`supabase/functions/planning-inputs/testdata/ingredient_keys.json`.

## Client behaviour

- **Source.** `RemotePlanSafety` (`lib/data/planning_tastes_remote.dart`)
  implements `PlanSafetySource` (`lib/domain/plan_safety.dart`). Without a
  household it returns unrestricted and makes no call.
- **Before every outline** (each week part and the rules retry), `MealPlanAI`
  sends the IDs of saved recipes with steps (at most 1000). When restricted:
  - only safe recipes are ranked and offered;
  - the prompt says to use only listed recipe IDs and to return
    `"recipeId": null` when nothing fits;
  - `parseOutline(allowNew: false)` treats a null ID as an empty slot and
    rejects any ID outside that meal's list (one repair attempt).
- **Per-meal candidates (TRELLO-45).** For every household, the Library is
  filtered per meal type before the 60-recipe cap. A recipe passes when its meal
  label (if any) matches and its weight and dish kind do not break the slot
  rules. Each meal type in the request gets an equal share of the cap. The AI
  must choose a recipe from that meal's list, and the rules fallback uses the
  same list.
- **Final check.** Before the draft is returned, the planner checks every
  proposed saved recipe again. If the household is restricted, every proposal
  that is not safe now (including a new AI dish) is removed, and its slot stays
  empty. This covers an allergy or a recipe edit made during generation, and
  single-meal replacement, which uses the same `propose` path.
- **Failure.** `401`/`409` → `PlanningTastesDenied` (stop, as for tastes).
  Anything else → `PlanSafetyUnavailable`: no plan and no AI request.
  Message: "Ograničenja domaćinstva trenutno ne mogu da se provere, pa plan
  nije napravljen. Pokušaj ponovo." Without the check, the app cannot know
  whether someone has an allergy.
- **Empty slots.** `PlanDraft.householdRestricted` is set. When slots stay
  empty, the preview shows "Za neke obroke nema recepta koji odgovara
  ograničenjima domaćinstva." The existing incomplete-draft flow lets the
  person save explicitly or try again.

## Known limits

Recorded for review; not solved in this slice.

- **Client-orchestrated.** The server filters and re-checks, but the app
  builds the AI request and applies the result. A modified client could skip
  the check. 008 treats the household as trusted. A server-owned planner,
  where the gateway builds the prompt and stores the validated draft, is later
  work.
- **Server copy.** The server checks the uploaded recipe. A recipe edited
  offline and not yet uploaded is checked in its old form. A recipe that was
  never uploaded is unsafe.
- **Paths outside `propose`.** A recipe picked manually from the library,
  kept/locked meals in regeneration, and later recipe edits that refresh saved
  plan snapshots are not re-checked.
- **Coverage.** A matching `matchedKey` detects a rename. It does not prove
  that the food ID was assigned correctly. Real coverage depends on TRELLO-21
  links and Dev 1's reviewed catalog data.
- **Guards.** The client never receives allergen codes, so the prompt cannot
  contain them (tests assert this). The full 008 guard set (import-boundary
  test, transport outbound guard, end-to-end canary across providers) belongs
  to the server-owned planner.

## Evidence

- `supabase/functions/planning-inputs/plan_eligibility_test.ts`: safe and unsafe
  recipes, unknown is never safe, the shared key fixture, union parsing.
- `supabase/functions/planning-inputs/planning_test.ts`: unrestricted without a
  union (no recipe read), only safe IDs with no allergen or member in the body,
  malformed lists, unexpected ID forms, unknown code, household change.
- `test/ai/meal_plan_safety_test.dart`: unchanged unrestricted plan, closed
  prompt and Library, empty slots without summaries, rejection of new or
  unsafe IDs, final-check removal, unavailable check stops before AI, and
  replacement.
- `test/ai/meal_plan_ai_test.dart` (group "kandidati po obroku"): filtering
  before the cap, per-meal ID check, fallback from the meal's list.
- `test/data/plan_safety_remote_test.dart`: request body, status mapping,
  timeout, malformed bodies, unknown returned ID, no call without a household.
- `test/domain/ingredient_key_fixture_test.dart`: Dart side of the shared fixture.
