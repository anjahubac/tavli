# Data model proposal: ingredient catalog tables (D1-005)

**Status:** proposal for review; nothing here is implemented, migrated or agreed.
**Source:** D1-005 / FR-002 in [spec.md](spec.md), task T004/T005 in [tasks.md](tasks.md).
**Owner:** Dev 1. **Reviewers requested:** Dev 4 (schema coordinator), Dev 3 (scope and RLS).
**Baseline:** `dev` 9fe5345. **Depends on:** the ingredient identity contract in
PR #30 (D1-001, version 1). If #30 changes, this document changes with it.

This is documentation only. It adds no migration, drift table, generated code or
drift version. The migration PR (T005) starts only after #30 and this document are
accepted, and takes its drift version last (see Rollout).

## Current state (verified on `dev`)

| Area | Today |
| --- | --- |
| Recipe ingredients | Embedded JSON in `recipes.ingredients`: name, quantity, unit, category, note. No food identity. |
| Shopping and pantry | `shopping_items` and `pantry_items` hold `name`, `quantity`, `unit`, `category` as text. No food identity. |
| Ids | Household tables use text ids (1–64 chars) made on the device; `id` is unique together with `household_id` and children use a composite foreign key. |
| Access | RLS on every table; `anon` has no rights; household rows use `private.is_member(household_id)`. |
| Reference data | **None.** No table is shared read-only across households yet, so this is the first one. |
| Local database | drift `schemaVersion` is 5 (`lib/data/database.dart`). |

## Scope

In scope for D1-005: the shared and household-owned **foods** and **aliases**
tables (server and local), their access rules, sync classification and tests.

Out of scope, each with its own task: seed data (D1-006), matcher (D1-007),
linking `food_id` into recipes and backfill (D1-008), review UI (D1-009),
ingredient units, density and conversions (D1-010, depends on 017), nutrition
(D1-011). The shape below leaves room for them without adding their columns.

## Proposed tables

### `foods`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` primary key | Immutable, never derived from the name (#30). |
| `household_id` | `uuid` null, references `households` on delete cascade | `null` = shared reviewed catalog; set = household-owned custom food. |
| `slug` | `text` not null | Readable identifier, separate from `id`. Uniqueness scope is decision D3. |
| `name` | `text` not null, non-empty | Canonical display name. |
| `category` | `text` not null | Existing ingredient category vocabulary; decision D5. |
| `base_unit` | `text` not null, check in (`piece`, `gram`, `milliliter`) | Wire values are decision D6. |
| `source` | `text` null | Provenance of a shared entry (FR-105). |
| `reviewed_at` | `timestamptz` null | Shared rows are promoted only after review (FR-101). |
| `created_at`, `updated_at`, `updated_by` | as other tables | `updated_by default auth.uid()`. |

### `food_aliases`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` primary key | |
| `food_id` | `uuid` not null, references `foods` on delete cascade | |
| `household_id` | `uuid` null, references `households` on delete cascade | `null` = shared alias; set = household confirmation or override. |
| `alias` | `text` not null | As entered or reviewed; the original ingredient text is never rewritten. |
| `alias_normalized` | `text` not null | Output of the one normalization function (decision D4). |
| `created_at`, `updated_at`, `updated_by` | as other tables | |

Uniqueness: one row per (`household_id` or shared, `alias_normalized`), so a
household override and a shared alias may coexist and the household one wins (#30).
Two equally authoritative visible mappings that disagree resolve to `Unresolved`,
which the matcher handles; the table only has to keep both rows.

Consistency: a shared alias must point to a shared food; a household alias may
point to a shared food or to a food of the same household. A foreign key cannot
say "either", so this is enforced by a trigger and covered by a test (decision D2).

## Access rules (server)

| Rows | Read | Write |
| --- | --- | --- |
| Shared (`household_id is null`) | every `authenticated` user | nobody from a client; only migrations and the service role |
| Household-owned | members of that household | members of that household, `with check` keeps the row in their household |

`anon` keeps no rights. New tables follow the existing `revoke all` baseline, then
explicit `grant select` on both tables and `grant insert, update, delete` limited
by policy to household rows. A client can never edit the shared catalog or another
household's food (US3 / SC-003).

## Sync and deletion

- Shared rows download as read-only reference data (see `docs/architecture.md`);
  they are not part of the outbox and are not exported as personal data.
- Household rows are ordinary outbox-backed writes through a `SyncEntity`, scoped
  by `household_id`, with deletion tombstones like other household data.
- Account and household deletion: household rows go with `on delete cascade`;
  `delete_account_data` needs a test that custom foods and aliases are removed.

## Local database (drift)

Two additive tables, `Foods` and `FoodAliases`, mirroring the columns above with
raw server values; parsing stays in the domain. Created with `m.createTable` in
one upgrade step; existing rows are unaffected. The drift version is **not**
fixed here. It is the next free number when the migration PR merges, because #31
and the recipe labels slice (#54) also need one.

## Tests required before the migration PR is ready

- Local `supabase db reset` and `supabase test db`: two accounts, own and foreign
  household, allowed and denied reads and writes, shared rows read-only, alias
  consistency trigger accepts and rejects, deletion removes household rows.
- Allowed-case controls next to every denial.
- drift upgrade from the previous version and fresh-install test.
- Outbox and account-switch regression for household rows.
- A downstream query test that matches on the stored `alias_normalized` value
  (quality gate for stored value formats).

## Decisions needed (from #30)

| ID | Question | Proposal | Needed from |
| --- | --- | --- | --- |
| D1 | One `foods` table with nullable `household_id`, or separate shared and household tables | One table: one foreign key target and one matcher query. Costs two partial unique indexes. | Dev 4, Dev 3 |
| D2 | How to enforce alias and food consistency | Trigger, since a foreign key cannot express it | Dev 3 |
| D3 | Slug uniqueness scope and rename behavior | Unique among shared rows and within one household; the id never changes on rename | Dev 4 |
| D4 | Normalization function and where it runs | One documented function, same result on client and server, covered by shared fixtures | Dev 2, Dev 4 |
| D5 | Category vocabulary | Reuse the current ingredient categories unchanged | Dev 4 |
| D6 | Wire values for `base_unit` | `piece`, `gram`, `milliliter`, final once 017 settles unit terms | Dev 4 |
| D7 | UUID generation and validation boundary | Client generates UUID for household rows, server validates format | Dev 4 |

## Rollout

1. #30 accepted (T001), then this document accepted.
2. Migration PR (T005): new SQL file with RLS, grants and tests; applied SQL is
   never edited. The drift tables and the version bump ship in the same PR so a
   client never talks to a server without them.
3. Hosted deployment only through CI; forward recovery is a new additive
   migration, not an edit.
4. No consumer changes until the producer is merged; D1-006 to D1-010 follow.
