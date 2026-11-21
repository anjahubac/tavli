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

In both cases original text, quantity and unit are unchanged after linking.

## Checked against the matcher

- Exact catalog-name match returns `Matched` with the catalog ID.
- No exact name or alias returns `Unresolved`; the item keeps no ID.
- Matching never alters the extracted fields.

## Left for integration (D2-020, #52)

- Producing the recognition name from the original line (e.g. "crnog luka" to
  "crni luk"); the matcher is exact-name only, so inflected forms are not matched.
- Persisting the imported item and its nullable food ID.
- Showing the "Proveri" flag in the review screen and its accessibility checks.
- Offline, cancel and retry behavior of the review flow.
