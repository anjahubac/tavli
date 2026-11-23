# Data model: households and member planning

## Direct household join

Status: proposed for D3-005, pending Dev 1 review. The existing server account
and recipe schemas are the migration baseline.

| Area | Current | Target |
| --- | --- | --- |
| Household membership | Unique household/user pair; provisioned users start as owner | Database uniqueness on user; owner and member roles; serialize changes to both affected households |
| Invite | No invite storage | One stable, high-entropy token per household, accessed through owner-share and authenticated preview/confirm operations. Source deletion invalidates the token |
| Recipe provenance | `updated_by` is edit attribution | Immutable server-controlled creator. Existing unknowns stay unknown. Copy caller-created and unknown records only |
| Recipe copy | Recipe and versions have household-scoped relations | Independent destination IDs, valid destination references, private photo copy where present, source originals retained until any confirmed source deletion |
| Switch retry | No recorded switch operation | Identifiable receipt per authenticated caller and operation UUID, with the original request and result bound to it. Replays neither repeat changes nor grant access outside current authorization |
| Source cleanup | Account deletion has a separate server path | Last-member switch requires explicit acknowledgement. Remove source shared rows transactionally after copying and queue cleanup of private source photo objects after commit |

The migration must preserve existing memberships and detect duplicate legacy
memberships before applying uniqueness. The receipt, token and cleanup data
have restricted access. The online switch saves only server-side state; the
app rebinds its offline cache to the verified membership. Any needed drift
migration is planned with the sync consumer. Personal account rows retain
their existing access and lifecycle.

### First sign-in step, rename and member list

| Data | Change |
| --- | --- |
| `profiles.household_setup_done` | New boolean. Existing rows are `true`; new rows default to `false`. Not client-writable (column grants unchanged). Set by `rename_household` and by a `household_members` insert with role `member`. |
| `rename_household(name)` | Owner-only RPC that trims and accepts 1–40 characters. Returns `renamed`, `invalid_name` or `not_allowed`. Locks the household row. |
| `household_members_overview()` | Security-definer read of the caller's own household: `user_id`, `display_name`, `role`, `joined_at`. No email. |
| Drift v12 `accounts.household_ready` | Cached copy of the server flag, default `true`, so the step survives an offline cold start. Migration adds the column only when missing. |

Migration `20261123170000_household_setup_and_members.sql`; pgTAP
`15_household_setup_test.sql`.

## Member planning inputs

**Status**: personal storage and advisory resolver implemented on the 008 work branch. Remaining targets follow the
[contract](contracts/member-planning-inputs.md). Allocate migrations with
Dev 1 after reviewing [the slice plan](plan.md).

| Data | Current | Target and invariants |
|---|---|---|
| Personal tastes | Drift `user_profiles(id, profile_json)`; Supabase `taste_profiles(user_id, profile, updated_at)`; user-scoped sync | Keep the existing row/owner. Add typed JSON fields for liked/disliked food IDs, dish-kind wires and reviewed cuisine codes, plus an optional bounded note in a later slice. Missing new fields read as empty; preserve unrelated legacy keys on edits. Resolve conflicts in planning toward dislike for ranking. |
| Sharing | No separate state | Owner-only SQL `user_planning_sharing(user_id, preferences, revision)` with a read grant and writes through the authenticated `set_planning_preferences_sharing` RPC. Missing row means off at revision 0. The RPC compares the expected revision. Consent mutations stay outside the outbox. The later note slice adds its separate flag. |
| Favorite | Ratings are a separate personal entity | Drift v10 and SQL `user_favorites` hold one owner/recipe pair with the deterministic ID `user_id:recipe_id`. Active state is a boolean so clearing and adding again use the same outbox identity. A favorite follows its recipe: RLS allows it only for a recipe visible in the user's household. Leaving a household, including removal by the owner, deletes the member's favorites and ratings on that household's recipes and syncs tombstones. A recipe brought to a new household is copied, and the household join copies the mover's favorite and rating to the copy (`20261122163000_recipe_marks_follow_join.sql`). Pending favorite writes wait for the join like ratings and are quarantined if skipped. A favorite saved again after rejoining clears its old tombstone unless the recipe was deleted. |
| Allergen selections | No personal relation | Drift v10 `user_allergen_selections(user_id, group_codes_json)` and owner-only SQL `user_allergen_selections(user_id, group_codes, updated_at)` store one validated set per account. A full replacement, including an empty list, is one outbox upsert. SQL migration `20261122160000_user_allergen_selections.sql` enforces the catalog codes. This keeps a selection atomic across retries and allows account deletion to cascade. An empty selection contributes zero codes and requires no additional confirmation record. The owner settings path may read and modify the owner's own choices. Only the server planner reads participant selections for planning, with verified membership. No participant selection data in member aggregates, client plan responses or AI payloads. |
| Catalog mapping | Reviewed identity and matching are separate catalog work | `food_allergen_groups(food_id, group_code)` plus an agreed representation of mapping completeness. An empty relation alone cannot distinguish a reviewed mapping with no matching groups from an unknown one. Metadata describes the food; it carries no association with a member. |
| Planning aggregate | No persisted aggregate or server resolver | Private SQL reads current membership and consent to derive preferences and visible favorites. Catalog food IDs are accepted only from a trusted server allowlist. The allergen union uses a separate private function. Return the allowlisted aggregate without person identifiers, raw personal rows or allergen data. Start with fresh authorized reads and no persisted aggregate. Any later offline cache and queued requests need explicit account/household scope and invalidation. |

### Member planning compatibility and lifecycle

- Reuse the existing account partitioning and transactional outbox for synced
  personal writes. Ordinary sign-out retains the account's cache; account
  deletion purges owned records. Verify fresh/upgrade caches and pending writes
  before enabling new entities. For the dish-kind JSON slice, only the stored
  JSON and existing sync payload change; the SQL and Drift schemas stay intact.
- Deploy the additive SQL migrations before distributing the client that syncs
  these rows. Before favorites upload and after each pull, the client drops
  cached favorites and queued favorite writes for recipes outside the active
  household; the server would reject them. Keep the newer client on
  devices with pending writes for the new sync entities until they upload.
- Additive SQL slices need explicit authenticated grants, RLS and local pgTAP
  tests. A server-side function verifies requester/membership before reading
  peer data. Include allowed operations alongside denial tests and cover
  account/recipe deletion and membership transitions.
- Tastes, allergen selections and planning consent are keyed only by the
  user, so they stay unchanged when the user changes household.
- For new Drift entities, coordinate schema version, generator output, sync
  registry and deletion handling. Specify minimum compatible client behavior
  and forward recovery in each migration PR. No data reset is required by this
  proposal.
