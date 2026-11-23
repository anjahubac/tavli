# Implementation plan: Household, member preferences and personal choices

**Status**: logic-first implementation in progress.
**Spec**: [requirements](spec.md) | **Lead/review**: Dev 3 / Dev 1 and Dev 2
**Household join planning baseline**: origin/dev at 6e560f6; every implementing branch starts from then-current origin/dev.
**Member planning baseline**: dev 0c286b6 (PR #77), with the server-only
allergen decision recorded on this branch.

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

## Direct household join (D3-005 to D3-008)

Decision recorded 2026-11-20 by Matija (Dev 3). Dev 1 is the proposed
independent reviewer and coordinates shared schema and sync changes.
The [flow map](../../docs/flows.md) records the boundary for downstream consumers.

| Source | Planned delivery | Primary paths |
| --- | --- | --- |
| D3-005 / T008–T009 | Server contract, reusable link authorization, preview and atomic membership switch including the recipe choice and owner succession | Additive `supabase/migrations/` and `supabase/tests/`; private recipe photo handling if needed |
| D3-006 / T010–T011 | Owner shares the link or displays its QR from Profile | `lib/features/account/`, `lib/features/settings/`; account API and platform coordination with Dev 4 |
| D3-007 / T012–T013 | Deep link, sign-in continuation, preview, confirmation and verified account/sync handoff | `lib/account/`, `lib/features/account/`, `lib/app/router.dart`, affected `lib/sync/` paths and mirrored tests |
| D3-008 / T014–T015 | Member listing, removal, manual owner transfer and standalone leave | Account UI/API and additive membership SQL/tests; reuse the reviewed transition rules where applicable |

### Proposed server contract

- Retrieve or initialize the stable share token for any current member. The
  server derives identity and household from the authenticated session and
  membership. The client forms the approved link and QR from that token.
- Preview takes the opaque token and returns the destination household name, the caller's source ID and whether leaving that source requires the deletion warning. Return a generic unavailable result for an invalid token. It grants no access to destination household rows.
- Confirm takes the token, expected source household ID, recipe choice
  (`bring_recipes` or `leave_recipes`), explicit acknowledgement of source deletion if the warning was shown, and a client-generated operation UUID.
  Derive the caller from the session and verify current membership, source and
  destination availability before doing any writes. Use the UUID to reconcile
  a lost response without repeating the transition. Recheck the deletion
  condition under lock. If the source became empty-on-leave after preview,
  require the warning and a new confirmation before any write. Return the verified new
  account scope on success or a stable failure category. Cancellation is local.
  An already-current destination is a no-op. A stale source requires a fresh
  preview and confirmation.
- Establish one membership per user in SQL and support member and owner roles.
  The existing account migration uses a composite household/user primary key,
  an owner-only role check and a provisioning trigger. Audit existing rows and
  define forward recovery before enforcing the new constraint. Serialize
  switches, owner changes, removals and account deletion against the same
  affected households. In one DB transaction apply the recipe choice, move
  membership, and promote the longest-serving remaining member (ascending
  user UUID breaks ties) or delete the now-empty source with its shared rows. Failures
  roll back the DB changes. Use least-privilege RPC grants, explicit policies
  and fixed search paths. Keep token lookup and delivery scoped to the caller's own membership.
- PR 94 account deletion uses the same private departure function as join.
  Both lock the account and affected household rows before changing membership.
  The departure function retires an empty household and records any photo
  cleanup in the existing private queue. The delete-account function removes
  those objects through Storage, confirms the queue entry and then deletes the
  login. A retry resumes cleanup after an interrupted response.
  The service-role photo RPC returns only paths for the caller's queued retired
  household. Client authorization and invite scope are unchanged. There are no
  new provider credentials, client endpoints or abuse limits. Deploy the
  migration with the updated delete-account function through the backend workflow.
- Keep the link reusable and rate-limit preview and confirmation server-side.
  Treat it as a secret in logs and analytics. Route validation, token lifecycle
  on household retirement and operation receipt retention belong in the final
  written contract.

The initial SQL fixture uses these proposed RPC signatures and response keys:

| RPC | Result |
| --- | --- |
| `household_invite_token()` | Stable token as text for any member; SQLSTATE `42501` without a membership (owner-only until migration `20261123130000`) |
| `regenerate_household_invite()` | New token as text for the owner; the old token stops resolving; SQLSTATE `42501` for members and unauthenticated callers |
| `preview_household_join(token text)` | JSON object with `status`, and on success `household_name`, `source_household_id` and `requires_source_deletion_ack` |
| `confirm_household_join(token text, expected_source_household_id uuid, recipe_choice text, source_deletion_ack boolean, operation_id uuid)` | JSON object with `status` and verified scope on success |
| `remove_household_member(member_id uuid)` | JSON object with `status`: `removed`, `not_allowed` or `invalid_request` |

The fixture checks `joined`, `already_member`, `unavailable`,
`stale_source`, `source_deletion_confirmation_required` and
`operation_conflict`. A warning acknowledgement is specific to this
switch. A rejected confirmation leaves no successful receipt, so the caller
can acknowledge the warning and submit the same operation UUID. Reusing a UUID
from a successful switch with a different request yields a conflict.

### Recipes, private photos and offline sync

- Use immutable server-controlled recipe creator provenance. Existing
  recipes without a trusted creator remain unknown and are eligible for
  copying. The current `updated_by` field tracks edits and cannot attribute
  creation. Allocate independent destination IDs for copies and retain the
  source originals while other members remain. Record the schema changes in
  [data model](data-model.md). Cover account deletion and earlier clients.
- Inventory recipe versions, labels, photo paths, plan/shopping references and
  tombstones. Preserve valid source references for remaining members and
  keep scoped IDs and snapshots consistent in the destination. Storage and
  Postgres commit separately. If files need transfer, plan idempotent staging
  in private storage, verified paths, publication after verification and
  cleanup of staged objects on failure so a failed file copy leaves membership
  unchanged and source photos available. After acknowledged deletion commits,
  use a durable, retryable cleanup for empty-source photo objects. A cleanup
  retry uses verified old-household paths only.
- Joining requires connectivity. The confirmation waits for pending or sending
  household rows and keeps normal background retries active. Terminal failures
  retain the local error code and allow the join to proceed. After 30 seconds
  the user can continue waiting or explicitly proceed without the remaining
  old-household edits. A failed join leaves pending writes eligible for retry.
  A confirmed membership change quarantines old-household writes in the same
  local transaction that clears download cursors. Personal writes stay queued.
  Cold start and sign-in with an existing cache reconcile membership before
  starting the sync engine. Cached offline data stays available while membership
  verification is retried.
- Preserve source `recipe_versions.created_at` so Undo still restores the
  latest snapshot first after a copy.
- Photo preparation reserves the copied object names for 24 hours. Retrying
  the same operation renews the reservation while it is available. Publication
  and releasing the reservation happen in one transaction. The scheduled
  photo cleanup worker deletes expired unpublished objects and files from
  retired source households with bounded batches through the Storage API.
  A deletion or completion error leaves the batch eligible for another run.
  The worker uses server-only RPCs and validates object paths. No user session,
  new join request or log of object names is required.

### Photo cleanup deployment

The Supabase migration registers the `household-photo-cleanup` job every five
minutes. In each deployed environment, configure that project's own HTTPS
base URL in Vault as `household_photo_cleanup_url`. Configure the same
dedicated random value of at least 32 characters in Vault as
`household_photo_cleanup_token` and in Edge Function secrets as
`HOUSEHOLD_PHOTO_CLEANUP_TOKEN`. This credential grants only access to the
cleanup endpoint. A missing or invalid credential leaves queued work intact.
Use only isolated synthetic fixtures to verify scheduler and Storage behavior.
Before enabling the deployment in an environment, confirm its schedule invokes
that environment's endpoint and a queued operation completes.

Photo staging is private, cleanup is bounded and authenticated, and no client
credential or network destination is added. The related changes require an
additive migration and Edge deployment. AI and provider access are N/A.

### Implementation status

Membership invariant: every account with a profile has exactly one
membership. A unique index enforces at most one. Deferred constraint triggers
on `household_members` and `profiles` enforce at least one at commit, so a
switch or account deletion may pass through an intermediate state. The owner
removes a member through `remove_household_member`. In one transaction, the
server deletes the membership and creates a new personal household owned by the
removed account. The removed client discovers the new scope on its next
membership refresh, quarantines old-household writes and downloads the new
household. Errors stay generic so callers cannot probe other memberships. The
member-management UI (T014/T015) still needs to list members and call this RPC.

New households generate a 12-character invite code. Previously issued
16- and 64-character credentials remain valid. The HTTPS share URL uses the configured project's
`/functions/v1/household-invite` endpoint and carries the credential in a URL
fragment. A fixed redirect points to `tavli://household/join`. The server
handles the code only in authenticated request bodies.

Matija (Dev 3) accepted the unverified `tavli://` custom scheme for the
initial release. Another installed app registered for the scheme may receive
the invite code, which remains usable by a signed-in bearer. Native delivery
and browser behavior need platform verification. Profile accepts invite codes
directly, and the in-app QR scanner reads the same code (see the UI slice
below). Windows support is planned and will require its own
protocol registration when the desktop app becomes available.

The confirmation Edge Function verifies the caller and consults the existing
rate-limited RPC. When photos are required it receives an authorized manifest,
copies the objects through the Storage API, and submits that manifest to the
service-only finalization RPC. The database rechecks membership and manifest
before publishing copies and applying the switch. A durable cleanup record
tracks old household objects. Confirmation attempts retry pending cleanup for
the same user. Prepared copies are unreadable to app users before commit.

Preview permits 60 requests per account per minute and confirmation permits
15. The account and sync consumer reconciles verified membership and retains
old household writes in the rejected queue. Profile, platform links, QR
generation and scanning, and the manual input screen are consumer work.

### Household UI and first sign-in slice (T010–T015)

Matija (Dev 3) chose the designs on 2026-11-22 from the
[household proposal canvas](https://claude.ai/artifact/Q7srd9bgd3sd9ZBKiun1L3#page-dcb81aee8d83):
variant A for Profile, variant C for the first sign-in step. Proposed reviewer
for the UI and deep-link boundary: Dev 4. Proposed reviewer for SQL ordering and
the drift change: Dev 1.

- **First sign-in.** After the name step, the new account sees “Tvoje
  domaćinstvo”. It names its household or joins an existing one. The trigger
  still provisions a personal household, so the one-membership invariant and
  the sync scope stay unchanged. `profiles.household_setup_done` records the
  step on the server. Existing profiles are backfilled to `true`; new profiles
  start at `false`. `rename_household(name)` completes the step for the
  owner. A membership insert with the `member` role completes it on join in
  the same transaction. The app caches the flag in drift v11
  (`accounts.household_ready`, default `true`) and adds the `NeedsHousehold`
  auth state with the `/sign-in/household` route. Joining from this step
  copies no recipes. It acknowledges deletion of the new empty household as
  part of the explicit “Pridruži se” choice, so it shows neither the
  recipe question nor the last-member warning.
- **Profile (variant A).** The “Domaćinstvo” section shows a card that expands
  to the member list. The owner sees “Izmeni domaćinstvo”. Every member sees
  “Podeli domaćinstvo” and “Pridruži se novom domaćinstvu”. On a wide
  window, the left column holds Account and Account deletion. The right column
  holds Household and Settings, as on the macOS canvas.
- **Members and rename.** `household_members_overview()` returns user ID,
  display name, role and join time for the caller's own household only. It
  never returns email. Profiles stay owner-readable under RLS.
  `rename_household` is owner-only, trims, accepts 1–40 characters and locks the
  household row like join and removal. Neither has an offline cache. The UI
  shows a retry notice. The member list reloads after membership
  verification.
- **Sharing and joining.** “Podeli domaćinstvo” shows the QR code (the plain
  code), the grouped code, “Pošalji pozivnicu” through the system share sheet
  on phones and “Kopiraj link” on wide windows, plus “Kopiraj kod”. “Pridruži
  se domaćinstvu” is a bottom sheet on phones and a dialog on wide windows. The
  phone and tablet variants offer “Skeniraj QR kod”. Desktop uses manual
  entry or the link only. The scanner accepts the plain code, the app link
  and the HTTPS share link. The app ignores other content.
- **Links through sign-in.** `tavli://household/join#CODE` is stored in memory
  until an account is present. The setup step or the signed-in app then opens
  the join flow with the code prefilled. After an app restart the user opens
  the link again. Android registers the `household` host; iOS and macOS
  already register the scheme.

New dependencies, all maintained Flutter community packages:

- `qr_flutter`: draws the invite QR code offline from the code itself.
- `mobile_scanner`: in-app camera QR scanning on Android and iOS, with
  manual entry as fallback.
- `share_plus`: the native share sheet for “Pošalji pozivnicu”.

Canvas deviations, for Dev 4 review: members do not see “Podeli
domaćinstvo”. Variant A shows the row to members, but the invite RPC and
FR-101 are owner-only. The canvas does not draw a confirmation for joining
from the setup step. It reuses the “Potvrda prelaska” header with “Pridruži
se” and “Odustani”. The removal message reads “člana {name}” because the app
cannot decline names. Dialog titles use the library `TavliDialog` style
(20/700) instead of the canvas 22/800. `TavliDialog` gains an optional
`header`, and `TavliAvatar` gains `.icon` with the 44 and 48 sizes, each
with a gallery example. New icons follow the canvas paths.

Privacy and security impact: members of one household see each other's
display names, which the name step already announces. No email, no other
household and no new storage path are exposed. Any member can read the invite;
the server still requires a membership. Only the owner can replace it, which
ends a leaked or removed person's ability to reuse the old code. The scanner reads codes on the device, and the app neither
stores camera frames nor sends them anywhere. A shared link still carries
the bearer code, as accepted above.

### Verification before rollout

- Dev 3 and Dev 1 review the typed contract, exact shared paths, migration
  ordering, estimates and fixtures before the slice becomes Ready. Dev 4
  reviews the deep-link and platform changes when those consumers are planned.
- Run local migration reset and pgTAP with synthetic accounts. Cover owner and
  member share access, unauthenticated requests, invalid tokens, reusable
  links, unauthorized data access, throttling, both recipe choices, concurrent
  switches, replay, stale source, successor and empty-source branches, and
  rollback. Verify the account deletion and storage boundaries affected by the
  selected model.
- Add fake-backed tests for offline, cancellation, sign-in continuation,
  ambiguous response, source-outbox isolation, and old-client scope changes
  in the consumer slice. Use the [quality gates](../../docs/development/quality-gates.md)
  and link observed evidence to the tasks and the PR.

## Recipe ratings data slice

D3-018 / FR-011 reuses the existing owner-only ratings table and sync outbox.
The server uses a unique user and recipe pair and keeps the existing server
ID when an offline write arrives from another device. The Drift v7 to v8
upgrade keeps the latest rating per pair and adds a local cache for the
household average and count. Dev 3 owns the ratings repository and SQL.
Coordinate changes to `lib/data/database.dart`, its generated output and
`lib/sync/` with Dev 1 before integration. The UI follows the agreed
[ratings contract](contracts/recipe-ratings.md) in a later slice.

The summary endpoint checks current membership and returns only recipe
identifiers, counts and averages, paged through the data layer. The average
uses one decimal place. In a small household, the count and average may allow
someone to infer a score. Private notes are available only to their authors.
Credential and file impacts are N/A. Deploy the migration through the
existing workflow before distributing a client that uses the new sync contract.

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

- **Personal allergen selection.** Drift v10 adds one private selection row
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

- **Favorites follow the recipe.** A favorite is one row per user and recipe
  (`user_id:recipe_id`), allowed only for a recipe visible in the user's
  household. Leaving a household deletes favorites on its recipes (trigger on
  `household_members`). The household join copies favorites and ratings to the
  recipes it brings along; recipes left behind lose them. Leaving or removal
  also deletes the member's ratings on the old household's recipes. Sync drops cached
  favorites and queued writes for recipes outside the active household before
  upload and after pulls. Tastes, allergens and consent belong to the profile
  and survive a household change. Drift v10 holds both new tables, after recipe
  ratings in v8 and the food catalog in v9.

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
| D3-011 | `FavoriteRepository` reads, watches and edits private favorites. The server resolver counts visible favorites after consent. Favorites follow the recipe; leaving a household removes them. | The join copies favorites and ratings for brought recipes. Connect the recipe heart and list filter, and run the integrated planner acceptance. |

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
