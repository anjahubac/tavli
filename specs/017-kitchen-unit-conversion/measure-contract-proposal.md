# Kitchen-measure contract and compatibility proposal

**Status:** Draft for review; not an accepted contract or implemented feature.
**Source:** D1-003 / FR-001 in [017](spec.md), Trello card
[Kuhinjske mere u sabiranju nabavke](https://trello.com/c/HubsZ2ic/100-kuhinjske-mere-u-sabiranju-nabavke).
**Owner:** Dev 1. **Proposed independent reviewer:** Dev 2; Dev 4 reviews
the pantry/shopping boundary.

## Existing behavior and evidence

At team `dev` commit `928d655b32035d752332763840cc5c4b0e281697`,
`normalizeUnit` recognizes `g`, `kg`, `ml`, `l` and pieces. Other units keep
their own groups. Quantities use integer millionths of the base unit;
`demandFor` scales by servings and rounds to an integer number of millionths.
A known amount with an unsupported unit remains a separate group, but the
current `needsReview` signal only marks unknown quantities.

The [synthetic fixture](fixtures/current_gap.dart.txt) can be run manually
from that baseline with Flutter 3.50.0 and existing dependencies:

```sh
cp specs/017-kitchen-unit-conversion/fixtures/current_gap.dart.txt /tmp/tavli-kitchen-measures-test.dart
flutter test --no-pub /tmp/tavli-kitchen-measures-test.dart --reporter expanded
```

Observed: the exact `1 kg + 500 g = 1500 g` control passes. Two desired
acceptance cases fail: `2 kašike + 1 kašičica` produces two separate lines
instead of one 35 ml line, and `1 prstohvat` is not flagged for review. This
fixture is intentionally outside the default suite until the behavior is
implemented; its failure is evidence of missing work, not a green test claim.

The separate `tavli-next` branch already has a versioned measure dictionary
and tests for a 350 ml yogurt sum, exact conversions and old snapshots. On the
local 051 checkout, eleven focused tests in `shopping_demand_v3_test.dart` and
`shopping_demand_v3_sum_test.dart` passed with Flutter 3.47.9. That is useful
reference evidence, not a test of team `dev` or proof of the household override,
unsupported-unit, release or mixed-client requirements in 017.

## Proposed behavior for review

- Default household measures: glass 200 ml, cup 250 ml, tablespoon 15 ml and
  teaspoon 5 ml; the resulting volume is approximate. Dimension conversions
  such as kg to g are exact. The visible `~` must reflect the provenance of
  the resulting open amount, including partial pantry coverage.
- Keep unsupported measures and original ingredient text instead of guessing
  a conversion. Such quantities need a review signal distinct from whether the
  quantity itself is missing. A volume without known ingredient density must
  never be silently converted to a mass or to zero.
- Keep integer micros and define when scaling is rounded. Preserve existing
  approved snapshots and show explicit version/provenance when a new rule
  affects reconciliation. Household-specific measures and conversion precedence
  must be reviewed before their storage or runtime behavior is implemented.
- Treat pantry stock, purchases and their receipts as physical quantities with
  shared capacity. The same amount must not be consumed twice across old/new
  representations or across multiple shopping sources.

These bullets are proposals to review against 017 and C4, not approval to
reinterpret existing plans, derive mass from volume, or change any stored data.

## Acceptance and compatibility cases

| Scenario | Expected behavior for review |
| --- | --- |
| 2 tablespoons + 1 teaspoon of the same ingredient | One approximate 35 ml need under the default measures. |
| 1 kg + 500 g | 1500 g, exact; no `~`. |
| One pinch of salt | Keep the original amount/unit and signal `Proveri količinu`. |
| One cup with unknown density | A known approximate volume is allowed; no invented gram amount. |
| Demand 350 ml; confirmed pantry stock 2 dl | 150 ml remains; a physical stock amount is allocated at most once. |
| Two sources share stock; a receipt represents an earlier purchase | Both sources compete for one physical capacity, including on repeated sync. |
| Previously approved plan and old/new clients share a household | Existing snapshot meaning and pending edits survive; no stale client silently replaces the accepted result. |

The separate local 051 mixed-client experiment observed an older client
overwriting a newer allocation in a synthetic fake backend. A simulated
transient server fence alone did not fix queued replay after an upgrade, and a
recalculation using a stale cache could also overwrite a newer result. These
are local experiment results, not evidence of hosted server behavior. The
actual release mechanism needs its own server/RLS, offline, concurrency,
rollback and device tests.

## Decisions needed before implementation

- Dev 1 and Dev 2: accepted aliases, punctuation/case rules, approximation
  provenance, unknown-unit review and rounding at scaling and display.
- Dev 1, Dev 2 and Dev 4: household override ownership, precedence, data
  model, snapshot behavior and shared pantry capacity across versions.
- Dev 1 and sync/data owners: old-client cutover, pending-outbox handling,
  conflict policy and forward recovery; a generic transient error alone is not
  proof of client-version enforcement.
- Dev 1 and schema coordinator: whether and how approximation/provenance is
  persisted, compatible schema upgrades and old-client behavior before any
  drift version or server migration is allocated.

Record real decision owners, dates, accepted fixtures and producer PR before
dependent implementation. This proposal does not mark T001 or D1-003 done.
