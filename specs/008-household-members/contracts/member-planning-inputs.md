# Contract: member inputs for household planning

**Status**: initial design merged in PR #77; server-only allergen revision and implementation details pending review. **Spec**: 008 FR-001 (D3-001); consumer: 019 FR-004–FR-007. **Producer**: Dev 3; **reviewers**: Dev 2 (planner) and Dev 1 (catalog/schema). **Product decisions**: Matija, 2026-11-20 and 2026-11-21 (allergens server-only).

## Scope and existing state

PR #77 recorded the initial types, signatures and scenarios as documentation. The logic-first sequence and storage shape are in the [plan](../plan.md) and [data model](../data-model.md). Today `taste_profiles` is owner-only JSON, ratings are personal, and recipes have the nine `DishKind` values. Allergen and favorite storage and the server planning reads are implemented on the 008 work branch. Reviewed food catalog data and gateway integration are pending. Do not expose personal profile or diary rows to household members.

## Inputs

- `participantUserIds`: a nonempty set of distinct account IDs. The planner defaults this to all current household members, but always passes it explicitly. The producer verifies every ID against the active household; a foreign or removed ID fails the whole request.
- Personal allergy selections use canonical allergen **group codes**, separate from food IDs. Canonical application codes for the [14 EU Annex II groups](https://food.ec.europa.eu/food-safety/campaign-2026/allergies_en): `gluten`, `crustaceans`, `eggs`, `fish`, `peanuts`, `soy`, `milk`, `nuts`, `celery`, `mustard`, `sesame`, `sulphites`, `lupin`, `molluscs`. Dev 1 owns the catalog checker and reviews mapping and provenance; regulatory exceptions and sulphite thresholds require care. Lactose avoidance is outside this allergy list. Foods may carry reviewed group mappings; an unmapped ingredient has unknown allergy status, never safe status.
- Personal favorite identity is `(user_id, recipe_id)`. Only recipes currently visible in the active household can contribute. Remove the favorite when the recipe is deleted or the user leaves/loses household access.
- Personal tastes have `likedFoodIds`, `dislikedFoodIds`, `likedDishKinds`, `dislikedDishKinds`, `likedCuisineCodes`, `dislikedCuisineCodes`, and an optional short `planningNote`. The initial supported cuisine codes are `serbian`, `italian`, `japanese`, `french`, `mexican`. Dev 2 should use these codes in the planner. Free text is accepted only in `planningNote`, whose UI explains that it contributes to shared plans. `DishKind` reuses the existing nine wire values (`soup`, `cooked`, `baked_fried`, `pasta`, `salad`, `pie_pizza_sandwich`, `eggs_breakfast`, `cold`, `sweet`); grill is covered by `baked_fried`. No dietary-mode field or user-defined style code in this slice. A like/dislike is advisory, never a safety prohibition. A conflicting like and dislike resolves in favor of the dislike for ranking, not a hard exclusion.

The first structured release omits notes from collection, aggregate payloads and
provider requests. The optional field and its independent default-off consent
are reserved for the later note slice.

## Typed boundary (target signature)

```dart
abstract interface class MemberPlanningInputsRepository {
  Future<PlanningMemberInputs> forParticipants({
    required AccountScope scope,
    required Set<String> participantUserIds,
  });
}

class PlanningMemberInputs {
  final Set<String> likedFoodIds;
  final Set<String> dislikedFoodIds;
  final Set<DishKind> likedDishKinds;
  final Set<DishKind> dislikedDishKinds;
  final Set<String> likedCuisineCodes;
  final Set<String> dislikedCuisineCodes;
  final List<String> planningNotes; // bounded, explicitly shared for planning
  final Map<String, int> favoriteRecipeCounts; // recipe ID -> number of participants
}

/// Owner-only, default false for every flag; only the owner can change it.
class PlanningSharing {
  final bool preferences; // likes/dislikes and favorites
  final bool planningNote;
}
```

Names are proposed for Dev 2 review; the planner sets provider payload bounds. The result contains no member IDs, names, email, profile, diary or raw personal rows, and only fields covered by [Disclosure and consent](#disclosure-and-consent). The caller receives only a purpose-limited planning view. An empty `participantUserIds` set is invalid. Allergens are deliberately absent from this type: they never reach the client, the prompt or the AI (see [Allergen protection](#allergen-protection)). A failed membership check returns a typed authorization error and no partial result. Cancellation/fetch failure preserves existing local data. Food/recipe validation, not this member aggregate, reports unresolved ingredient mappings.

Example: `forParticipants(scope: activeScope, participantUserIds: {'ana-id', 'marko-id'})` returns the consented merged advisory tastes and favorite counts for visible recipes. If Ana likes `fish-id` and Marko dislikes it, it ranks lower. Allergens are applied only by the server plan endpoint, described below.

## Disclosure and consent

Aggregation is not anonymization: a household may have one or two members, so a single-participant result is attributable to that person. Consent, not aggregation, is the control.

- **Per-field consent.** Each member owns `PlanningSharing` with two independent flags: `preferences` (likes/dislikes and favorites) and `planningNote`. All default to **false** (opt-in). Only the owner can read or change them (owner-only RLS); the UI asks once and explains that shared fields reach other members' plans and the AI provider; consent may be withdrawn at any time. Allergens have no sharing flag because they are never shared (see below).
- **Server-side filtering.** The producer (a server function checking household membership) reads each participant's flag and omits a field unless its flag is true. Filtering never happens on the client.
- **Own data.** If the only participant is the caller, their own fields are available to the authorized consumer and server-local ranking regardless of flags. Sending their fields to an AI provider still requires the relevant opt-in.
- **Single other participant.** Returns the same shape, but only the consented fields of that person (never allergens). No names or IDs, so the type cannot carry attribution; the client must not display notes or favorites next to a member name (neutral UI text such as "household restrictions" only). `planningNotes` are deduplicated and sorted by text, never by member.
- **Withdrawal.** Consent changes take effect on authenticated server acknowledgement. Server updates compare a revision to reject stale writes. The first implementation keeps no aggregate cache or queued personalized plan requests. Refresh effective consent before use and revalidate before subsequent provider attempts and returning a potentially stale draft. Saved plans retain their existing access rules.
- **AI provider.** Shared data leaves the app to Gemini, Groq or OpenRouter, so "backend only" is not accurate. Prompts label people `P1..Pn` (no names/emails), include only consented fields, mark notes as untrusted quoted data, and are never logged. The consent text names the AI provider.

### AI response leak check

The AI response is untrusted. After parsing and before display or storage the planner runs a `PlanLeakGuard`:

- The plan schema has no free-text field about people (no "reason", "for whom" or "note"). Unknown or extra fields fail parsing (`FormatException`, one repair attempt per the router).
- Remaining free text (titles, meal names) is checked against every participant's display name, email, `planningNote` (normalized, token overlap above a fixed threshold) and "allergy/alergija + group label" patterns. A hit rejects the response: one repair attempt, then a Serbian error. The leaked text is never shown, stored or logged.
- The guard is best-effort text matching with possible false positives (for example a dish named after a member); it is a second layer, not the only control. The primary controls are consent filtering, pseudonymous prompts and the closed schema.
- The guard also fails closed if any allergen group code or the test canary appears in a response (defense in depth; allergens are never sent, so a hit means a bug or a model echo).

## Allergen protection

**Decision (Matija, 2026-11-21).** Allergens are a safety restriction used only inside the server plan endpoint to exclude recipes. The planning endpoint never sends member selections to AI providers, includes them in client responses or logs them. The separate owner-only settings path lets a member manage their own choices. The planning endpoint needs no allergen-sharing flag. An unset or empty selection contributes zero codes and does not block planning. This records an absence of entered data and makes no claim about the member's actual allergens. A profile hint is deferred. Household members may know each other's allergens; that is accepted and not specially protected beyond the rules below.

- **Server-only reads.** Personal allergen rows stay owner-only under RLS. Only the server plan function (a membership-checked function, not a client query) reads the union for the validated participant set. Until the gateway/server planner exists, no client path reads another member's allergens, and consumers of this contract do not implement allergen planning on the client.
- **Pre-filter.** Before anything reaches the AI, the server removes every candidate recipe whose mapped allergen groups intersect the union. Automatic recommendations exclude recipes with a missing or invalid foodId or an unreviewed allergen mapping. For manual cooking, show “Mogući alergeni: nepoznata namirnica” for an unresolved ingredient. For a linked food with an unreviewed mapping, show that allergen information is incomplete. The AI sees only the remaining recipes, with no hint why others are missing.
- **Closed output.** The planning schema lets the AI choose only candidate recipe IDs from the filtered pool. Free-text dishes are not accepted as plan entries.
- **Pool exhaustion (Dev 2, 019).** Initial household-aware planning returns an incomplete draft with unfilled slots when the eligible pool is exhausted. Generation of new candidates is later planner work. If enabled, an AI-proposed new recipe starts as a draft: its ingredients are resolved to catalog foods with reviewed group mappings and checked against the union. Any unresolved ingredient or any intersection rejects it (one repair attempt, then the Serbian error). Ingredient names the AI writes are never trusted as safe.
- **Post-check.** After parsing, the server re-checks every plan entry (including single-meal replacement) against the union and rejects violations. The response and error say only that a plan could not be produced within the household's restrictions: no allergen, no person.
- **Accepted residual risk.** A member who repeatedly requests plans for another member could infer allergens from what is excluded. The household is a trusted group (decision above); the endpoint is authenticated, membership-checked and rate limited, and no extra anti-inference measure is required.

**Implementation (2026-11-24, TRELLO-43, pending review).** The
`planning-inputs` function checks recipe safety for the planner; see the
[019 allergen-safe plans contract](../../019-meal-selection-rules/contracts/plan-allergen-safety-contract.md).
Proposed amendment, which needs the contract owner's approval: the closed
output and the reviewed-mapping requirement apply when the union is
non-empty. An empty union keeps today's planning, including new AI dishes.
That contract also records the known limits of the client-orchestrated slice.

### Guards that keep allergens away from the AI

1. **Type boundary.** The AI prompt builder accepts only `AiPlanningContext`, an allowlisted type with no allergen field. Participant allergen access and the union stay server-only. The app has a separate owner-settings repository and the shared code vocabulary. The `ai/` layer and prompt builder cannot import either settings type.
2. **Import-boundary test.** A test (like the existing `tavli_ui` public-entry check in `scripts/check.sh`) fails if `lib/ai/**` or the prompt builder imports an allergen type or module. It runs in `scripts/check.sh` and CI.
3. **Outbound guard at the transport.** `AIRouter`/the gateway scans the serialized request body before sending and fails closed if it contains any canonical allergen group code (for example `nuts`) for a request that carries household context. The Serbian error is generic and the body is not logged.
4. **Canary regression test (always on).** A fixture gives synthetic members distinctive canary allergens. The full plan flow runs with a recording fake transport. The test asserts that no canary appears in any captured request body, header, prompt, log line, client response, drift row, outbox entry or error text. It covers generation, single-meal replacement, retry/repair, fallback to every provider in the chain, and a single-participant request.
5. **Negative controls.** A test proves the guard works: a deliberately leaking prompt builder stub makes the canary test and the outbound guard fail.
6. **Review rule.** Any PR touching prompts, `AiPlanningContext`, the planner or allergen code states this in its security section and runs these tests.

## Data and lifecycle

Targets: owner-only `user_planning_sharing(user_id, preferences, revision)` (row absent means off; the note flag comes in the later note slice), owner-only `user_allergen_selections(user_id, group_codes)` and `user_favorites(user_id, recipe_id)`, a validated extension of existing `taste_profiles(user_id, profile)`, and catalog `food_allergen_groups(food_id, group_code)` coordinated with Dev 1. Favorites use unique owner and recipe pairs; server membership/recipe checks protect cross-household references. Additive server migrations and drift schema changes are separate implementation slices with explicit grants, RLS, schema-version bump, generated code and outbox writes. Personal entries sync under `user_id`; the planning result is freshly derived for the authorized active household in the first implementation. An optional later cache requires explicit account/household scope and invalidation after member, consent, taste, favorite or recipe changes. A removal immediately revokes server access and blocks queued old-household writes on replay. The client cache never stores allergen data of other members. Delete favorites on recipe deletion or loss of household access. Ordinary sign-out retains personal data and cache under the account.

## Evidence required in implementation PRs

- Two users in one household and a user in another: own writes allowed; direct reads of a co-member's personal rows and foreign aggregation denied; valid selected-member aggregate allowed.
- One selected member versus all; empty/foreign/removed IDs; no leakage of nonselected preferences or favorites.
- Dev 2 planner fixtures: an empty selection contributes zero codes; selected codes form a union; unknown mappings are excluded before provider work; out-of-pool IDs are rejected; single-meal replacement uses the same post-check. If recipe invention is enabled later, verify rejection for unresolved or allergenic ingredients.
- Dev 3 producer fixtures: dislike resolves a ranking conflict; recipe deletion or leaving a household removes invalid favorite contributions; offline edits, outbox replay and account switching preserve ownership.
- Consent matrix (pgTAP and repository fakes): for each of the two flags true/false, with one participant (self, other) and two participants, the result contains exactly the consented fields; withdrawing a flag removes the field on the next authorized read, rejects a stale write and leaves no reusable aggregate; a co-member cannot read or write another member's `PlanningSharing`; a nonmember, foreign or removed ID gets a typed denial and no partial data.
- Single other participant: result type has no ID/name field (compile-time), notes are not ordered by member, and the type has no allergen field.
- Allergen guards 1–5 above (import boundary, outbound guard, canary regression across all flows and providers, negative control).
- Prompt builder test with a fake AI transport: the captured prompt contains no names/emails, no unshared field, no allergen and no nonselected member's data; notes appear only as quoted data.
- Leak guard tests with a fake provider that echoes a participant's name, email, note text and "Ana je alergična na kikiriki" in titles or extra fields: each is rejected, repaired once, then fails with a Serbian message; the leaked string is absent from UI, drift, outbox and logs. Clean responses pass.
- Widget test: no note or favorite text is rendered next to a member name, and no UI path displays another member's allergens.
- Dev 2 fixture verifies plan generation and single-meal replacement consume the same boundary and the server rejects allergenic candidates after AI output.

## Pending review

Dev 2: exact consumer API and favorite weighting; planner integration is owned by 015/019. The tastes consumer transport is the `planning-inputs` Edge Function in the [019 planning tastes contract](../../019-meal-selection-rules/contracts/planning-tastes-contract.md) (TRELLO-41, pending review): server-derived household and participants, `for_provider = true`, a server-computed food allowlist and a projection to the six taste arrays plus `favoriteRecipeCounts`. Favorite weighting (TRELLO-44): favorites of all consenting participants rank first by count, a dislike still wins, and each favorite repeats at most once in 7 days. Note handling and leak-guard thresholds are reviewed with the later note slice. Dev 1: catalog mapping review, provenance, and migration order. The canonical allergen codes follow the catalog checker. The 008 work branch provides `public.planning_advisory_inputs` and a
separate `public.planning_allergen_codes` function. Only the database service role can call either RPC. The gateway must derive
the actor from its verified session before calling them. The advisory function takes a verified actor,
household, participant set, explicit provider-disclosure flag and a catalog food
ID allowlist supplied by the server. It returns dish-kind and cuisine preferences, visible
food preferences and visible favorite counts. Its default food allowlist is
empty. Catalog lookup, consumer transport, consent revalidation during
generation and the later note fields are pending.
