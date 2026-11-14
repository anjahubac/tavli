# 010 current direction and remaining scope

Amendment: 2026-11-13. Original spec/tasks/checkmarks remain historical evidence.
This overlay resolves new product decisions without claiming they already ship.

At `dev` `207c94c`, generation/review/calendar/plan edits and plan/recipe shopping
have code, tests and schema v5. The original “implementation not started” header
is stale; full acceptance, pantry/preferences/cooking/UI evaluation remain open.

| Earlier 010 direction | Current accepted direction | Handoff |
| --- | --- | --- |
| Four tabs, Plan opens, Today inside Plan | Five tabs: Plan, Nabavka, Početna, Recepti, Ostava; Home opens | Dev 4, route compatibility tests |
| Pantry expiry/use-in-plan and no automatic consumption | No expiry UX; optional quantity; consume known stock on cooking, undo restores once | Dev 4 + Dev 1 supply contract |
| Creator-only private planning preferences | Purpose-limited authorized household inputs; raw personal rows stay private; favorites aggregation unresolved | Dev 3 producer, Dev 2 consumer |
| Three fixed meal kinds | List-based slots with morning/afternoon snacks; lock/import compatibility | Dev 2; Dev 4 rendering |
| Text ingredient identity | UUID/slug catalog with original text and unresolved fallback | Dev 1; Dev 2/3/4 consumers |
| Existing local built-in provider keys | Planned authenticated Supabase Edge gateway, own keys still device-only | Dev 2 |
| Legacy original plan tasks describe all work in one spec | Completed slices retained; new behavior gets focused spec/contracts and linked tasks | All owners |

Still binding: reviewed drafts, snapshots/servings, delta-only repeat Add,
canonical week/month shopping, six-week months, bought/manual preservation,
one allocation of supply across plan and recipe, idempotent receipt, offline
outbox, account isolation and original recipe-photo access.

Before implementing remaining tasks T035–T046, rewrite their **future execution
plan** against these changes in the owning feature. Do not implement obsolete
expiry tests, four-tab assertions or no-consumption rules just because their old
checkbox is still open. Retain their original text/IDs and record replacement
tasks/requirements, not a fabricated completed acceptance history.

The full plan is in [product plan](../../docs/product-plan.md), with
[shared contracts](../011-team-development/contracts/shared-boundaries.md).
Architecture describes actual existing paths; this overlay adds no tables,
routes or providers by itself. Old personal-data grants are not loosened by
this amendment: agree purpose/consent/RLS before exposing planning aggregates.
