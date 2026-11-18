# Review-only ingredient candidates

**Status:** Independent research, not an active catalog or completed review.
This material supports D1-006 / FR-003 in [spec 018](../spec.md); it does not
resolve the spec's open decisions or mark any implementation task complete.

The candidate CSV contains 163 generated name/category suggestions. Their
identity, base units, sources and allergen details have not been independently
reviewed. Every row starts `pending`, with allergen status `unknown`. They are
not included in application code, database seeds or migrations.

The adjacent `legacy-food-reference.csv` contains only name, category and
aliases from a separate reference catalog at commit `e181050`. It is a
historical research reference, not the current team catalog, an accepted schema,
verified identity data or an import file. Its names and aliases may themselves
contain errors. It has no IDs, conversion values, nutrition or allergen data.
The accepted team catalog must be checked again when it exists.

`alias-correction-proposals.csv` records disputed historical alias mappings.
Each row names the original canonical food and exact alias plus a reason.
The checker allows the alias to appear as a separate candidate only when the
historical pair exists. A canonical name or an alias still mapped to another
food remains a conflict. The historical CSV stays intact. The T-400 and
T-500 candidates remain pending with unknown allergen status.

## Review worksheet

`catalog-review-worksheet.csv` joins the 163 candidates and the 171 reference
rows (334 foods) with **proposed** evidence for a human reviewer. It is a
reviewer aid: no row is accepted, nothing is imported, and every row keeps
`identity_status = pending` and `allergen_status = unknown`. The first eleven
columns match `candidates.csv`; the rest are added evidence.

| Column | Meaning |
| --- | --- |
| `origin` | `candidate` or `legacy_reference`; the second also lists `legacy_aliases`. |
| `proposed_base_unit` | `g`, `ml` or `kom`, the same values `candidates.csv` allows; the wire names are still open decision D6. For candidates it is a proposal from the typical way the food is measured; for reference rows it is the unit in the historical catalog. Neither is reviewed. |
| `usda_fdc_id`, `usda_description` | A proposed USDA FoodData Central SR Legacy record (April 2018 release), or empty. |
| `usda_basis` | How the record was chosen: a keyword search of record descriptions (proposal), the historical mapping (its id and description match the downloaded release; the food match itself is not reviewed), or no match found. |
| `usda_alternates` | Other records the search found, for the reviewer to compare. |
| `notes` | Known approximations, for example a cut of meat or a proxy species or product. |
| `base_unit_reviewer`, `usda_reviewer` | Empty; filled by an independent human reviewer. |

Current counts: 308 rows have a proposed USDA record and 26 have none (the
foods are not in SR Legacy, such as halloumi, skyr and sumac). The matching only
compares names, so a proposed record can be the wrong food, a different cut or a
proxy. A record is evidence for the reviewer to confirm, not a conversion or
nutrition value to use. USDA terms and the seed provenance still need the team's
acceptance under Q1. The offline checker below validates the worksheet: it must list
every candidate and reference food exactly once, keep each row's origin, category
and USDA fields consistent, and carry no review decision of its own (review
columns repeat `candidates.csv`; a reference row stays unreviewed).

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
The current expected output is 171 reference rows, 163 proposals, 334 worksheet
rows and zero marked reviewed.

**A passing check is not approval.** Exact comparison does not catch every
semantic duplicate, establish that a reference alias is correct, verify a
source or establish reviewer independence. A row's review markers record
claims; they do not prove that a qualified person approved the food or its
allergens. A proposed name is not evidence of the absence of an allergen or
cross-contact.

## Before promotion

For each candidate, a human reviewer must assess identity, semantic overlap,
name, base unit and a documented source. Allergen assessment requires its own
recorded evidence and reviewer; `unknown` must remain unknown until supported.
Reject or keep pending anything ambiguous. Recheck accepted names against the
actual current team catalog and resolve conflicts before a separate migration.
No review status, source or approval has been invented in this research.
