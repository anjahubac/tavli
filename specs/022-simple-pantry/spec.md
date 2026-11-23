# Specification: Simple pantry and reversible consumption

**ID**: 022-simple-pantry | **Feature key**: PANTRY
**Created**: 2026-11-14 | **Revised**: 2026-11-23 | **Baseline**: dev 5d181e4
**Status**: Implemented in one PR (Ostava tab, add/edit/remove, receiving
purchases, "šta imam" query, adding from a photo of food); acceptance pending
independent review and merge.
**Lead**: Dev 4 | **Proposed independent reviewer**: Dev 1

## Scope and source

Implements the PANTRY portion of the [accepted product plan](../../docs/product-plan.md)
and collects every pantry function from the plan and the Trello cards in one
place. UI follows the design canvas (sections "Ostava" and "Predlog: Ostava,
dodavanje namirnice"); where the canvas and older text differ, the canvas wins.
Preserve inherited 010 quantity, snapshot, offline and account invariants.

At baseline the pantry repository, purchase receipt (Nabavka → "Prebaci u
ostavu") and cooking consumption already existed; the Ostava tab was a
placeholder. This revision adds the Ostava screen and the functions below.

## Pantry functions (one list)

| # | Function | Source | Status in this slice |
|---|---|---|---|
| P1 | Ostava list: name + optional quantity, count, search | D4-014, canvas | New |
| P2 | Add a food: catalog search, or a new name; optional quantity and unit | D4-014, canvas proposal | New |
| P3 | Edit quantity: tap a row, minus/plus, direct input, unit | D4-017, pantry rules | New |
| P4 | Remove with undo: swipe "Ukloni" on phone, hover/focus trash on desktop, "Vrati" | D4-015 | New |
| P5 | One row per food: same name and unit show once, with the summed quantity (also after "Prebaci u ostavu") | D4-016 | New |
| P6 | Receive checked purchases via "Prebaci u ostavu", once | D4-016 | Existing (#83); removal no longer re-opens a received purchase |
| P7 | Cooking consumes known quantities once, floors at 0, undo restores once; a manual count wins | D4-017, 021 contract | Existing, unchanged |
| P8 | "Šta imam" query for shopping (Dev 1) and recipe suggestions (Dev 2) | D4-014 | New |
| P9 | Manual entry (teammate suggestion) | Team 2026-11-23 | Covered by P2 |
| P10 | Add from a photo of food: one item, a shelf or an open fridge, reviewed before saving | Team suggestion, Anja 2026-11-23 | New |
| P11 | Add from a shop receipt photo | Team suggestion | Dropped by Anja 2026-11-23 |

## Requirements and source traceability

- **FR-001**: Deliver **List and add pantry ingredients** (P1, P2, P5). Source D4-014; Dev 4; phase 3.
- **FR-002**: Deliver **Remove pantry ingredients with undo** (P4). Source D4-015; Dev 4; phase 3.
- **FR-003**: Deliver **Receive checked purchases into the pantry** (P5, P6). Source D4-016; Dev 4; phase 3.
- **FR-004**: Deliver **Consume and edit pantry quantities with reversal** (P3, P7). Source D4-017; Dev 4; phase 3.
- **FR-005**: Deliver the **"šta imam" query** (P8). Source D4-014; Dev 4; consumers Dev 1 and Dev 2.
- **FR-006**: Deliver **add from a photo of food** (P10). Source: team suggestion, Anja 2026-11-23; Dev 4.

## Behavioral requirements

- **FR-101**: Presence means available. Rows show the name and, when known, the
  quantity; no "imam" badge, expiry field or use-first subsystem.
- **FR-102**: The list is flat and sorted by name (canvas; this supersedes the
  earlier category grouping). Search filters by name; the count shows all items
  ("1 namirnica", "3 namirnice", "7 namirnica"). Phone: one card list, floating
  "Dodaj namirnicu". Wide (≥ 720): page header with search and "Dodaj namirnicu",
  table Namirnica · Količina.
- **FR-103**: Adding searches the food catalog (name and aliases, withdrawn
  foods hidden) and offers "Dodaj „…“ kao novu namirnicu". The second step asks
  for an optional quantity (minus/plus, input) and unit (kom, g, kg, ml, l).
  Adding a name already in the pantry (case-insensitive) with the same unit adds
  the quantity; with another unit it creates a separate row; without a quantity
  it keeps the existing row.
- **FR-104**: Tapping a row opens the same quantity form; saving sets the count
  of the whole food (a manual count supersedes earlier cooking consumption).
  Clearing the quantity keeps the item as present without quantity.
- **FR-109**: Rows with the same name (case-insensitive) and unit display as one
  food with the summed available quantity; a row without quantity joins a food
  of the same name that has one. Receiving a purchase of a food already in the
  pantry therefore increases the shown quantity, while each received purchase
  keeps its own row for idempotent receipt. A manual count writes the first row
  and removes the others.
- **FR-105**: Remove hides the row at once and shows "Uklonjeno: …" with
  "Vrati". The delete is written only when the message closes without "Vrati",
  because a server deletion tombstone blocks re-inserting the same id. A
  received purchase row is not deleted: its quantity becomes 0 and it is
  hidden, so the purchase stays received and cannot be moved in twice. Phone:
  swipe left reveals "Ukloni". Wide: a trash button ("Ukloni iz ostave") appears
  on hover or keyboard focus; screen readers get a custom "Ukloni" action.
- **FR-106**: Checked purchases move only via explicit "Prebaci u ostavu", once;
  a purchase and its pantry receipt are a single supply credit.
- **FR-107**: Cooking consumes known quantities once without negative stock;
  undo restores once. Unknown quantity persists until the person removes it.
- **FR-110**: `PantryRepository.whatIHave(FoodMatcher)` (provider
  `pantryStockProvider`) returns every displayed food with name, available
  quantity and unit, and the catalog food id when the name matches a catalog
  food or alias. Unmatched foods keep `foodId == null`. Without a downloaded
  catalog every food stays by name.

- **FR-111**: "Slikaj namirnice" in the add sheet opens "Namirnice sa slike"
  (phone: Slikaj / Izaberi iz galerije; desktop picks a file first). The
  downscaled photo goes through `AIRouter` with task `pantry_from_photo`
  (vision). The answer is validated (`photoItemsFromAiResponse`): at most 60
  items, names trimmed and non-empty, quantity only for countable pieces
  (> 0) or null, unit canonical or dropped, unknown category → "ostalo"; no
  valid item → repair request; `{"error":"no_food"}` → "Na slici nisu
  prepoznate namirnice.". Recognition is a suggestion: the person reviews the
  list (check/uncheck, edit quantity) and confirms "Dodaj u ostavu (N)"; the
  chosen items are added in one transaction with the merge rules of FR-103.
  The photo is not stored or logged.

## User scenarios and acceptance

- **US1 / SC-001**: Press transfer twice or replay after offline restart: stock/coverage does not double.
- **US2 / SC-002**: Cook/undo/undo for a recipe restores original known stock exactly once; unknown-presence items remain present.
- **US3 / SC-003**: Remove a food by swipe (phone) and by the hover/focus trash
  (wide); "Vrati" restores it; without "Vrati" the row is deleted and an outbox
  delete is written.
- **US4 / SC-004**: At 2× text on a 320 px phone, open a quantity edit and reach
  the input and "Sačuvaj"; a row without quantity shows only its name.
- **US5 / SC-005**: With milk already in the pantry, receive a milk purchase:
  one "Mleko" row shows the sum. Remove it: it disappears, the purchase stays
  received and "Prebaci u ostavu" does not offer it again.
- **US6 / SC-006**: "Šta imam" returns each food once with its quantity and the
  catalog id for catalog names.

- **US7 / SC-007**: With a fake AI answer, a photo yields a list; unchecking
  one item adds only the rest. Cancel, "Odbaci" and a no-food answer add
  nothing.

Evidence: `test/features/pantry/`, `test/data/pantry_repository_test.dart`,
`test/data/food_catalog_reader_test.dart`, `test/ai/pantry_ai_test.dart`,
`packages/tavli_ui/test/content_test.dart`; existing P6/P7 coverage in
`test/data/shopping_repository_test.dart` and `test/data/cooking_repository_test.dart`.

## Data, AI and privacy

No schema change. Rows use the existing `pantry_items` columns (name,
optional quantity/unit, category, `quantitySetAt`, `sourceShoppingItemId`,
household scope) through `PantryRepository` and the outbox. Pantry rows do not
store a catalog food id; "šta imam" resolves it by name through the catalog
matcher. Storing the id on the row is a later reviewed migration if matching
by name proves insufficient.

The food photo is personal content (it may show a home interior): it is sent
only to the configured AI route for that request, never stored or logged. AI
output is untrusted and validated before display; nothing is saved without the
person's confirmation. The gateway allowlist gets `pantry_from_photo` as a
vision task (`supabase/functions/ai-gateway/input.ts`, contract in spec 015);
Anja owns the AI part of this feature.

## Exact UI copy

"Ostava", "Pretraži ostavu", "Dodaj namirnicu", "N namirnica/namirnice",
"Još nema unetih namirnica", "Ovde ćeš pratiti namirnice koje imaš kod kuće.",
"Ostava nije učitana.", "Nema namirnica za „…“.", "Namirnica", "Količina",
"Ukloni", "Ukloni iz ostave", "Uklonjeno: …", "Vrati", "Već u ostavi",
"Dodaj „…“ kao novu namirnicu", "Količina (nije obavezna)", "Jedinica", "Manje",
"Više", "Sačuvaj", "Dodaj u ostavu", "Upisana količina je novo stanje u
ostavi.", "Namirnice iz kataloga; ono čega nema dodaješ kao novu.",
"Potraži namirnicu", "Prebaci u ostavu", "Slikaj namirnice", "Jedna namirnica
ili ceo frižider", "Izaberi sliku namirnica ili frižidera", "Namirnice sa
slike", "Slikaj jednu namirnicu, policu ili otvoren frižider. Slika se ne čuva,
samo se prepoznaju namirnice.", "Slikaj", "Izaberi iz galerije", "Prepoznajem
namirnice…", "Ovo je prepoznato na slici. Proveri nazive, štikliraj ono što
želiš u ostavi i, ako hoćeš, upiši količinu.", "Odbaci", "Dodaj u ostavu (N)",
"Dodato u ostavu: N", "Na slici nisu prepoznate namirnice.", "Pokušaj
ponovo", "Izaberi drugu sliku", "Prepoznavanje je prekinuto.".

"Vrati" replaces the earlier "Poništi" for removal, matching shopping-list
removal.

## Decisions

- 2026-11-13 (Anja): presence = have, no "imam"; quantity optional; removable;
  no expiry. Cooking decreases quantity automatically and the person can
  decrease it manually any time.
- 2026-11-19 (Dev 4): zero-stock and adjustment-versus-undo follow the
  [cooked meal contract](../021-home-and-cooking/contracts/cooked-meal-contract.md):
  displayed stock floors at 0, a manual count wins over earlier cooking, undo
  restores only consumption not superseded by a later count.
- 2026-11-23 (Anja): add flow drawn on the canvas first; all pantry functions
  from her Trello cards ship in one PR; receipt photos are dropped; adding
  from a photo of food (one item or a fridge) is added to the same PR; its
  canvas boards were approved.

## Open items

- Canvas boards for the edit sheet await approval (photo flow approved 2026-11-23); add/edit open as a bottom
  sheet on desktop too (canvas draws a dialog), pending Anja's choice.
- The shopping screen keeps received purchases visible with "U ostavi"; hiding
  them is shopping-list UI (Dev 1 area) and is not changed here.

Producer specs: [018](../018-ingredient-catalog/spec.md), [020](../020-catalog-shopping/spec.md), [021](../021-home-and-cooking/spec.md)
