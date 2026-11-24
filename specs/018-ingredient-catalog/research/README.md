# Review-only ingredient candidates

**Status:** Owner-confirmed identity/base-unit review recorded for the 167
candidate foods; legacy rows remain references. This material supports D1-006 /
FR-003 in [spec 018](../spec.md). It does not resolve the spec's separate schema,
alias-scope or licensed-seed provenance decisions.

On 2026-11-24, Uroš Milutinović confirmed in chat that he personally reviewed
and approved the 167 candidate identities and proposed base units, as well as
the candidate USDA mappings. The worksheet records him as the reviewer.
Allergen review remains separate: only rows with their own evidence retain a
reviewed allergen status; all other rows remain `unknown`. The svinjski but USDA
record is an approximation for a whole leg with separable lean and fat, including
bone and skin; see its row-level note.

The adjacent `legacy-food-reference.csv` lists 171 food names with their
category and aliases, collected before the team catalog work began. It is a
historical research reference, not the current team catalog, an accepted schema,
verified identity data or an import file. Its names and aliases may themselves
contain errors. It has no IDs, conversion values, nutrition or allergen data.
The accepted team catalog must be checked again when it exists.

`alias-correction-proposals.csv` records disputed historical alias mappings.
Each row names the original canonical food and exact alias plus a reason.
The checker allows the alias to appear as a separate candidate only when the
historical pair exists. A canonical name or an alias still mapped to another
food remains a conflict. The historical CSV stays intact. The T-400 and T-500 candidates remain distinct identities; their allergen status
remains unknown.

## Review worksheet

`catalog-review-worksheet.csv` joins the 167 candidates and the 171 historical
reference rows (338 rows total). The 167 candidate rows carry the owner-confirmed
identity/base-unit decision. The 171 reference rows remain comparison material
and are not new catalog identities or seed rows. The owner confirmed manual
review of all 338 USDA mapping decisions on 2026-11-23. The subsequent named
review covers the candidate rows. Of the 338 rows, 312 have an approved FDC ID
and 26 have no suitable match. The first eleven columns match
`candidates.csv`; the rest add evidence and review details.

| Column | Meaning |
| --- | --- |
| `origin` | `candidate` or `legacy_reference`; the second also lists `legacy_aliases`. |
| `proposed_base_unit` | `g`, `ml` or `kom`, the same values `candidates.csv` allows; the wire names are still open decision D6. Candidate values were proposed from typical measurement and owner-confirmed. Reference values are historical and do not create identities. |
| `usda_fdc_id`, `usda_description` | A USDA FoodData Central record (usually SR Legacy April 2018), or empty. |
| `usda_basis` | How the record was found: keyword search, historical mapping, or no match. The owner separately confirmed each recorded mapping on 2026-11-23. |
| `usda_alternates` | Other records the search found, for the reviewer to compare. |
| `notes` | Known approximations, for example a cut of meat or a proxy species or product. |
| `base_unit_reviewer` | Uroš Milutinović for candidate rows. Empty for reference rows. |
| `usda_reviewer` | Uroš Milutinović for candidates with an FDC ID. Historical rows retain their original review record. A blank FDC ID means no match was selected. |

Of the 338 worksheet rows, all mapping outcomes were reviewed: 312 have an
approved FDC mapping and 26 have no suitable match. No nutrition value is
assigned to the unmatched rows.
Red onion uses a USDA Foundation Foods record and has no value in the SR Legacy-only
nutrition extract. Name matching alone can select the wrong food, a different cut
or a proxy; the owner separately confirmed the recorded mappings on 2026-11-23.
This approval does not convert historical reference rows into active catalog
identities. The offline checker validates every candidate/reference row and keeps
identity/allergen decisions on candidates only; USDA mapping approval may be
recorded for either origin.

## Approved reference foods

`legacy-food-approvals.csv` lists the 171 historical reference foods that
Uroš Milutinović approved on 2026-11-24, when he confirmed in chat that he had
reviewed all catalog data, including each reference food's identity, base unit
and aliases. The worksheet keeps these rows as `legacy_reference` without
decisions; the approval file is the only source of the decision.
`scripts/build_food_catalog_seed.py --legacy-approvals` builds an additive seed
for them with the same deterministic IDs, nutrition only for complete
owner-approved USDA records, and their historical aliases except the disputed
pairs in `alias-correction-proposals.csv`.

`legacy-allergen-proposals.csv` holds manual Annex II proposals for the same
171 foods and is their allergen review record. Uroš Milutinović approved the
137 rows marked `auto` (plain single ingredients or products with a fixed
Annex II group) on 2026-11-24; `scripts/food_allergens.py seed-legacy` writes
only decided rows. The 34 `needs_review` rows depend on the product (for
example sausage, bread or ketchup) and stay `unknown`.

## Offline checks

From the repository root:

```sh
python3 scripts/check_catalog_candidates.py
python3 -m unittest scripts.test_check_catalog_candidates
```

The checker detects invalid rows, missing evidence in rows marked reviewed,
unrecognized allergen codes and normalized exact duplicate names against this
historical reference or another candidate. A rejected candidate may remain as
history if it has a reason. It also checks the worksheet against its sources. The
scripts CI job runs the checker against all four CSV files via the test suite.
Expected counts are 171 reference rows, 167 candidates, 338 worksheet rows,
167 candidate identity/base-unit approvals and 312 owner-approved FDC mappings.
The separate allergen-reviewed count remains four.

The checker records and cross-checks the owner's approval statement; it does
not establish reviewer independence or prove allergen safety. A proposed name
is not evidence of the absence of an allergen or cross-contact.

## Before promotion

Uroš Milutinović is the recorded identity, base-unit and USDA mapping reviewer
for the candidate rows. Allergen assessment requires its own evidence;
`unknown` remains unknown until supported. The 171 historical reference rows are
not active identities. Recheck accepted candidate names against the actual current
team catalog and resolve conflicts before a separate migration.

## Allergen proposals (EU Annex II)

`allergen-proposals.csv` is generated by `python3 scripts/food_allergens.py propose`
from a rule table over Regulation (EU) No 1169/2011 Annex II. It is a proposal,
not a review: every food stays `unknown` until a named reviewer fills the
`decision` column (`approved`, or `codes:a|b` / `codes:none` for their own
codes) and runs `apply --reviewer NAME`. `needs_review` rows cannot be bulk
approved. After review, `seed` writes the UPDATE migration for reviewed rows
only. No external dataset is used: USDA SR Legacy has no allergen data, and the
Open Food Facts taxonomy lists only positive allergens, not reviewed absence.
