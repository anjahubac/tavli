# Data model: 006a

Two stores: the **server** (Supabase Postgres + Storage, durable) and the
**device** (drift, offline cache + outbox). Decisions in [research.md](research.md);
SQL-level rules in [contracts/server-schema.md](contracts/server-schema.md).

## Server (Postgres, schema `public`)

All tables: RLS on, `anon` no access, `authenticated` only the grants listed.
`updated_at timestamptz not null default now()` is set by trigger
`private.touch_updated_at()` (`clock_timestamp()`) on insert and update.

### Accounts

| Table | Columns | Rules |
|---|---|---|
| `profiles` | `id uuid pk → auth.users on delete cascade`, `email text not null`, `display_name text null check (display_name is null or char_length(btrim(display_name)) between 1 and 40)`, `created_at`, `updated_at` | select own; update own (`display_name` column only). Created by trigger. |
| `households` | `id uuid pk default gen_random_uuid()`, `name text not null default 'Moje domaćinstvo'`, `created_by uuid → auth.users on delete set null`, `created_at`, `updated_at` | select if member. No client writes in 006a. |
| `household_members` | `household_id uuid → households on delete cascade`, `user_id uuid → auth.users on delete cascade`, `role text not null check (role in ('owner'))`, `joined_at`, pk `(household_id, user_id)` | select rows of own households. No client writes in 006a. |

Provisioning (`private.handle_new_user`, `AFTER INSERT ON auth.users`): one
profile (`email` = `lower(new.email)`, `display_name` null), one household, one
owner membership. Exactly once per auth user.

### Household data (`household_id uuid not null → households on delete cascade`)

Common columns: `id text pk check (char_length(id) between 1 and 64)`,
`household_id`, `created_at timestamptz not null`, `updated_at`,
`updated_by uuid default auth.uid()`. Policies: select/insert/update/delete when
`private.is_member(household_id)`; update `with check` the same (cannot move a row
to a foreign household).

| Table | Own columns (mirroring drift) |
|---|---|
| `recipes` | `title text not null`, `servings int not null check (servings > 0)`, `prep_minutes int`, `source text not null`, `ingredients jsonb not null`, `steps jsonb not null`, `image_path text` (file name only), `answered_by text` |
| `recipe_versions` | `recipe_id text not null → recipes on delete cascade`, `recipe_json jsonb not null`, `instruction text`, `change_kind text not null`, `changed_by text` |
| `shopping_lists` | `name text not null`, `meal_plan_id text → meal_plans on delete set null`, `week int` |
| `shopping_items` | `list_id text not null → shopping_lists on delete cascade`, `name text not null`, `quantity double precision`, `unit text`, `category text not null`, `is_bought bool not null default false`, `is_manual bool not null default false`, `from_recipe_ids jsonb not null default '[]'` |
| `pantry_items` | `name text not null`, `quantity double precision`, `unit text`, `category text not null`, `added_at timestamptz not null`, `expires_at timestamptz` |
| `meal_plans` | `start_date timestamptz not null`, `end_date timestamptz not null`, `meal_types jsonb not null`, `use_pantry bool not null default true` |
| `meal_plan_entries` | `plan_id text not null → meal_plans on delete cascade`, `date timestamptz not null`, `meal_type text not null`, `recipe_id text → recipes on delete set null`, `is_locked bool`, `is_cooked bool` |

### Personal data (`user_id uuid not null default auth.uid() → auth.users on delete cascade`)

Policies: all operations when `user_id = (select auth.uid())`; insert/update for
`ratings` additionally require `private.is_member` of the recipe's household.

| Table | Columns |
|---|---|
| `ratings` | `id text pk`, `user_id`, `recipe_id text not null → recipes on delete cascade`, `stars int check (stars between 1 and 5)`, `is_comfort_food bool`, `comment text`, `cooked_at timestamptz`, `created_at`, `updated_at` |
| `taste_profiles` | `user_id uuid pk`, `profile jsonb not null`, `updated_at` |

### Tombstones

| Table | Columns | Rules |
|---|---|---|
| `deletions` | `entity text`, `record_id text`, `household_id uuid null`, `user_id uuid null`, `deleted_at timestamptz default clock_timestamp()`, pk `(entity, record_id)`; check exactly one of household_id / user_id | select when member of `household_id` or `user_id = auth.uid()`. Written only by `AFTER DELETE` triggers (security definer). No FK, removed by `delete_account_data`. |

`BEFORE INSERT` triggers on data tables return `NULL` when `(entity, id)` — or
the parent's `(entity, parent_id)` — exists in `deletions` (deletion wins).

### Storage

Bucket `recipe-photos` (private, `file_size_limit` 5 MB, `image/jpeg` only).
Object name `{household_id}/{file}.jpg`. Policies on `storage.objects` for
select/insert/update/delete: `bucket_id = 'recipe-photos' and
private.is_member(((storage.foldername(name))[1])::uuid)`.

## Device (drift, schema v3 → v4)

### Changed tables

| Table | Change in v4 |
|---|---|
| `Recipes` | + `householdId text null` |
| `RecipeVersions` | `id int` → `id text` pk; + `householdId` |
| `PantryItems` | `id int` → `id text`; + `householdId` |
| `ShoppingLists` | + `householdId` |
| `ShoppingItems` | `id int` → `id text`; + `householdId` |
| `MealPlans` | + `householdId` |
| `MealPlanEntries` | `id int` → `id text`; + `householdId` |
| `Ratings` | `id int` → `id text`; + `userId text null` |
| `UserProfiles` (taste) | `id int` → `id text` pk = userId (`'legacy'` for the pre-account row) |

Existing rows: integer ids become `lower(hex(randomblob(16)))`; scope columns are
`null` (= predates accounts) until the legacy move. Migration via
`TableMigration` with `columnTransformer`; covered by `test/data/migration_test.dart`.
`RecipeVersion.id` becomes `String` (domain), `RecipeRepository.restore(String)`.

### New tables

| Table | Columns | Notes |
|---|---|---|
| `Accounts` | `userId text pk`, `email`, `displayName null`, `householdId`, `householdName`, `role`, `initialDownloadDone bool default false`, `lastPullAt datetime null`, `createdAt` | Cached profile + household for offline start; one row per account that signed in on the device. |
| `SyncOutbox` | `seq int autoinc pk`, `accountId text`, `entity text`, `recordId text`, `op text` (`upsert`/`delete`/`photoUpload`/`photoDelete`), `state text default 'pending'` (`pending`/`rejected`), `attempts int default 0`, `nextAttemptAt datetime null`, `lastError text null` (error code only, never payload), `createdAt` | Index `(accountId, state, seq)`; at most one pending `upsert` per `(accountId, entity, recordId)`. |
| `SyncCursors` | `accountId`, `entity`, `updatedAt datetime`, `lastId text`, pk `(accountId, entity)` | Download position (resumable, incremental). |

`AppSettings['legacy_move']` = JSON `{accountId, finishedAt}` — the device-level
move record (FR-019). No session, token or key ever goes into drift (FR-007).

### Entity registry (`lib/sync/entities.dart`)

| `entity` | drift table | server table | scope | parent (for tombstone check / order) |
|---|---|---|---|---|
| `profile` | `Accounts` (displayName) | `profiles` | user | — |
| `recipe` | `Recipes` | `recipes` | household | — |
| `recipe_version` | `RecipeVersions` | `recipe_versions` | household | recipe |
| `shopping_list` | `ShoppingLists` | `shopping_lists` | household | meal_plan (nullable) |
| `shopping_item` | `ShoppingItems` | `shopping_items` | household | shopping_list |
| `pantry_item` | `PantryItems` | `pantry_items` | household | — |
| `meal_plan` | `MealPlans` | `meal_plans` | household | — |
| `meal_plan_entry` | `MealPlanEntries` | `meal_plan_entries` | household | meal_plan |
| `rating` | `Ratings` | `ratings` | user | recipe |
| `taste_profile` | `UserProfiles` | `taste_profiles` | user | — |

Each entry provides `toRemote(row) → Map` and `fromRemote(Map) → Companion`
(snake_case ↔ camelCase, JSON text ↔ jsonb, local relative photo path ↔ file
name).

## State transitions

**Auth** (`AuthState`): `starting → signedOut(reason?)`;
`signedOut → codeSent(email, sentAt) → verifying → needsName | signedIn`;
`needsName → signedIn`; `signedIn → signedOut(null)` (sign-out) |
`signedOut(sessionExpired)` (refresh refused) | `signedOut(accountDeleted)`.
`codeSent` is never persisted (edge case: reopening shows the email step).

**Outbox entry**: `pending → (sent: removed)`; `pending → pending (attempts+1,
nextAttemptAt)` on transient error; `pending → rejected` on permanent error;
`pending → removed` when its record is deleted (coalesced) or a download
tombstone arrives.

**Sync status**: `allSaved ↔ sending ↔ waiting(n)`; `rejected(n)` while any
rejected entries exist (shown with priority).

**Account lifecycle on the device**: first sign-in → `Accounts` row → legacy
move (once per device) → initial download → `initialDownloadDone`; sign-out
keeps everything; delete removes the account's rows, outbox, cursors and
`Accounts` row.
