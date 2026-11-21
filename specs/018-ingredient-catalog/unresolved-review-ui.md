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

The sheet's present rule is that it saves nothing until "Dodaj u nabavku" (the doc
comment on `showIngredientReview` and the test "pregled ne čuva ništa" say so). This
proposal changes that rule for one thing only: confirming a link writes it at once,
whether or not anything is added to shopping. Quantities, the home-stock marks and the
shopping addition keep the old rule, and the existing test needs a case that separates
the two.

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
  shopping addition. The AI preview (`ai_preview.dart`) opens the sheet without a
  `recipeId`, before the recipe is saved: if the person saves it afterwards, the draft
  recipe must carry `foodId`, `matchedKey` and `linkSource` of the links made in the
  sheet, or they are lost. How the draft carries them is an implementation decision
  for T013 and needs a test.
- **Nova namirnica.** A small form with the name prefilled from the ingredient, a
  category and a base unit. It creates a household food and links the ingredient to it,
  with the same scope switch for the alias. It never writes to the shared catalog.
- **Several rows in one visit.** Confirming or cancelling closes only the picker or the
  food form, never the sheet. The person returns to the same sheet with its scroll
  position, quantities and home-stock marks unchanged, the confirmed row already shown
  as linked, and focus on that row. They can then open the next unresolved row
  directly. Each row is still its own transaction, so a failure on one row does not
  undo the others.
- **Same-key refresh.** When a confirmation also saved a household alias (or created
  a household food, whose canonical name matches like a confirmed household alias,
  #30), the sheet runs the matcher again for the other rows with the same
  `ingredientKey`, but only for **eligible** rows: rows without a valid `confirmed`
  link and without a valid `unlinkedKey` marker. A valid confirmed link to another
  food and a removed link stay exactly as they are. The refresh changes only what
  the row displays and writes nothing. Each refreshed row shows the actual matcher
  result: linked to the food when it is now `Matched`, or still "Nije povezano" when
  it is `Unresolved` (for example, the canonical name of another household food or a
  second household mapping conflicts with the new alias). A refreshed row that shows a
  match is stored as a `matched` link only by the backfill (D1-008), or by the person
  confirming it.
- **Household data from an AI draft.** In the AI preview the link itself lives only in
  the draft (see above). A household food created with "Nova namirnica", or a household
  alias saved with the switch on, is written to the household at the confirm tap like
  anywhere else. It is household data with its own stated effect and does not depend on
  the draft. If the draft is discarded, the link is lost with it, but that food and
  alias stay and keep working in other recipes. The confirmation line says so: the food
  form and the switch help name the household as the place it is saved. To remove them,
  the person uses Correcting a link in another recipe or, later, food management.
  Nothing is written for a draft that the person only viewed. The disclosure is part
  of the visible copy before the tap (see Copy: food form household note, alias
  switch help), and it is shown whether or not the alias switch is on.
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
- **Newer recipe edits win.** The sheet keeps an **expected state**: the recipe's
  `updatedAt` and, per ingredient, its name, link and `unlinkedKey`. It starts as what
  the sheet read when it opened; for that, `showIngredientReview` has to receive the
  recipe's `updatedAt` together with `recipeId`, so its signature changes. Every write
  (confirm, change, remove, undo) compares the stored recipe with the expected state.
  If the recipe was changed by anything else, nothing is written, the row stays as it
  was and the person sees "Recept je u međuvremenu izmenjen" with a way to reload the
  sheet. A link is never written over a newer edit.
- **The expected state advances after each successful write.** The transaction
  returns the committed `updatedAt` and ingredient state, and they become the sheet's
  next expected state. This happens without resetting scroll position, quantities or
  home-stock marks. The sheet's own writes are therefore never mistaken for an
  external edit, so a second row in the same saved recipe, or the same row again, can
  be confirmed in the same visit.
- **After confirmation.** Closing the sheet does not undo it. For the rest of the
  sheet's life the row offers "Poništi" (see Undo). Later changes go through
  Correcting a link.

### Undo

Each confirming operation records the **before-state** it replaced, and "Poništi"
restores exactly that in one transaction, with its outbox entries:

| Operation | Before-state kept | "Poništi" restores |
| --- | --- | --- |
| New link (row was unresolved) | No link, plus any previous `unlinkedKey` | Removes the link and puts back the previous `unlinkedKey`, if there was one |
| **Promeni vezu** (A → B) | The previous link to A (`foodId`, `matchedKey`, `linkSource`) | The link to A |
| **Ukloni vezu** | The removed link | That link, and clears `unlinkedKey` |
| Manual relink of a removed link | The `unlinkedKey` it cleared | The `unlinkedKey` marker, and removes the new link |
| Household alias written with the switch | The household aliases of that key that the replacement deleted (#56 replacement protocol) | Those aliases, inserted again (new rows, same food and wording), then the replacement deleted, in the same insert-then-delete order |
| Household food created with "Nova namirnica" | Nothing (the food is new) | Deletes that food (and, through the cascade, its aliases), if nothing else links to it yet |

Guards: undo runs only if the recipe and the rows it touches still equal the state
the operation left. The sheet's expected state is checked, and the alias and food
rows the operation wrote must be unchanged. If anything changed meanwhile, undo
writes nothing and says "Nije uspelo. Pokušaj ponovo." with the row unchanged.
Household foods and aliases that existed before the operation are never in its
deletion set. Undo only ever deletes rows that the operation itself inserted. A
household food that another recipe has linked to in the meantime is kept, and undo
removes only the link.
- **Repeating** a confirmation is idempotent: the same link and alias, no duplicates.

## Correcting a link

A linked row offers **Promeni vezu**, which opens the picker with the current food
selected, and **Ukloni vezu**, which makes the row unresolved again and keeps the
original text. Both follow the same commit rules and write `linkSource: confirmed` (or
remove the link).

**A removed link must not come back by itself.** Without a marker, the next matcher
run or backfill would match the same name again and re-link it, because the shared or
household alias that matched it is still there. Removing a link therefore stores
`unlinkedKey` (= `ingredientKey(name)` at removal) on the ingredient instead of the
link. While `unlinkedKey` equals the current `ingredientKey(name)`:
- the matcher result is not applied to this ingredient, and the row shows "Nije
  povezano";
- backfill (D1-008) skips it, like a `confirmed` link;
- the person can still link it again by hand with **Poveži namirnicu**, which clears
  `unlinkedKey`.

Editing the name makes the marker stale by itself, the same rule as `matchedKey`, so
the new wording is matched normally. The marker affects only this ingredient in this
recipe. Stopping a wording from matching in the whole household is the household
alias's job, not this marker's. `unlinkedKey` is an additive field on the embedded
ingredient. It needs the same mixed-version gate as the link fields in #30 (an older
build drops it on save) and an amendment to the #30 contract before T013 (U6). Removing a link does not delete a household alias; a household alias
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
| Household switch help | Naziv „{naziv}” će se u svim receptima tvog domaćinstva prepoznavati kao {namirnica}. |
| Food form fields | Naziv; Kategorija; Osnovna jedinica |
| Food form household note (always shown above "Sačuvaj", switch on or off) | Namirnica se čuva u tvom domaćinstvu i ostaje i ako ne sačuvaš ovaj recept. Svaki sastojak sa nazivom „{naziv}” u receptima domaćinstva prepoznavaće se kao ova namirnica. |
| Alias switch help, AI draft (replaces the switch help in the AI preview) | Naziv „{naziv}” će se u svim receptima tvog domaćinstva prepoznavati kao {namirnica}. To ostaje i ako ne sačuvaš ovaj recept. |
| Food form button | Sačuvaj |
| Linked confirmation | Povezano: {namirnica} |
| Undo | Poništi (the word the shopping messages already use) |
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

Widget tests with fakes: both row states (linked, unresolved); choosing a food links
the ingredient and writes an alias only with the household switch on; cancel writes
nothing; confirming writes the link even if nothing is added to shopping; the link,
the optional alias and their outbox entries are saved together or not at all; a recipe
edited after the sheet opened is not overwritten; "Poništi" removes exactly what the
confirmation wrote; a link made in the AI preview survives saving the recipe;
a household food or alias created in the AI preview stays after the draft is
discarded, while the draft's link does not; after "Ukloni vezu" a matcher run and a
backfill do not re-link the ingredient, and editing its name lets it match again;
confirming one row returns to the same sheet with the others unchanged;
confirming two different rows of one saved recipe in one visit succeeds (the expected
revision advances), while an external edit between the two confirmations is still
rejected; the same-key refresh after a household alias leaves a row with a valid
`confirmed` link to another food unchanged, leaves a row with a valid `unlinkedKey`
unlinked, and shows "Nije povezano" for a row whose matcher result is `Unresolved`
because of a conflict; undo after "Promeni vezu" restores the link to the previous
food; undo after a household alias replacement restores the previous household alias
and removes the replacement; undo after a manual relink restores the previous
`unlinkedKey`; undo never deletes a household food or alias that existed before the
operation, and does nothing after an intervening edit; in the AI preview, creating a
food with the alias switch off shows the household note before "Sačuvaj", and the
food stays after the draft is discarded;
repeating the choice creates no duplicate; offline choice is queued; a renamed ingredient stops being linked; no overflow
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
| U6 | How a removed link stays removed | `unlinkedKey` on the ingredient, valid while it equals `ingredientKey(name)`; an additive amendment to the #30 contract with the same mixed-version gate | Dev 4, Dev 2 |
| U7 | Household food or alias made from an AI draft that is later discarded | It stays: it is household data saved at the confirm tap, and only the draft's link is lost. The effect is stated in the visible copy before the tap (food form household note, also with the alias switch off; AI-draft switch help), including that the food's canonical name matches in other recipes | Dev 4, Dev 3 |

## Sequencing

1. #30 accepted, then #56 and the matcher (D1-007) and backfill (D1-008) merged.
2. Copy finalized, then this proposal accepted.
3. One UI PR for T012/T013, test first, from the latest `dev`.
