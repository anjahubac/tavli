# Implementation plan: Household, member preferences and personal choices

**Status**: logic-first implementation in progress.
**Spec**: [requirements](spec.md) | **Lead/review**: Dev 3 / Dev 1 and Dev 2
**Baseline**: dev 0c286b6 (PR #77), with the server-only allergen decision
recorded on this branch. New implementation branches start from current origin/dev.

## Existing boundaries and proposed files

- `lib/account/`
- `lib/domain/account.dart`
- `lib/features/account/`
- `lib/features/settings/`
- `lib/data/`
- `lib/sync/entities.dart`
- `supabase/migrations/`
- `supabase/tests/`

Items marked new/proposed/external do not exist at baseline. Verify exact existing
files and consumers before editing; new files remain in current feature/domain/
data/AI/account/sync layers. Shared providers and schema versions are coordinated.

## Contract and data plan

Household membership/invites are server-authorized; preferences, allergens, favorites and ratings are personal. The [member planning inputs contract](contracts/member-planning-inputs.md) specifies the proposed typed boundary, selected participants and fixtures. Planning receives only the agreed minimum aggregate. New grants/RLS and account-scope/outbox transitions require migration and denial tests.

The D3-001 contract PR is documentation and interface design only. Later slices implement personal tastes in the existing `taste_profiles` path, owner allergen selections and a user/favorite relation, catalog food/group mappings with Dev 1, then the aggregate consumed by Dev 2. Document current-to-target columns in `data-model.md` before the schema slice; allocate the next drift version after earlier schema PRs merge. No new dependency is proposed.

Producer dependencies: the merged 008 contract and the existing taste-profile
sync path for the first slice. Later slices depend on catalog identity/mappings,
household access transitions and the 015 gateway as listed below.

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

## Logic-first implementation

This sequence applies to D3-004 and D3-009–D3-011 on top of the member-input
contract. Screen work follows the corresponding repository and server tests.
Invitation and membership changes retain their own 008 tasks. Record exact
migration names, reviewers and effort per PR before marking a slice Ready.

### Verified baseline at 0c286b6

- Drift already persists `user_profiles.profile_json` by user ID. The existing
  `TasteProfileEntity`, `SyncedWriter` and server `taste_profiles` provide
  account-scoped sync and owner-only RLS. Legacy JSON can contain unrelated keys.
- The nine canonical `DishKind` wire values already exist in
  `lib/domain/recipe_labels.dart`. Ratings already have separate storage and
  sync; keep rating and favorite semantics independent.
- `household_members` exists and is used by `lib/account/account_api.dart`.
  This checkout has no member-planning endpoint, favorites or allergen relations,
  or reviewed food-to-allergen mapping. `lib/ai/meal_plan_ai.dart` still uses
  client `AIRouter`; the [015 gateway](../015-ai-server-gateway/spec.md) is
  planned. Keep scope with the existing plan draft and approval repositories.
- [Data model](data-model.md) records existing and proposed data and rollout
  constraints. Review the [member-input contract](contracts/member-planning-inputs.md)
  before finalizing any wire format.

### Implementation sequence

| Slice and source | Implementation and acceptance | Owner / independent review |
|---|---|---|
| 1. Private dish-kind preferences, D3-004 / T006–T007 | Add a pure Dart value and account-scoped repository in `lib/domain/` and `lib/data/`. Use the existing JSON fields and `DishKind` wires. Read absent fields as empty and preserve unrelated legacy fields when writing. Write the profile and outbox together. Test canonical stored and synced values, read-back, repeat edits and account isolation. This part needs no food catalog, cuisine list, UI, SQL or Drift schema change. | Dev 3 / Dev 2 |
| 2. Structured profile and sharing, D3-004 / T006–T007, FR-108/111 | Extend the same repository with catalog food IDs and reviewed cuisine codes. Add owner-only opt-in for preferences/favorites through authenticated online writes with revision checks. Test default-off, server-acknowledged withdrawal, stale devices and old-client sync. Schedule the optional note and its separate consent after structured preferences and favorites. | Dev 3 / Dev 2 for consent, Dev 1 for catalog and migrations |
| 3. Private favorites, D3-011 / T020–T021 | Add owner-scoped favorite storage, repository and sync. Use unique user/recipe pairs and server-verified recipe access. Test repeat add/remove, recipe deletion, account deletion, membership loss and stale outbox replay. Storage can precede the planner. Coordinate membership-loss cleanup with the household transition owner. | Dev 3 / Dev 1 for schema, Dev 2 for recipe access and consumer |
| 4. Authorized member inputs, FR-106/110–112 and 019 D2-009/D2-012 | Add a server resolver and typed consumer boundary. Derive requester identity from auth; verify the entire nonempty participant set; apply consent per participant; resolve like/dislike conflicts toward dislike for ranking; count only visible favorites. Shared note normalization and deduplication belong to the later note slice. Test self, another member, multiple members, foreign/removed IDs and revocation. Start with a fresh authorized read per request; defer aggregate caching and queued personalized requests until invalidation is specified and tested. Dev 2 can prepare fake-backed consumer tests before producer merge. | Dev 3 producer, Dev 2 consumer / reciprocal review |
| 5. Personal allergen selection and catalog metadata, D3-009/D3-010 / T016–T019 | Use Dev 1's existing allergen codes for owner-only selection storage. Integrate catalog mappings with explicit unknown coverage as Dev 1 reviews them. The member can manage their own selections through the owner-only settings path. An empty selection contributes no codes and requires no confirmation or onboarding step. Public recipe metadata may describe ingredients; it carries no member selections. Test two-account RLS, catalog identity, and unknown versus verified absence. | Dev 3 personal selection, Dev 1 catalog / reciprocal review |
| 6. Planner integration handoff, 019 D2-009/D2-011/D2-012/D2-013 | Dev 3 delivers the reviewed member-input contract, access/consent fixtures and a server-only interface for selected allergen codes. Dev 2 owns gateway, generation, replacement and candidate exhaustion in 015/019. Review the privacy boundary and verify shared fixtures before enabling household-aware planning. | Dev 2 consumer / Dev 3 for privacy and Dev 1 for mapping |
| 7. UI and end-to-end acceptance, D3-004/D3-009–D3-011 and 019 | Connect the verified repositories to the profile and recipe UI. Participant selection and server-planner UI are separate Dev 2 work. Verify Serbian Latin copy, consent and pending withdrawal feedback, generic restriction errors, empty/offline states, phone/wide, 2× text and reduced motion. | Existing feature owners / independent reviewer per PR |

Slices 2 and 3 can advance separately once their own decisions are recorded.
Slice 4 can ship the preference aggregate before favorite contributions, as long
as the contract and consumer describe the available fields. Slice 5 can build
private selections and catalog metadata before 015. The server planner requires
the reviewed mappings, a server-side planning contract, and shared fixtures with
Dev 2; never route a failed personalized request through the legacy direct AI
path. Existing locked plan entries remain intact and any restriction conflict
exposed to clients is generic.

Shared schema and generated cache files, sync registry and deployment migration
ordering are coordinated by Dev 1, with Dev 3 reviewing authorization and
membership transitions. Dev 2 coordinates the AI/router and planning entry
points. Keep existing feature providers; name the exact shared paths in each PR.
No dependency is proposed. File handling is out of scope. Credentials and
server deployment follow 012/015.

### Implementation decisions

- **Personal allergen selection.** Drift v8 adds one private selection row
  per account. The account-scoped repository replaces the entire canonical set
  and enqueues one upsert in the same transaction. Clearing writes an empty set.
  The SQL migration checks the vocabulary and uses owner-only RLS. Auth account
  deletion cascades and local account deletion clears the owner cache.
  `RecipeAllergens` models public recipe metadata for manual cooking, including
  unresolved ingredients and linked foods awaiting review. Its personal comparison
  takes the owner's own selection. Catalog lookup and server planner activation
  are awaiting the corresponding producer schemas and review.

- **First repository slice.** Add `DishKindPreferences` in
  `lib/domain/dish_kind_preferences.dart` and `TasteProfileRepository` in
  `lib/data/taste_profile_repository.dart`, with tests in the matching
  `test/domain/` and `test/data/` directories. Expose a one-shot read, a
  Drift watch and an atomic save scoped to the signed-in user. Use
  `likedDishKinds` and `dislikedDishKinds` JSON arrays with the existing
  `DishKind.wire` values, deduplicated in enum order. Normalize overlap in
  favor of dislike. Missing fields read as empty; ignore unknown array entries
  on read. Saving only these fields preserves all unrelated JSON keys and
  fails without writing if the existing payload is not an object. Write the
  row and existing `taste_profile` outbox operation in the same transaction.
  No shared schema, provider wiring or UI changes are required for this slice.
- **Consent and freshness.** Both flags are owner-only and default off.
  Changes require an authenticated online write with an expected revision;
  stale changes refresh rather than overwriting newer consent. Do not queue
  consent changes. Read participants and effective consent before use and
  revalidate on a later provider attempt or before returning a result that
  might have become stale. Requests already delivered to a provider cannot be
  recalled. Existing saved plans remain available under current permissions.
- **Resolver and favorites.** The server derives caller identity from the
  session, verifies caller and every selected member against the requested
  household, and denies the whole request with a generic authorization
  category when any check fails. Resolve private inputs server-side for each
  request. Preserve the sole-self exception for the caller's own authorized
  view and server-local ranking; provider disclosure still follows the
  relevant opt-in. Count a visible recipe at most once per selected, eligible
  member. Use favorite counts as a soft ranking signal after eligibility and
  suitability; exact ranking integration is owned by Dev 2. Membership-loss
  cleanup and stale-write rejection must be verified before favorite sync.

### Product decisions for rollout

Matija confirmed on 2026-11-21 that structured preferences and favorites ship
before optional planning notes. The later note has its own opt-in. Members can
leave their allergen selections empty; the planner uses the selections present
at request time. A profile hint can be considered separately after the initial
implementation. Dev 2 owns incomplete drafts when the reviewed recipe pool is
exhausted; the 008 delivery does not depend on building that planner behavior.

- **Favorite membership lifetime.** SQL uses a separate identity for every
  household membership. The favorite row references the precise membership
  and recipe so access loss and recipe deletion cascade. A reconnect may
  refresh the membership identity but cannot migrate stale writes to it.
  Existing cached accounts can fetch the identity on their first edit.
  Sync reconciles the cached identity before sending favorites and after pulls.
  A verified access change removes stale favorite rows and queued operations.
  The invitations PR should keep the identity when saving the new membership. Coordinate the additive
  migration and Drift v9 with Dev 1.

### Cross-owner handoffs and remaining decisions

- Dev 1 supplies catalog food IDs, visibility rules and reviewed allergen
  mappings with a completeness signal. Matija confirmed the initial five cuisine
  codes. Dev 2 should use the same codes and set provider payload bounds. Dev 1
  coordinates any shared migrations. For catalog decision D10, Matija confirmed keeping ingredient links embedded in
  recipe JSON. The server planner
  reads each authorized recipe's `foodId` links and resolves them against
  reviewed catalog mappings. Dev 1 owns the checker and mapping review. Automatic
  recommendations require complete ingredient mapping and review coverage. Manual
  cooking shows a warning for incomplete allergen information.
- Dev 3 supplies Dev 2 with a typed selected-participant fixture and expected
  authorization, consent and favorite counts. Dev 2 reviews the request/response
  shape and typed error mapping and owns planner consumption. The note's length
  and leak-check fixtures are decisions for the later note slice.
- Dev 3 owns personal allergen selection using the existing catalog checker codes. Reuse the household transition work to verify favorite cleanup and stale
  writes when recipe access changes. The sync hooks remove operations tied to
  a superseded membership.
- Dev 2 owns 015/019 endpoint limits, replacement, batch behavior, favorite
  weighting and incomplete drafts. Dev 3 reviews the privacy boundary. Dev 2
  and Dev 3 agree the server-only comparison inputs before the later free-text
  note slice.

## Logic handoff on the 008 work branch

| Source | Implementation available | Remaining acceptance |
|---|---|---|
| D3-004 | `TasteProfileRepository` reads, watches and writes dish-kind, catalog food and cuisine choices. `PlanningSharingRepository` reads and changes owner consent online. The private resolver applies consent and resolves ranking conflicts. | Dev 2 to apply the five cuisine codes and define consumer limits. Connect the profile UI and the visible food catalog. |
| D3-009 | `AllergenRepository` reads, watches and replaces owner selections. `public.planning_allergen_codes` checks household scope and resolves the selected union. | Connect profile UI and Dev 2 server planning. |
| D3-010 | `RecipeAllergens` derives visible recipe groups, warns on unresolved links or unreviewed mappings and compares with the viewer's own selection. The domain fixture covers seven reviewed ingredients out of eight. | Dev 1 supplies linked food IDs and reviewed mappings. Connect the recipe warning UI. Dev 2 applies the same completeness requirement in recommendation eligibility and result checks. |
| D3-011 | `FavoriteRepository` reads, watches and edits private favorites. The server resolver counts visible favorites after consent. Membership-scoped identity prevents replay on a new membership. | Preserve the identity in the invitations PR, connect the recipe heart and list filter, and run the integrated planner acceptance. |

At `origin/dev` 5fc4485, PR #90 has merged the alias matcher. That baseline
has no food catalog migrations, embedded recipe food links or reviewed
allergen metadata. The 008 branch does not need those producer changes for
private storage. Review shared changes with Dev 1 for `lib/data/database.dart`,
generated Drift, `lib/sync/entities.dart` and migration order, and with Dev 2
for the gateway consumer. No new credential, file or AI transport is added.

## Constitution check (3.1.0)

| Gate | Required response before implementation |
| --- | --- |
| I | English docs; exact Serbian Latin UI/copy for changed screens |
| II | Preserve outbox/account scope; explicit personal/device/reference classification |
| III | D3-001 adds no AI call; later planner use remains through AIRouter |
| IV | No real secrets/logged private content; apply 012 trust-boundary controls |
| V | Test-first logic/parsing; local SQL/Edge tests when backend changes |
| VI | D3-001 is documentation-only; UI slices require phone/wide/text/motion/keyboard proof |
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
