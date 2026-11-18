# Store-price source and basket research

**Status:** Independent research, not approved source selection or an
implemented import. Source tasks: D1-017 and D1-018 / FR-001–002 in
[spec 024](spec.md). No store data, user basket or price history is added to
this repository.

## Public source observations

On 2026-11-15, the public open-data portal listed retail CSV resources for
[Delhaize](https://data.gov.rs/sr/datasets/cenovnici-proizvoda-prema-pravilniku-o-uslovima-sadrzaju-i-nacinu-objavljivanja-cenovnika-delhaize-serbia-doo-beograd/)
and [Europrom](https://data.gov.rs/sr/datasets/cenovnici-proizvoda-prema-pravilniku-o-uslovima-sadrzaju-i-nacinu-objavljivanja-cenovnika-europrom-doo/).
Both dataset descriptions state the Serbian Open Data License, require source
and retrieval-date attribution, and distinguish historical monthly snapshots
from the latest valid price lists. The descriptions also state that their
consolidated lists may show the highest applicable price where stores differ.
That is not a guaranteed price at a particular location.

The portal metadata describes semicolon-separated UTF-8 CSV and product,
barcode, unit, price and price-list-type fields. Metadata and resource URLs
can change; these observations are not evidence that every live file was
downloaded, complete, current or compatible on 2026-11-15. Source terms,
update schedules, coverage and acceptable processing limits still require
review before selection or integration.

Earlier research in a separate reference checkout reported that the two
CSV endpoints returned data on 2026-11-13. Its sampled files contained both
historical and current-list rows. It also reported product names containing
package sizes that were not safely inferable from the observed unit-price
fields. These are historical sample observations, not claims about the current
contents of every retailer file.

## Synthetic comparison evidence

The [fixture](fixtures/basket_comparison_test.dart.txt) is a copy of three
existing tests for a separate reference comparison implementation based
on `e181050`. It requires that checkout's `basket_comparison.dart` and package
configuration; team `dev` at `928d655b` does not yet contain that module. With
Flutter 3.47.9 and cached dependencies, the following passed on 2026-11-15:

```sh
# Copy the fixture from the team checkout to /tmp/tavli-price-test.dart.
# Run from the separate checkout that contains the comparison module.
flutter test --no-pub /tmp/tavli-price-test.dart --reporter expanded
```

The synthetic tests cover full packages, missing or conflicting offers and
sharing a single pack across repeated lines. One hand-checkable example is
1,500 ml of milk in 1,000 ml packs at 120 RSD plus six eggs in a ten-pack at
250 RSD: `2 × 120 + 1 × 250 = 490 RSD`. A store with only the milk price has
a partial 200 RSD subtotal and an uncovered egg item; it is not a complete
basket comparison. Another test confirms two 400 ml needs share one 1,000 ml
pack. All prices, products and source URLs in the fixture are fictional.

Seven earlier comparison and catalog tests also passed in the separate
checkout with Flutter 3.47.9. Neither result tests the current team app, a
server-owned importer, current retailer feeds or real price freshness. The
fixture does not cover the full 024 three-priced-plus-one-unknown acceptance
case, historical import idempotency, retries or live-data validity.

## Proposed price acceptance cases

Record each observation with retailer, explicit retailer or store scope, source
and observation time. Display scope and age together with the comparison. Use
store-specific prices only for their matching store. Label any retailer-wide
fallback and preserve its age so it cannot appear to be a fresh store quote.

| Scenario | Expected result |
| --- | --- |
| A needed item has no comparable price | Show coverage and label the subtotal partial. Exclude it from cheapest complete basket ranking. |
| The same demand is offered in different pack sizes | Compare the cost of enough whole packs for the requested amount and show the purchased quantities. |
| Import the same source observation twice | Reuse the existing observation and keep the same basket totals. |
| Refresh fails | Retain the last successful observation and its original time. Display that the refresh failed. |
| A store price and a retailer-wide price both exist | Retain both scopes and prefer the matching store observation for that store. |

These are acceptance cases for the eventual importer and comparison against the
team catalog. They are not results from the existing synthetic fixture.

## Decisions and checks still required

- Review allowed sources, license obligations, retailer coverage, ingestion
  frequency, source versions, store/location semantics and data retention.
- Specify package-size and barcode-to-food confirmation. Missing, ambiguous,
  expired or contradictory observations must remain visible as uncovered;
  a product's display name alone is not proof of a pack size or food identity.
- Keep household basket data private. Define bounded parsing, timeouts,
  redirects, source failures and stale-result disclosure before networking.
- Test a three-priced-plus-one-unknown basket, same-source reimport without
  duplicate history, different package sizes, conflicting same-date offers,
  failed refresh and date boundaries. Recheck actual files and source terms
  under the accepted review process before integration.

No implementation, source approval or D1-017/D1-018 completion is claimed.
