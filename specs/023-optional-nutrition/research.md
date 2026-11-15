# Nutrition reference and portion-calculation research

**Status:** Independent research, not an approved source mapping or shipped
feature. Dev 1 evidence for D1-011, D1-015 and D1-016 / FR-001–003 in
[spec 023](spec.md). No nutrition data, diary record or application code is
added by this report.

## Reference-source observations

The [USDA FoodData Central API guide](https://fdc.nal.usda.gov/api-guide/)
states that FoodData Central data is public domain and published under CC0 1.0;
it requests source attribution. Its [download page](https://fdc.nal.usda.gov/download-datasets/)
identifies SR Legacy as the April 2018 release. The [SR Legacy description](https://fdc.nal.usda.gov/food-search/?query=Fish%2C+mackerel&type=SR+Legacy)
states that this historical data type is not updated. This documents a source
and version, not whether a particular USDA food is an accurate substitute for
a local product.

The official [ANSES Ciqual 2025 documentation](https://ciqual.anses.fr/cms/sites/default/files/inline-files/Table%20Ciqual%202025%20doc%20FR_2025_11_19.pdf)
describes reuse under an Open Licence and conditions including preserving
meaning and identifying source and version. No Ciqual data was imported here;
the relevant team reviewer must assess source terms and version before any use.
No claim is made that either source provides personalized dietary advice.

## Existing separate-checkout evidence

The separate `tavli-next` `main` at `e181050` contains a USDA SR Legacy
mapping, portion calculation and ingredient-unit conversions. A later,
unmerged `fix/review-findings` branch at `78c0ae1` documents five questionable
mappings (coffee, tea, coconut, breadcrumbs and puff pastry) being removed
from that separate candidate dataset, leaving 161 of 171 mapped there. That
branch is not team `dev`, has not been merged into the separate `main`, and
is not an accepted team seed. These counts do not describe an active team
catalog or prove correctness of the remaining mappings.

On 2026-11-15, 25 synthetic nutrition calculation, CSV-validation and unit
weight tests passed in a separate checkout based on `e181050`, using Flutter
3.47.9. The [portion-calculation fixture](fixtures/recipe_nutrition_test.dart.txt)
contains nine of those tests and can be rerun from that checkout, whose
nutrition modules and package configuration must already exist:

```sh
cp /path/to/team-checkout/specs/023-optional-nutrition/fixtures/recipe_nutrition_test.dart.txt /tmp/tavli-nutrition-test.dart
flutter test --no-pub /tmp/tavli-nutrition-test.dart --reporter expanded
```

All fixture values are synthetic. Two manually checkable examples are:

- 200 g at 77 kcal per 100 g, divided into two portions: `77 kcal/portion`.
- 200 g at 77 kcal per 100 g plus two 50 g pieces at 143 kcal per 100 g,
  divided into two portions: `(154 + 143) / 2 = 148.5 kcal/portion`.

The fixture also checks that missing data is excluded and counted as incomplete,
not treated as zero. It does not establish that actual food matches, densities,
brands, sources or individual results are accurate. Its modules do not exist
on team `dev` at baseline `928d655b`.

Three targeted tests for meals without preparation steps passed in the same
separate checkout: the recipe screen, shopping entry and cooking screen. Those
tests do not by themselves establish the complete team flow from saving a
step-free meal through shopping and per-portion nutrition.

## Remaining review and integration

- Review each candidate food identity, source version, portion mass/density
  and preparation state. Do not import ambiguous mappings or invent values;
  absent values remain unknown. Reassess the separate branch's corrections
  rather than copying either historical seed blindly.
- Agree how consumers represent coverage, approximate conversions and missing
  data. Team acceptance includes a seven-of-eight ingredient case; the copied
  fixture is evidence of the earlier implementation, not that team case.
- Keep attributed reference values separate from private member diaries and
  targets. Tracking is off by default according to [spec 023](spec.md); this
  research does not implement tracking, consent, storage or access control.
- After relevant decisions and catalog/unit dependencies are accepted, test
  the team calculation, step-free meal flow, account isolation and migration
  on the actual team implementation. No clinical accuracy or personalized
  target calculation is established by synthetic unit tests.

No source approval, team review or task completion is asserted by this report.
