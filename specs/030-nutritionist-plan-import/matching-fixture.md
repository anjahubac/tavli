# Catalog matching fixture (D1-020 / Trello #32)

Synthetic, already extracted plan items and the expected result of the existing
`AliasFoodMatcher`. Executable form: `test/domain/imported_plan_item_matching_test.dart`.
The import model from the D2-020 slice does not exist yet, so the test uses a
local record; replace it when that model lands.

Synthetic catalog: one shared food, `crni luk` (`food-crni-luk`), no aliases.

| Original text | Recognition name | Quantity | Unit | Expected link | Review flag |
|---|---|---|---|---|---|
| 150 g crnog luka | crni luk | 150 | g | `food-crni-luk` | none |
| 80 g domaće mešavine | domaća mešavina | 80 | g | none (`Unresolved`) | "Proveri" |

Original text, quantity and unit must stay unchanged after linking. The matcher
takes only a name string and returns a result, so it cannot alter them; the
test does not assert this because a local record would only compare constants
with themselves. Assert it on the real import model in D2-020.

## Checked against the matcher

- An already normalized recognition name equal to the catalog name returns
  `Matched` with the catalog ID.
- The raw original line ("150 g crnog luka") returns `Unresolved`, so a
  recognition-name step is required before matching.
- No match returns `Unresolved`; the item keeps no ID. The test checks only a
  boolean "needs review" derived from that, not the "Proveri" label.

## Left for integration (D2-020, #52)

- Producing the recognition name from the original line (e.g. "crnog luka" to
  "crni luk"); the matcher compares names after trim, lowercase and whitespace collapsing
  only. Inflected forms and diacritics are not folded ("domaća" differs from
  "domaca").
- Persisting the imported item and its nullable food ID.
- Showing the "Proveri" flag in the review screen and its accessibility checks.
- Offline, cancel and retry behavior of the review flow.
