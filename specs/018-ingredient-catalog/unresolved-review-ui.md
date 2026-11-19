# Unresolved-ingredient review UI proposal (D1-009)

**Status:** proposal for review; nothing here is implemented or agreed.
**Source:** D1-009 / FR-006 in [spec.md](spec.md), tasks T012/T013 in [tasks.md](tasks.md).
**Owner:** Dev 1. **Reviewers requested:** Dev 4 (recipe and shopping screens), one independent consumer.
**Baseline:** `dev` as of 18 Nov 2026. **Depends on:** the ingredient contract and ingredient link
in PR #30, the tables in PR #56, the matcher (D1-007) and the backfill (D1-008).

## Why

The matcher leaves uncertain ingredients unresolved on purpose. A person needs a
way to connect one to a food, or to create their own food, at the moment it
matters: when they check a recipe's ingredients before shopping. Resolving must
never block shopping; an unresolved ingredient keeps working by name (FR-104).

## First slice and reuse

Shopping is the first slice: the existing "Proveri sastojke" sheet. The picker
and food form are built as reusable components with no dependency on that sheet,
so recipe and pantry flows can open the same picker later. Showing the actions
only at purchase time is a first-slice choice, not a settled rule; it still
needs its own UX review against the recipe and pantry journeys before it is
accepted.

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

For matcher v1, a unique reviewed match is `Matched` and a conflict or no match is
`Unresolved`. `Proposed` waits until there is something to propose (U3). A row is in
one of two states, taken from the matcher result and the stored link (a link is valid
only while its `matchedKey` equals `ingredientKey(name)`):

| State | What the row shows | Action |
| --- | --- | --- |
| Linked (`Matched`) | The ingredient as today, with the food name | **Promeni vezu** and **Ukloni vezu** (see Correcting a link) |
| Unresolved | The ingredient as today, marked "Nije povezano" | **Poveži namirnicu** opens the picker; **Nova namirnica** opens the food form |

- **Picker.** A search field over the foods visible to the active household (shared and
  household-owned), served from the local snapshot so it works offline. Choosing a food
  only selects it; nothing is written until the person confirms (see Commit and cancel).
- **Scope of a link.** By default a confirmation links **this ingredient only**
  (`foodId`, `matchedKey`, `linkSource: confirmed`). It does not create a household
  alias. A separate, visibly labeled switch, off by default, also remembers the wording
  for the whole household ("Zapamti i za druge recepte u domaćinstvu"), with a line
  that says what it does. Only then is a household alias written, and it affects future
  lookups of the same text in every recipe of that household.
- **Where the link is stored.** If the recipe is in the library (`recipeId` is set) the
  link is saved on the recipe. Otherwise it exists only in the snapshot passed to the
  shopping addition.
- **Nova namirnica.** A small form with the name prefilled from the ingredient, a
  category and a base unit. It creates a household food and links the ingredient to it,
  with the same scope switch for the alias. It never writes to the shared catalog.
- **Offline.** Works from the local snapshot; writes wait in the outbox.
- **Errors.** A failed write keeps the row unresolved and offers a retry. If the active
  household changes while the picker is open, the result is discarded (#30).
- **Shopping.** Quantities, units and the "Dodaj u nabavku" result are unchanged;
  an unresolved ingredient is still added by name.

## Commit and cancel

- **Before confirmation.** Choosing a row in the picker, typing in the food form or
  closing the picker, the sheet or the app writes nothing. Cancel and dismiss are the
  same.
- **Confirmation** is the tap on "Poveži" (or "Sačuvaj" in the food form). It is one
  local database transaction that holds every related write: the link on the recipe
  (when it is in the library), the household food or alias when chosen, and their
  outbox entries. Either all of it is saved or none of it is; the outbox never holds
  an alias without the link it was made with, or the other way around.
- **Newer recipe edits win.** The write compares the recipe row and the ingredient
  (its name and any existing link) with what the sheet read when it opened. If the
  recipe was changed meanwhile, nothing is written, the row stays as it was and the
  person sees "Recept je u međuvremenu izmenjen" with a way to reload the sheet. A
  link is never written over a newer edit.
- **After confirmation.** Closing the sheet does not undo it. For the rest of the
  sheet's life the row offers "Opozovi", which is another single transaction that
  removes exactly what that confirmation wrote, if it is still unchanged; otherwise
  it does nothing and says so. Later changes go through Correcting a link.
- **Repeating** a confirmation is idempotent: the same link and alias, no duplicates.

## Correcting a link

A linked row offers **Promeni vezu**, which opens the picker with the current food
selected, and **Ukloni vezu**, which makes the row unresolved again and keeps the
original text. Both follow the same commit rules and write `linkSource: confirmed` (or
remove the link). Removing a link does not delete a household alias; a household alias
is removed or changed only when the person uses the same household switch and the
change names it. A link that points to a withdrawn shared food (#56) shows as
unresolved and can be corrected the same way.

## Copy

Exact copy from the spec: "Poveži namirnicu", "Nova namirnica", "Proveri" ("Proveri" is
not used while there is no `Proposed` state). The rest, in Serbian Latin and complete for
this slice, for review by a Serbian-speaking reviewer before Ready:

| Where | Text |
| --- | --- |
| Unresolved marker | Nije povezano |
| Picker title | Izaberi namirnicu |
| Search field | Pretraži namirnice |
| Empty search result | Nema takve namirnice. Možeš da napraviš novu. |
| Confirm button | Poveži |
| Cancel button | Otkaži |
| Household switch | Zapamti i za druge recepte u domaćinstvu |
| Household switch help | Naziv „{naziv}” će se u svim receptima vašeg domaćinstva prepoznavati kao {namirnica}. |
| Food form fields | Naziv; Kategorija; Osnovna jedinica |
| Food form button | Sačuvaj |
| Linked confirmation | Povezano: {namirnica} |
| Undo | Opozovi |
| Change / remove link | Promeni vezu; Ukloni vezu |
| Save failed | Nije uspelo. Pokušaj ponovo. |
| Recipe changed meanwhile | Recept je u međuvremenu izmenjen. Učitaj ga ponovo i pokušaj opet. |
| Reload action | Učitaj ponovo |

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
| U1 | When is anything written, and what is the default scope? | On the confirm tap only, in one transaction with its outbox entries; the default links this ingredient only and a visible switch adds the household alias | Dev 4, Dev 3 |
| U2 | Where do the picker and food form live? | A new `lib/features/foods/` folder | Dev 4 |
| U3 | Is `Proposed` part of matcher v1? | No: unique reviewed matches are `Matched`, conflicts `Unresolved`; `Proposed` waits until AI-assisted proposals exist | Dev 2 |
| U4 | Serbian copy for all remaining text | The table in Copy, reviewed before Ready | Dev 1 |
| U5 | Purchase-time-only entry point | Kept for the first slice; needs UX review against the recipe and pantry journeys | Dev 4 |

## Sequencing

1. #30 accepted, then #56 and the matcher (D1-007) and backfill (D1-008) merged.
2. Copy finalized, then this proposal accepted.
3. One UI PR for T012/T013, test first, from the latest `dev`.
