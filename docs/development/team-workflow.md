# Four-developer workflow

Status: operating rules, 2026-11-13. Applies to the existing single Flutter app;
it does not introduce four services, four independent databases or new packages.

## Ownership

| Role | Person / Trello account | End-to-end responsibility | Required collaboration |
| --- | --- | --- | --- |
| Dev 1 | umilutinovic25 | Ingredient catalog, quantities/conversions, shopping, nutrition calculation, prices | Coordinates local schema versions, SQL ordering and shared data contracts |
| Dev 2 | Ceviz / ceviz2 | `lib/ai/`, plan generation, planning UI, recipe list/input, future gateway and cookbooks | Dev 1 for ingredient mapping; Dev 3 for member inputs; Dev 4 for voice transport |
| Dev 3 | Matija / matijaradulovic077 | `lib/account/`, household, preferences, allergies, favorites, personal nutrition diary | Owns identity/privacy rules; reviews all permission changes |
| Dev 4 | Anja / anja129 | `lib/app/`, navigation, Home, pantry UI/domain operations, cooking, camera, voice UI, platform integration | Uses Dev 1 shopping/catalog and Dev 2 gateway; integrates Dev 3 calorie component |

Owners follow functionality through domain, repository, sync, server and UI.
Folder names are not exclusive silos. Existing files stay in place unless a
scoped refactor has its own acceptance criteria. GitHub handles for Matija and
Ceviz are not verified: do not invent CODEOWNERS usernames from Trello accounts.
Assign reviewers manually until those handles and repository rules are confirmed.

## Files with several consumers

| File / area | Coordinator | Rule |
| --- | --- | --- |
| `lib/data/database.dart`, `lib/data/database.g.dart` | Dev 1 | Serialize schema merges; regenerate after rebasing |
| `lib/sync/entities.dart`, uploader/downloader cleanup | Dev 1, affected data owner | Review registry, ownership, deletion and account switch together |
| `lib/providers.dart` | Affected owner + consumer | Small wiring PR; feature providers remain in their existing feature folders |
| `lib/app/router.dart`, `home_shell.dart`, `tab_app_bar.dart` | Dev 4 | Route/auth/deep-link tests; preserve existing URLs |
| `pubspec.yaml`, `pubspec.lock`, platform settings | Dev 4 + dependency owner | Dedicated change, dependency reason in active plan, platform check |
| Auth/membership SQL, `lib/account/` | Dev 3 | Security review, two-account and membership-transition tests |
| `lib/data/shopping_repository.dart` | Dev 1 | Split by responsibility before overlapping shopping/pantry work |
| `lib/features/recipes/recipe_detail_screen.dart` | Dev 2 integration; Dev 1 ingredients, Dev 3 personal actions, Dev 4 cooking | Separate widgets in the current recipes directory, not simultaneous edits of one screen |
| `.github/workflows/`, branch rules | Dev 3, Anja for release | Infrastructure PR; document actual enabled checks and missing hosting settings |

Before editing a shared file, record the exact paths, purpose and owner in the
task/PR. The coordinator sequences merges; they do not write every table for
everyone. Review is required for changes across an ownership boundary. A request
to another owner can be a small PR, not a reason to block all independent work.

## Ready → implementation → review → done

1. **Ready:** link Trello card, spec requirement and task ID; name one implementer
   and another human reviewer. Record dependencies, changed files, acceptance,
   data/privacy classification and remaining effort. Drafts are not Ready.
2. **Contract first:** merge a small contract/domain-model PR before consumers
   depend on it. Consumers can prepare isolated tests using fakes. No feature
   branches based on an unmerged producer branch.
3. **Implement:** use a separate branch/worktree per task; limit work in progress
   to one implementation task per person plus review. Aim for 1–2-day slices;
   split work that cannot produce a reviewable result in that interval.
4. **Review:** author summarizes behavior and evidence. Reviewer reads the diff,
   checks the contract and relevant tests; an AI review is additional evidence,
   not the required independent human approval. Resolve shared-file conflicts
   with the owner; do not choose one side wholesale.
5. **Done:** accepted behavior, green required checks, merged PR and validation
   evidence linked from the task. Implementation, integration and release are
   separate states. Never mark Done because an agent says it finished.

Map these states to the board's configured lists; verify the current list names
before moving cards. This document does not change the board. Person labels aid
filtering; the card member is the actual assignee. Existing 20/21/20/26 ticket
counts are assignments, not an assertion of balanced effort.

## Branches and worktrees

Normal work starts from current `origin/dev`, PRs target `dev`:

```bash
git fetch origin
git worktree add -b 034-example-feature ../tavli-034 origin/dev
```

Use the next reserved spec number, not the example literally. A spec may have
sequential implementation slices named `feat/<topic>-<task>` against the same
spec. Each branch has one owner, one topic and one PR; multiple developers never
share a writable checkout. Before merging, update from `dev`, rerun applicable
checks, verify producer PRs and regenerate derived files. Never reset or stash
another person's edits automatically.

Release: tested `dev` → `main` by merge commit. Hotfix: branch from `main`, PR
to `main`, then merge `main` back into `dev`. Production approval and secrets
belong to GitHub environments. Never force push shared branches; ask before any
destructive operation, including history rewrites and branch deletion.

The existing Spec Kit `create-new-feature.sh` prepares files/state; it does not
create a Git branch in this installation. Create/verify the branch separately.
Use worktree-local `SPECIFY_FEATURE_DIRECTORY` explicitly; do not assume that
the tracked `.specify/feature.json` points to your current task.

## Migration coordination

Each data owner writes new SQL for their tables; Dev 1 allocates the next drift
version at integration time. Never preallocate the same version to four PRs.
Record starting/target version, migration filename, affected entities and old
client behavior in the PR. Applied SQL files are immutable. If another schema
PR merges first, update your pending migration/version and regenerate from
source. Test upgrade from the released cache and fresh installation, preserving
IDs, quantities and pending outbox writes. Prefer additive changes; destructive
cleanup needs a separately reviewed compatibility/data-preservation plan.

## Effort and dependencies

Estimate **remaining** engineering days as a range (implementation + tests +
review/integration), with confidence and risk. Count only code verified in this
repository; reference code still needs adaptation and validation. Compare load
per phase and available working days, not ticket counts. Reserve capacity for
review/integration; rebalance with owner approval before changing assignments.

Split cookbooks/RAG, voice, nutrition and Windows into contract, spike, vertical
slice and hardening tasks. A spike has a time box, reproducible evidence and a
go/no-go decision; it does not count as the production feature. Review blocked
work and projected phase load weekly. A developer may help another area through
an owner-reviewed PR while retaining one accountable task owner.

Spec Kit state caveat: the installed `get_feature_paths` persists an explicit
`SPECIFY_FEATURE_DIRECTORY` into that worktree's `.specify/feature.json`, even
when a command only checks prerequisites. Inspect the resulting diff; keep this
session pointer out of a feature PR unless intentionally updating shared default
context. The environment selection is isolated by worktree, not a promise that
the helper is read-only. Do not overwrite another person's existing pointer edit.
