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
2. **Make the floor checkable.** Record the first build number or date that
   contains #100 and have each team member confirm in Trello that their devices
   are on it. Do not rely on "the team updates together".
3. **Drain old outbox entries first.** Before the switch is turned on, the
   `sync_outbox` of every device must be empty (how to check it on a device is
   still to be defined). An entry created by an older build is the only way an old payload
   can arrive after links exist.
4. **Make confirmation recoverable.** A confirmed mapping is also saved as a
   household alias (D2), which outranks shared matches. If a link is ever lost,
   resolving the same name again returns the same food, so the confirmation is
   restored by lookup and not only by the link. This depends on the alias being
   written before the link, and needs the catalog writes of rollout step 4.
5. **Backfill is idempotent and re-checked.** It follows the rules already in
   the proposal: skip a valid link, never overwrite `confirmed`, discard the
   result when the recipe or ingredient changed since it was read, never touch
   approved plan snapshots.

## What this does not solve

- A build older than #100 that appears after the switch is on can still drop
  links on its next save. The switch is a team agreement, not enforcement. A
  server-side minimum client version would enforce it; none exists today, and
  adding one is a separate decision.
- A link dropped that way is repaired by backfill only if no newer user edit
  exists, and a confirmation only if step 4 holds.

## Decisions required

- Dev 3: whether a server-side minimum client version is wanted, or the
  agreement in steps 1 to 3 is enough while the team is small.
- Dev 3 and Dev 4: whether confirm-writes-alias (step 4) is accepted as the
  recovery path for confirmed links.
- Dev 1: record the first build number or date with #100 once it is known.

## Acceptance for the first code slice

- With the switch off, backfill and confirm perform no recipe write.
- With the switch on, running backfill twice leaves the same links and no extra
  aliases or proposals.
- A recipe saved by a build that ignores links is re-read without error.
