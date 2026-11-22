# Implementation plan: Household, member preferences and personal choices

**Status**: scoped proposal; runtime implementation not started by this revision.
**Spec**: [requirements](spec.md) | **Lead/review**: Dev 3 / Dev 1 and Dev 2
**Household join planning baseline**: origin/dev at 6e560f6; every implementing branch starts from then-current origin/dev.

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

The D3-001 contract PR is documentation and interface design only. Later slices implement personal tastes in the existing `taste_profiles` path, user/allergen-group and user/favorite relations, catalog food/group mappings with Dev 1, then the aggregate consumed by Dev 2. Document current-to-target columns in `data-model.md` before the schema slice; allocate the next drift version after earlier schema PRs merge. No new dependency is proposed.

Producer dependencies: Existing baseline; no new producer feature required for the first slice.

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

- Retrieve or initialize the stable share token for the current owner. The
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
  and fixed search paths. Keep token lookup and delivery owner-scoped.
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
| `household_invite_token()` | Stable token as text; SQLSTATE `42501` for non-owners |
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
and browser behavior need platform verification. Profile accepts invite codes directly. The in-app QR scanner remains a separate UI slice. macOS requires registering the scheme and
routing it into the app. Windows support is planned and will require its own
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

### Verification before rollout

- Dev 3 and Dev 1 review the typed contract, exact shared paths, migration
  ordering, estimates and fixtures before the slice becomes Ready. Dev 4
  reviews the deep-link and platform changes when those consumers are planned.
- Run local migration reset and pgTAP with synthetic accounts. Cover owner and
  non-owner share access, unauthenticated requests, invalid tokens, reusable
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

## Constitution check (3.0.1)

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
