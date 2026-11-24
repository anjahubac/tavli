# Data model proposal: ingredient catalog tables (D1-005)

**Status:** accepted in #56. Rollout step 2 (server tables, RLS, grants and
pgTAP) is `supabase/migrations/20261121150000_food_catalog.sql` with
`supabase/tests/10_food_catalog_test.sql`. The local drift tables, download and
client tests (step 3 onward) are not implemented.
**Source:** D1-005 / FR-002 in [spec.md](spec.md), task T004/T005 in [tasks.md](tasks.md).
**Owner:** Dev 1. **Reviewers requested:** Dev 4 (schema coordinator), Dev 3 (scope and RLS).
**Baseline:** `dev` as of 18 Nov 2026. **Depends on:** the ingredient identity contract in
PR #30 (D1-001, version 1). If #30 changes, this document changes with it.

The server migration followed the acceptance of #30 and this document. The
client step adds the drift tables and takes its drift version last (see Rollout).

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
| `id` | `text` primary key, `char_length(id) between 1 and 64` | Immutable, never derived from the name (#30). Same type and check as every other table, plus a check that it is a UUID string (the contract requires one). See decision D7. |
| `household_id` | `uuid` null, references `households` on delete cascade | `null` = shared reviewed catalog; set = household-owned custom food. |
| `slug` | `text` not null | Readable identifier, separate from `id`. Uniqueness scope is decision D3. |
| `name` | `text` not null, non-empty | Canonical display name. |
| `category` | `text` not null | Existing ingredient category vocabulary; decision D5. |
| `base_unit` | `text` not null, check in (`piece`, `gram`, `milliliter`) | Wire values are decision D6. |
| `source` | `text` null | Provenance of a shared entry (FR-105). |
| `reviewed_at` | `timestamptz` null | Shared rows are promoted only after review (FR-101). |
| `withdrawn_at` | `timestamptz` null, `check (withdrawn_at is null or household_id is null)` | A shared entry is withdrawn by setting this, never by deleting the row (see Withdrawing a shared entry). A household deletes its own food instead, with the usual tombstone. |
| `created_at`, `updated_at`, `updated_by` | as other tables | `updated_by default auth.uid()`. |

### `food_aliases`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `text` primary key, same checks as `foods.id` | |
| `food_id` | `text` not null, references `foods` on delete cascade | A single foreign key: the composite `(id, household_id)` pattern of other tables cannot express a shared (null household) food. |
| `household_id` | `uuid` null, references `households` on delete cascade | `null` = shared alias; set = household confirmation or override. |
| `alias` | `text` not null | As entered or reviewed; the original ingredient text is never rewritten. |
| `alias_normalized` | `text` not null | Output of the one normalization function (decision D4). |
| `withdrawn_at` | `timestamptz` null, `check (withdrawn_at is null or household_id is null)` | Withdraws a wrong shared alias without deleting the row (see Correcting an alias). |
| `created_at`, `updated_at`, `updated_by` | as other tables | |

Uniqueness of aliases differs by owner:

- **Shared aliases:** one active row per `alias_normalized`. A partial unique
  index on `food_aliases (alias_normalized) where household_id is null and
  withdrawn_at is null` enforces it, so a correction can add the replacement
  under the same key after withdrawing the old row. Only migrations write
  shared rows, so the index never rejects a client upload.
- **Household aliases: no unique key**, on the server or in the local cache.
  Several rows of one household may share an `alias_normalized`. Rows that
  name the same food count as one mapping. Rows that name different foods are
  two equally authoritative mappings, and the matcher returns `Unresolved`
  for that key (#30). This is what makes alias replacement safe without a
  server transaction (see Correcting an alias).

A household override and a shared alias may coexist, and the household one wins
(#30).

Slugs follow the same split. Shared slugs are unique (partial unique index on
`foods (slug) where household_id is null`). **Household slugs have no unique
key:** two devices can create the same custom food offline with different
client ids, and a unique `(household_id, slug)` would reject the second upload
permanently. Two such rows are two foods of the household; if both are linked
to the same wording, the matcher returns `Unresolved` and the review UI (#57)
lets the household pick one. (Changed from the accepted D3 during the migration
PR; needs Dev 4 confirmation.)

Consistency: a shared alias must point to a shared food; a household alias may
point to a shared food or to a food of the same household. A foreign key cannot
say "either", so this is enforced by a trigger and covered by a test (decision D2).

## Ownership and consistency rules

- **Ownership is immutable.** `id` and `household_id` of a food, and `id`,
  `food_id` and `household_id` of an alias, cannot change after insert. A
  trigger rejects such an update for every role. Promoting a household food to
  the shared catalog is a new shared row made by a migration or the service
  role, not a change of `household_id`; the household row and its aliases stay.
- **Alias consistency when foods change.** Because ownership cannot change, a
  food cannot move out from under its aliases. The consistency trigger runs on
  every insert and update of `food_aliases`. Updating `name`, `slug` or
  `category` of a food never rewrites aliases or recipe text. Deleting a
  household food removes its aliases (cascade) and the household's links to it
  stop resolving. Shared foods are never deleted once released: recipe links
  live in JSON, which the database cannot check, so a foreign key cannot protect
  them. Clients have no DELETE right on shared rows, and migrations withdraw
  instead of deleting (see below).
- **Name normalization.** `alias_normalized` is the existing `ingredientKey`
  unchanged (decision D4). Inflected forms are reviewed aliases; there is no
  stemming and no diacritic stripping in this slice.
- **Priority.** The canonical name of a food owned by the household counts as a
  confirmed household alias, ahead of shared matches. Mappings of the same
  priority that name different foods stay `Unresolved`. A household alias on a
  shared food never changes who owns that food's canonical name (#30).

## Withdrawing a shared entry

A shared entry that turns out to be wrong is withdrawn: `withdrawn_at` is set
and the row stays, so its id keeps meaning the same thing and clients can learn
about the change through ordinary incremental download. A hard delete would
leave offline caches with a row nobody tells them to drop. The existing
`deletions` tombstone table cannot carry it either: it requires either a
household or a user owner (`check ((household_id is null) <> (user_id is null))`),
and a shared row has neither.

- Clients download shared rows with a cursor on `updated_at` (the existing
  downloader pulls per entity by `updated_at` and `id`, so the foods stream
  would carry shared rows and the household's own rows together under RLS).
  Withdrawing must bump `updated_at`, or the cursor never sees it. A row with
  `withdrawn_at` set replaces the cached one. The matcher ignores withdrawn
  foods and aliases that point to them.
- A recipe link to a withdrawn food is not rewritten. Consumers treat it like an
  unresolved ingredient: the original text stays, and the ingredient can be
  reviewed again (#57).
- An offline device keeps matching against its cache until its next successful
  download. That staleness is accepted: a match is evidence for a suggestion
  and for shopping, not authority, and no write depends on the food still being
  active. The server rejects a new household alias that points to a withdrawn
  food.
- Withdrawal does not touch approved plan snapshots.

## Correcting an alias

`food_id` of an alias is immutable, so a correction never edits the row in
place. It retires the old row and adds a new one, and caches learn about both
through the channels they already use.

| Case | Server change | How a cache picks it up |
| --- | --- | --- |
| Shared food withdrawn | Same migration sets `withdrawn_at` on the food and on its shared aliases, bumping `updated_at`. If a reviewed replacement exists, the migration inserts new shared aliases to it. | Incremental download by `updated_at` brings the withdrawn rows and the new aliases. The matcher ignores withdrawn rows. |
| Shared alias points to the wrong food | Migration sets `withdrawn_at` on that alias and inserts a new shared alias with the same `alias_normalized` to the correct food. | Same as above. Until the next download, the device keeps the old match (accepted staleness, see above). |
| Household alias points to a withdrawn food | The row stays but stops resolving. The matcher returns `Unresolved` for that wording and the review UI (#57) offers it again. Confirming a new food replaces the household alias with the protocol below. | The insert arrives through download, the delete through the existing `deletions` tombstone, like other household rows. |
| Household changes its own mapping | Replacement protocol below. | Same as the previous row. |

Existing recipe links are not rewritten in any case (#30): a link to a withdrawn
food is treated as unresolved, and a link confirmed under an old household
mapping stays until the user reviews that ingredient again.

### Replacing a household alias

The server has no multi-row transaction for client writes. The existing
`Uploader` groups the outbox by entity **and** operation (`_nextBatch()`), so a
delete and an insert are always separate remote calls, and a connection can drop
between them. The local transaction does not make them atomic on the server.
The protocol is therefore built so that every intermediate state is safe on its
own:

1. **One local transaction:** insert the new household alias, then delete every
   other household alias of the same household and `alias_normalized`. The
   outbox therefore holds the upsert **before** the delete(s), and the uploader
   sends them in that order.
2. **Interrupted after the insert:** the server holds the old and the new
   mapping. Other devices see two household mappings to different foods and get
   `Unresolved` for that key: never the stale food, and never a fallback to the
   shared alias, because a household mapping still exists. The outbox retries the
   delete, and the next download brings the tombstone.
3. **Interrupted before the insert:** nothing has changed on the server.
4. **Two devices correct the same key offline** (old → B on one, old → C on the
   other): both inserts are accepted, because household aliases have no unique
   key, so no outbox row is rejected. Both deletes target the old row; a second
   delete of a missing row is a no-op. The household ends with B and C, which is
   `Unresolved`, so the review UI (#57) offers the key again. Confirming one
   food there runs step 1 again and deletes the other row. The household
   resolves the conflict; the server does not pick a winner.
5. **The same food twice** (both devices pick B): two rows, one mapping. The
   matcher treats them as one result. The next confirmation of that key removes
   the extra row.

The sending device applies step 1 locally right away, so its own matcher sees
only the new mapping.

### Local cache staging

The local `FoodAliases` table mirrors the server rule: **no unique index on
`(household_id, alias_normalized)`**, only the primary key on `id`. The
`Downloader` applies entity rows before it pulls `deletions`. A replacement can
therefore arrive before the tombstone of the row it replaces, in the same run or
in a later one if the app restarts in between. The insert never fails on a
unique key. Until the tombstone arrives, the cache holds both rows and the
matcher returns `Unresolved` for that key. After the tombstone, only the new row
remains. Shared aliases keep their uniqueness in the local cache too
(`alias_normalized` where `household_id is null` and `withdrawn_at is null`).
A withdrawn shared row is written in place of the cached row with the same `id`,
so it never collides with its replacement.

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
- Ownership trigger (D8): an update of `id` or `household_id` on a food, and of
  `id`, `food_id` or `household_id` on an alias, is rejected, with an allowed
  update of `name` as the control.
- Withdrawal (D9): withdrawing sets `updated_at`, the downloader receives the
  row, the matcher ignores it, and the server rejects a new household alias
  that points to it; `withdrawn_at` on a household food is rejected.
- Uniqueness: two identical active shared aliases and two identical shared
  slugs are rejected. A withdrawn shared alias and its replacement under the
  same key are accepted. Two household aliases with the same key are accepted,
  and so are the same alias in a household and in the shared catalog.
- Household alias replacement (acceptance fixtures):
  - **Interrupted between insert and delete:** the server holds the old and new
    rows. A second device downloads both and the matcher returns `Unresolved`,
    not the old food and not the shared alias. After the retried delete and the
    tombstone, it returns the new food.
  - **Two devices correct the same key offline** to different foods: both
    uploads succeed and no outbox row is rejected. Both devices then return
    `Unresolved` for the key. Confirming one food deletes the other row, and
    every device converges on it.
  - **Same food from two devices:** two rows resolve to that one food.
  - Outbox order: the upsert of the new row has a lower `seq` than the delete
    of the old one.
- Local cache staging (download fixture): start with the old household alias
  cached. The download delivers the replacement row first and the old row's
  tombstone in a later run, with an app restart between them. The insert
  succeeds, the matcher returns `Unresolved` until the tombstone, then the new
  food. The sync does not repeat a failing insert.
- Both directions of the rollout: a new client against a server without the
  tables, and an old client against a server with them.
- A downstream query test that matches on the stored `alias_normalized` value
  (quality gate for stored value formats).

## Decisions needed (from #30)

| ID | Question | Proposal | Needed from |
| --- | --- | --- | --- |
| D1 | One `foods` table with nullable `household_id`, or separate shared and household tables | One table: one foreign key target and one matcher query. Shared slug uniqueness needs `nulls not distinct` or two partial unique indexes. Shared aliases are unique only while active, household aliases are not unique (see Replacing a household alias). | Dev 4, Dev 3 |
| D2 | How to enforce alias and food consistency | Trigger, since a foreign key cannot express it | Dev 3 |
| D3 | Slug uniqueness scope and rename behavior | Unique among shared rows only; household slugs are not unique so offline duplicates can sync (changed in the migration PR, see Proposed tables); the id never changes on rename | Dev 4 |
| D4 | Normalization function and where it runs | The existing `ingredientKey`, unchanged, so stored `alias_normalized` equals what the client already computes; covered by shared fixtures. Inflections are reviewed aliases. | Dev 2, Dev 4 |
| D5 | Category vocabulary | Reuse the current ingredient categories unchanged | Dev 4 |
| D6 | Wire values for `base_unit` | `piece`, `gram`, `milliliter`, final once 017 settles unit terms | Dev 4 |
| D7 | Id type, generation and validation boundary | `text` ids like every other table, with a UUID-format check; the client generates the UUID string for household rows, migrations for shared rows, the server validates the format | Dev 4 |
| D8 | Immutable ownership | Trigger blocks changing `id` and `household_id`; promotion creates a new shared row | Dev 3, Dev 4 |
| D9 | Withdrawn shared entries | `withdrawn_at` tombstone instead of delete; clients drop it on the next download | Dev 3, Dev 4 |
| D10 | Separate ingredient table or the embedded ingredient list | Keep the embedded list (`foodId`, `matchedKey` and `linkSource` per ingredient, #30). Plans and shopping run in the client over the local database, and no server function queries ingredients today. The [008 contract](../008-household-members/contracts/member-planning-inputs.md) assigns member allergen checks to the server. The server uses the embedded foodId links and reviewed catalog mappings. Revisit a derived table if query performance or per-ingredient access rules require one. | Dev 3, Dev 4; allergen placement Dev 3, Dev 2 |

## Rollout

Shipping the migration and the app change in one PR does not make a deployment
compatible: the hosted server and installed clients change at different times.
The order is therefore:

1. #30 accepted (T001), then this document accepted.
2. **Server first.** Migration PR (T005): new additive SQL file with RLS, grants
   and tests; applied SQL is never edited. It is deployed to hosted only through
   CI and checked there. Nothing reads the new tables yet, and installed clients
   ignore them.
3. **Client second.** The drift tables, the version bump and the read-only
   download ship in a client release that works against a server that does not
   have the tables yet. The download keeps these outcomes separate (#30):
   - **Older server without the catalog.** PostgREST reports the table as
     unknown (`PGRST205`, HTTP 404) or PostgreSQL reports `42P01`. The client
     records "catalog not available on this server", keeps the matcher on
     `Unresolved` for every name and retries on a later sync. This is not an
     error for the user.
   - **Household access failure.** The tables exist but the request is denied
     (`42501`, HTTP 403) or the active household is no longer the user's. An
     expired session (`401`, `PGRST3xx`) stays the existing
     `UnauthorizedSyncError` and is handled as it is today. The client
     drops the cached household foods and aliases of that household and
     discards in-flight results, and shared rows already cached stay readable.
   - **Empty result.** The tables exist and are readable but hold no rows for
     this scope. This is a valid empty catalog, not an error.

   Today `classifySyncError` in `lib/sync/sync_remote.dart` maps both a missing
   table and `42501` to `PermanentSyncError`, so the catalog download needs its
   own classification before this step. Tests cover all three against a fake
   backend. A test also checks that an
   access failure is never classified as "older server". Local and CI checks run both directions:
   new client with old server, old client with new server.
4. **Writes last.** No consumer writes a link, alias or food until step 3 is
   released. Links on recipe ingredients carry the mixed-version gate from #30:
   an older build drops `foodId`, `matchedKey` and `linkSource` when it saves a
   recipe, including from old outbox entries, so link writing stays off until
   that gate is agreed.
5. Forward recovery is a new additive migration, not an edit.
6. No consumer changes until the producer is merged; D1-006 to D1-010 follow.

## Remaining reviews

Dev 3 still has to review scope and access rules, and Dev 4 the schema decisions
D1–D10. Dev 4's support for keeping the link on the embedded ingredient (#30)
is not approval of those.
