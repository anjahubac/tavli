# Unresolved-ingredient review UI proposal (D1-009)

**Status:** proposal for review; nothing here is implemented or agreed.
**Source:** D1-009 / FR-006 in [spec.md](spec.md), tasks T012/T013 in [tasks.md](tasks.md).
**Owner:** Dev 1. **Reviewers requested:** Dev 4 (recipe and shopping screens), one independent consumer.
**Baseline:** `dev` 9fe5345. **Depends on:** the ingredient contract and ingredient link
in PR #30, the tables in PR #56, the matcher (D1-007) and the backfill (D1-008).

## Why

The matcher leaves uncertain ingredients unresolved on purpose. A person needs a
way to connect one to a food, or to create their own food, at the moment it
matters: when they check a recipe's ingredients before shopping. Resolving must
never block shopping; an unresolved ingredient keeps working by name (FR-104).

## Goals, non-goals, anti-goals

- **Goal:** in the existing "Proveri sastojke" sheet, a row that is not linked to a
  food offers a way to link it or to create a food, without leaving the sheet.
- **Non-goal:** a separate list of every unresolved ingredient across all recipes.
  It can be added later if the need shows. Nor does this task change quantities,
  units (D1-010), nutrition or the shared catalog.
- **Anti-goal:** a blocking step, a mandatory review before shopping, or any write
  that happens without an explicit tap.

## Where it lives today

`lib/features/recipes/ingredient_review_sheet.dart` (`showIngredientReview`),
opened from `ai_preview.dart` and the recipe view. It lists a recipe's
ingredients, tracks which ones the person already has by list position, scales
quantities with copies built as `Ingredient(...)`, and saves nothing until
"Dodaj u nabavku". Two consequences for this task: the copies must keep the link
fields once `Ingredient` has them, and a link made here has to say what is stored
when the recipe is not in the library.

## Approaches considered

| # | Approach | Trade-off |
| --- | --- | --- |
| 1 | **Actions in the row and one picker** (chosen) | Smallest scope, the action sits where the decision is made. A second modal opens over the sheet, so narrow screens and 2× text need care. |
| 2 | A top banner ("N ingredients are not linked · Proveri") that steps through them | Better for many unresolved rows, but more state and an extra step for people who do not care. Can be added later. |
| 3 | Resolve everything before the sheet opens | Rejected: blocks shopping and contradicts FR-104. |

Chosen on 2026-11-18 by Dev 1: approach 1.

## Behavior

A row is in one of three states, taken from the matcher result and the stored link
(a link is valid only while its `matchedKey` equals `ingredientKey(name)`):

| State | What the row shows | Action |
| --- | --- | --- |
| Linked | The ingredient as today | none |
| Proposed (the matcher has a candidate) | the suggestion | **Proveri** opens the picker with the candidate selected |
| Unresolved | the ingredient as today | **Poveži namirnicu** opens the picker; **Nova namirnica** opens the food form |

- **Picker.** A search field over the foods visible to the active household (shared and
  household-owned), served from the local snapshot so it works offline. Choosing a food
  is the confirmation: it writes a household alias for the ingredient's text, through the
  outbox, and links the ingredient (`foodId`, `matchedKey`, `linkSource: confirmed`).
- **Where the link is stored.** If the recipe is in the library (`recipeId` is set) the
  link is saved on the recipe. Otherwise it exists only in the snapshot passed to the
  shopping addition. The alias is written in both cases, because it describes the
  household's wording, not the recipe.
- **Nova namirnica.** A small form with the name prefilled from the ingredient, a
  category and a base unit. It creates a household food and an alias for the original
  text. It never writes to the shared catalog.
- **Cancel or dismiss.** Nothing is written. Repeating a confirmation is idempotent:
  the same alias and link, no duplicates.
- **Offline.** Works from the local snapshot; writes wait in the outbox.
- **Errors.** A failed write keeps the row unresolved and offers a retry. If the active
  household changes while the picker is open, the result is discarded (#30).
- **Shopping.** Quantities, units and the "Dodaj u nabavku" result are unchanged;
  an unresolved ingredient is still added by name.

## Copy

Exact copy from the spec: "Poveži namirnicu", "Nova namirnica", "Proveri". All other
text (field labels, empty search result, error and confirmation messages, the
unresolved marker) must be written in Serbian Latin and listed here before this task is
Ready; nothing else is invented in this proposal.

## UI standard

Follows [the UI standard](../../docs/development/ui-standard.md): actions at least
48×48 dp, long Serbian copy wraps or stacks at 2× text, the picker uses the current
adaptive sheet or dialog with a bounded width and restores focus on close, keyboard and
screen-reader support, reduced motion, and no state shown by color alone. The pull
request records phone widths 320 and 400, wide 1200, light and dark, text 1× and 2×,
and the loading, empty, error and offline states.

## Files likely touched

- `lib/features/recipes/ingredient_review_sheet.dart`: row states and actions; the
  scaled copies must keep the link.
- A new picker and food form. Placement (a `lib/features/foods/` folder or under
  `recipes/`) is a shared-path decision for Dev 4.
- `lib/providers.dart` for the food and alias providers until a feature needs its own file.
- Tests under `test/features/recipes/`.

## Tests required

Widget tests with fakes: each of the three row states; choosing a food writes one
alias and links the ingredient; cancel writes nothing; repeating the choice creates no
duplicate; offline choice is queued; a renamed ingredient stops being linked; no overflow
at 2× text on 320 dp; the picker works by keyboard. Repository tests for the alias and
household food writes belong to D1-007 and D1-005.

## Decisions needed

| ID | Question | Proposal | Needed from |
| --- | --- | --- | --- |
| U1 | Is the household alias written immediately on confirmation, even if the sheet is closed without adding to shopping? | Yes: the tap is the explicit confirmation | Dev 4, Dev 3 |
| U2 | Where do the picker and food form live? | A new `lib/features/foods/` folder | Dev 4 |
| U3 | What does the Proposed state show before the AI-assisted proposal exists? | Only matcher candidates from reviewed aliases; AI suggestions arrive with the gateway | Dev 2 |
| U4 | Serbian copy for all remaining text | Written by Dev 1, reviewed before Ready | Dev 1 |

## Sequencing

1. #30 accepted, then #56 and the matcher (D1-007) and backfill (D1-008) merged.
2. Copy finalized, then this proposal accepted.
3. One UI PR for T012/T013, test first, from the latest `dev`.
