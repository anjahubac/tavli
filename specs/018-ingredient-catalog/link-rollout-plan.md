# Rollout plan: persisting ingredient catalog links

**Status**: draft proposal for review; not an accepted decision.
**Author**: Dev 1 | **Proposed reviewers**: Dev 3 (sync and server), Dev 4 (consumers)
**Closes**: the open item "rollout plan for mixed-version writes and old outbox
entries" in the [ingredient model proposal](ingredient-model-proposal.md).
**Gates**: D1-008 part 2 (writing links). Nothing in this document changes code.

## Problem

An ingredient link (`foodId`, `matchedKey`, `linkSource`) is additive JSON on the
embedded ingredient. Builds from before #100 do not know these fields: reading a
recipe drops them, and saving that recipe writes it back without them. With
several devices syncing one household, an old build can silently remove links,
including a `confirmed` link a person set by hand. Backfill must not be assumed
to restore it.

Three cases are affected:

| Case | What goes wrong |
| --- | --- |
| Old build edits a linked recipe and uploads it | The links disappear from the synced row. |
| Old build has a pending outbox entry for a recipe | When it replays after a new build wrote links, it overwrites them without links. |
| New build reads a row without links | Nothing breaks: absence of a link is valid and means unresolved. |

Only the first two lose data. Reads in either direction stay compatible.

## Proposed approach

1. **Write nothing until the floor is reached.** Link writes (backfill and the
   confirm action of D1-009) sit behind one local switch that is off by default.
   It may be turned on only when every device that syncs the household runs a
   build that contains #100 (merged 2026-11-21), including any build that still
   holds pending outbox entries.
2. **Make the floor checkable.** Every build today reports the same version
   (`1.0.0+1`), so a build cannot show which side of #100 it is on. Bump the
   build number once, in a change merged after #100, and record that number as
   the floor. Have each team member confirm in Trello that their devices run it
   or a later build. Do not rely on "the team updates together".
3. **Drain old-build outbox entries first.** Before the switch is turned on, the
   `sync_outbox` of every device must be empty (how to check it on a device is
   still to be defined). This covers only writes already queued by a build that
   does not know the link fields. It does not cover the next case.
4. **Keep links when an upgraded device uploads a stale recipe** (see the next
   section). This is the rule that protects links once the switch is on.
5. **Backfill is idempotent and re-checked.** It follows the rules already in
   the proposal: skip a valid link, never overwrite `confirmed`, discard the
   result when the recipe or ingredient changed since it was read, never touch
   approved plan snapshots.

## Stale recipe writes from an upgraded device

The uploader reads the current local recipe row and sends the whole
`ingredients` array, and the server keeps the last write. A device that was
offline can therefore hold a recipe without links that another device added in
the meantime, edit it, and later overwrite those links. Draining the outbox
does not help here: the edit is queued after the rollout.

Proposed rule: **before it uploads a recipe row, the client reads the row that
is on the server and carries links forward.** For each local ingredient that has
no valid link, take the server's link when its `matchedKey` equals
`ingredientKey(name)` of the local ingredient (the same carry rule as
`carryIngredientLinks` after an AI edit, with the server row as the source).
Two guards:

- A local `unlinkedKey` that equals the current key means the person removed the
  link on purpose; do not carry it back
  ([D1-009](unresolved-review-ui.md)).
- A local `confirmed` link is kept, and a server `confirmed` link wins over a
  local `matched` one. A name edited since the link was made no longer matches
  `matchedKey`, so nothing is carried.

If the read fails (offline, error), the upload waits and retries; it is never
sent without the check while the switch is on. The cost is one extra read per
recipe upload, which is small at household scale. A server-side merge in SQL
would avoid the read but would need `ingredientKey` implemented a second time
in SQL, so it is not proposed here.

**Two-device acceptance case** (to be a test before the switch is turned on):

| Step | Device A | Device B (upgraded, offline) |
| --- | --- | --- |
| 1 | Online; the recipe has no link for "jaja". | Syncs; has the same recipe, no link. Goes offline. |
| 2 | Confirms "jaja" → food; the link is saved and uploaded. | Edits a quantity of another ingredient. The edit is queued. |
| 3 | | Goes online; the upload reads the server row first. |
| Expected | The server keeps the `confirmed` link for "jaja" and has B's quantity edit. | After the next sync it has the link. |

Variants that must also pass: B renames "jaja" while offline (the link is not
carried, the original text is kept); B removes the link on purpose offline (the
removal is kept through `unlinkedKey`); B's upload fails the read (nothing is
sent until it succeeds).

## Recovering lost links

D1-009 confirms **this ingredient only** by default and writes a household alias
only when the person turns on the separate switch. The plan follows that:

- A confirmation with the alias switch **on** is recoverable: the household
  alias outranks shared matches, so resolving the same text again returns the
  same food.
- A recipe-only confirmation (the default) lives only in the link. If an old
  build or any other path loses it, nothing recovers it automatically. The
  ingredient becomes unresolved again, keeps its original text and appears in
  the review list, where the person confirms it again. This is accepted as a
  cost, and it is the reason the first four steps above exist: they keep it from
  happening, not repair it afterwards.

This replaces the earlier proposal that every confirmation also writes an alias,
which contradicted D1-009.

## What this does not solve

- A build older than #100 that appears after the switch is on can still drop
  links on its next save. The switch is a team agreement, not enforcement. A
  server-side minimum client version would enforce it; none exists today, and
  adding one is a separate decision.
- A recipe-only confirmation dropped that way needs the person to confirm it
  again.

## Operating the switch (review of #168)

These points answer the #168 review. They are proposals until the decision
owners below record them.

- **Who runs the backfill.** Nothing in `lib/` calls `backfillCatalogLinks`
  yet, so the shipped code stays dormant. Proposal (Dev 1): the build that
  opens the switch also runs the backfill once per account at startup, after
  the first successful sync. A second trigger is not needed because the
  backfill is idempotent.
- **A compile-time switch and the "all devices" condition.** `recipeLinkRollout`
  is a `const`, so opening it needs a new build. That fits the floor: the floor
  for understanding the link fields is the build that includes #100. Before
  opening the switch, verify that every syncing device also protects links
  when uploading a stale recipe and uses the same shopping key rules. A build
  that understands links but keeps the switch closed can still upload a stale
  recipe without carrying server links forward and reconcile shopping by
  text. Drain old outboxes as in step 3 and keep the switch closed until the
  team agrees how to prevent mixed behavior across devices.
- **Unreadable server ingredients.** When the server row's `ingredients` cannot
  be read, the uploader rejects that outbox entry (`recipe_ingredients_invalid`)
  and goes on with the next ones. A transient error here would retry forever
  and hold up the whole outbox. The server row is left unchanged, so no link is
  overwritten. The rejected entry is not retried. After the server row is
  repaired, the recipe needs to be saved again to queue another upload.
- **Fetch and upsert are not atomic.** A link written by another device between
  the uploader's read and its upsert can still be overwritten. The window is
  the time between the read and the write. Backfill may resolve a lost match
  from an alias, but cannot recover a recipe-only confirmation. The decision
  owners need to accept this risk before enabling the switch. A server-side
  merge would remove the client-side race.
- **`updatedAt` and ordering.** Backfill sets `updatedAt` on every recipe it
  links. Recipe lists are ordered by `createdAt` (`RecipeRepository._all`) and
  no list in `lib/` orders by `updatedAt`, so one backfill does not reorder the
  user's recipes. It does make every linked recipe sync again once.

## Decisions required

- Dev 3: whether a server-side minimum client version is wanted, or the
  agreement in steps 1 to 3 is enough while the team is small.
- Dev 4: whether the "read the server row before upload" rule is accepted for
  recipe uploads, including the extra read.
- Dev 3: whether the backfill trigger above (once at startup of the build that opens the switch) is accepted.
- Dev 1 and Dev 4: agree the build number that becomes the floor (the current version is `1.0.0+1` in every build), and bump it in a separate change.

## Acceptance for the first code slice

- With the switch off, backfill and confirm perform no recipe write.
- With the switch on, running backfill twice leaves the same links and no extra
  aliases or proposals.
- A recipe saved by a build that ignores links is re-read without error.
- The two-device case above, with its three variants.
