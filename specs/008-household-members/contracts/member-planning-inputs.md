# Contract: member inputs for household planning

**Status**: proposed for review, not implemented. **Spec**: 008 FR-001 (D3-001); consumer: 019 FR-004–FR-007. **Producer**: Dev 3; **reviewers**: Dev 2 (planner) and Dev 1 (catalog/schema). **Product decisions**: Matija, 2026-11-20.

## Scope and existing state

The first PR agrees types, signatures and fixtures. It adds no data logic. Today `taste_profiles` is owner-only JSON, ratings are personal, and recipes have the nine `DishKind` values. Allergen and favorite tables and the food catalog are planned. Do not expose personal profile or diary rows to household members.

## Inputs

- `participantUserIds`: a nonempty set of distinct account IDs. The planner defaults this to all current household members, but always passes it explicitly. The producer verifies every ID against the active household; a foreign or removed ID fails the whole request.
- Personal allergy selections use canonical allergen **group codes**, separate from food IDs. Proposed codes for the [14 EU Annex II groups](https://food.ec.europa.eu/food-safety/campaign-2026/allergies_en): `gluten_cereals`, `crustaceans`, `eggs`, `fish`, `peanuts`, `soybeans`, `milk`, `tree_nuts`, `celery`, `mustard`, `sesame`, `sulphites`, `lupin`, `molluscs`. Dev 1 reviews mapping and provenance before implementation; regulatory exceptions and sulphite thresholds require care. Lactose avoidance is outside this allergy list. Foods may carry reviewed group mappings; an unmapped ingredient has unknown allergy status, never safe status.
- Personal favorite identity is `(user_id, recipe_id)`. Only recipes currently visible in the active household can contribute. Remove the favorite when the recipe is deleted or the user leaves/loses household access.
- Personal tastes have `likedFoodIds`, `dislikedFoodIds`, `likedDishKinds`, `dislikedDishKinds`, `likedCuisineCodes`, `dislikedCuisineCodes`, and an optional short `planningNote`. Initial proposed cuisine codes are `serbian`, `italian`, `japanese`, `french`, `mexican`; Dev 2 reviews the list. Free text is accepted only in `planningNote`, whose UI explains that it contributes to shared plans. `DishKind` reuses the existing nine wire values (`soup`, `cooked`, `baked_fried`, `pasta`, `salad`, `pie_pizza_sandwich`, `eggs_breakfast`, `cold`, `sweet`); grill is covered by `baked_fried`. No dietary-mode field or user-defined style code in this slice. A like/dislike is advisory, never a safety prohibition. A conflicting like and dislike resolves in favor of the dislike for ranking, not a hard exclusion.

## Typed boundary (target signature)

```dart
abstract interface class MemberPlanningInputsRepository {
  Future<PlanningMemberInputs> forParticipants({
    required AccountScope scope,
    required Set<String> participantUserIds,
  });
}

class PlanningMemberInputs {
  final Set<String> allergenGroupCodes; // union; hard restriction
  final Set<String> likedFoodIds;
  final Set<String> dislikedFoodIds;
  final Set<DishKind> likedDishKinds;
  final Set<DishKind> dislikedDishKinds;
  final Set<String> likedCuisineCodes;
  final Set<String> dislikedCuisineCodes;
  final List<String> planningNotes; // bounded, explicitly shared for planning
  final Map<String, int> favoriteRecipeCounts; // recipe ID -> number of participants
  final bool allergenDataComplete; // false if any participant has not shared allergens
}

/// Owner-only, default false for every flag; only the owner can change it.
class PlanningSharing {
  final bool allergens; // allergen group codes
  final bool preferences; // likes/dislikes and favorites
  final bool planningNote;
}
```

Names are proposed for Dev 2 review; bounds and the cuisine list are finalized before implementation. The result contains no member IDs, names, email, profile, diary or raw personal rows, and only fields covered by [Disclosure and consent](#disclosure-and-consent). The caller receives only a purpose-limited planning view. An empty `participantUserIds` set is invalid. Missing personal selections mean no stated preference, not proof of no allergy. A failed membership check returns a typed authorization error and no partial result. Cancellation/fetch failure preserves existing local data; the planner must not silently treat unavailable allergy data as safe. Food/recipe validation, not this member aggregate, reports unresolved ingredient mappings.

Example: `forParticipants(scope: activeScope, participantUserIds: {'ana-id', 'marko-id'})` returns the union of their selected allergen groups, merged advisory tastes and favorite counts for visible recipes. If Ana likes `fish-id` and Marko dislikes it, it ranks lower. If either selected `fish` as an allergy group, candidate recipes containing that group are rejected; recipes with unknown mappings require review.

## Disclosure and consent

Aggregation is not anonymization: a household may have one or two members, so a single-participant result is attributable to that person. Consent, not aggregation, is the control.

- **Per-field consent.** Each member owns `PlanningSharing` with three independent flags: `allergens`, `preferences` (likes/dislikes and favorites) and `planningNote`. All default to **false** (opt-in). Only the owner can read or change them (owner-only RLS); the UI asks once and explains that shared fields reach other members' plans and the AI provider. Allergen data is health data (GDPR Art. 9); consent is the legal basis and may be withdrawn at any time.
- **Server-side filtering.** The producer (a server function checking household membership) reads each participant's flag and omits a field unless its flag is true. Filtering never happens on the client.
- **Own data.** If the only participant is the caller, all of the caller's own fields are returned regardless of flags.
- **Single other participant.** Returns the same shape, but only the consented fields of that person. No names or IDs, so the type cannot carry attribution; the client must not display allergens, notes or favorites next to a member name (neutral UI text such as "household restrictions" only). `planningNotes` are deduplicated and sorted by text, never by member.
- **Missing consent for allergens.** The field is omitted and `allergenDataComplete` is `false`. The planner treats this like stale allergen data: warn the user, never assume safe. This discloses only that data was not shared, not its content.
- **Withdrawal.** Withdrawing a flag invalidates the cached aggregate for the household and any queued plan request built from it; an offline device may only use its last verified snapshot and shows that it may be stale.
- **AI provider.** Shared data leaves the app to Gemini, Groq or OpenRouter, so "backend only" is not accurate. Prompts label people `P1..Pn` (no names/emails), include only consented fields, mark notes as untrusted quoted data, and are never logged. The consent text names the AI provider.

### AI response leak check

The AI response is untrusted. After parsing and before display or storage the planner runs a `PlanLeakGuard`:

- The plan schema has no free-text field about people (no "reason", "for whom" or "note"). Unknown or extra fields fail parsing (`FormatException`, one repair attempt per the router).
- Remaining free text (titles, meal names) is checked against every participant's display name, email, `planningNote` (normalized, token overlap above a fixed threshold) and "allergy/alergija + group label" patterns. A hit rejects the response: one repair attempt, then a Serbian error. The leaked text is never shown, stored or logged.
- The guard is best-effort text matching with possible false positives (for example a dish named after a member); it is a second layer, not the only control. The primary controls are consent filtering, pseudonymous prompts and the closed schema.
- Allergen enforcement stays separate: candidates matching an allergen group are rejected after the AI output (see evidence below).

## Data and lifecycle

Targets: owner-only `user_planning_sharing(user_id, allergens, preferences, planning_note)` (booleans, default false; row absent means all false), owner-only `user_allergen_groups(user_id, group_code)` and `user_favorites(user_id, recipe_id)`, a validated extension of existing `taste_profiles(user_id, profile)`, and catalog `food_allergen_groups(food_id, group_code)` coordinated with Dev 1. Composite pairs are unique; server membership/recipe checks protect cross-household references. Additive server migrations and drift schema changes are separate implementation slices with explicit grants, RLS, schema-version bump, generated code and outbox writes. Personal entries sync under `user_id`; the planning result is derived for the authorized active household and may be cached for offline use only within that account/household scope. Refresh or invalidate it after member, allergy, taste, favorite or recipe changes. A removal immediately revokes server access and blocks queued old-household writes on replay; an offline device can only use its last verified snapshot and must show that it may be stale. Delete favorites on recipe deletion or loss of household access. Ordinary sign-out retains personal data and cache under the account.

## Evidence required in implementation PRs

- Two users in one household and a user in another: own writes allowed; direct reads of a co-member's personal rows and foreign aggregation denied; valid selected-member aggregate allowed.
- One selected member versus all; empty/foreign/removed IDs; no leakage of nonselected preferences or favorites.
- Allergy union and unknown mapping; conflict between a like and dislike; deleted recipe/left household; offline edit, outbox replay, account switch and stale cache.
- Consent matrix (pgTAP and repository fakes): for each flag true/false, with one participant (self, other) and two participants, the result contains exactly the consented fields; withdrawing a flag removes the field and invalidates the cache; a co-member cannot read or write another member's `PlanningSharing`; a nonmember, foreign or removed ID gets a typed denial and no partial data.
- Single other participant: result type has no ID/name field (compile-time), notes are not ordered by member, and `allergenDataComplete` is false when allergens are not shared.
- Prompt builder test with a fake AI transport: the captured prompt contains no names/emails, no unshared field and no nonselected member's data; notes appear only as quoted data.
- Leak guard tests with a fake provider that echoes a participant's name, email, note text and "Ana je alergična na kikiriki" in titles or extra fields: each is rejected, repaired once, then fails with a Serbian message; the leaked string is absent from UI, drift, outbox and logs. Clean responses pass.
- Widget test: no allergen, note or favorite text is rendered next to a member name.
- Dev 2 fixture verifies plan generation and single-meal replacement consume the same boundary, and reject allergenic candidates after AI output.

## Pending review

Dev 2: exact API names, note handling, leak-guard thresholds, behavior when `allergenDataComplete` is false, favorite weighting and planner response to stale allergy data. Dev 1: canonical allergen vocabulary/provenance, food-group mapping, cuisine vocabulary ownership and migration order. No schema or runtime implementation is claimed by this draft.
