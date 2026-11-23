# Review-only ingredient candidates

**Status:** Owner-confirmed identity/base-unit review recorded for the 167
candidate foods; legacy rows remain references. This material supports D1-006 /
FR-003 in [spec 018](../spec.md). It does not resolve the spec's separate schema,
alias-scope or licensed-seed provenance decisions.

On 2026-11-23, the project owner confirmed in chat that the candidate identities
and proposed base units had been manually reviewed and approved. The individual
reviewer for each row was not recorded, so the worksheet says so explicitly.
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
and are not new catalog identities or seed rows. USDA mappings with an FDC ID
carry the owner's separate manual mapping approval dated 2026-11-23; individual
reviewers were not recorded. The first eleven columns match `candidates.csv`;
the rest add evidence and review details.

| Column | Meaning |
| --- | --- |
| `origin` | `candidate` or `legacy_reference`; the second also lists `legacy_aliases`. |
| `proposed_base_unit` | `g`, `ml` or `kom`, the same values `candidates.csv` allows; the wire names are still open decision D6. Candidate values were proposed from typical measurement and owner-confirmed. Reference values are historical and do not create identities. |
| `usda_fdc_id`, `usda_description` | A USDA FoodData Central record (usually SR Legacy April 2018), or empty. |
| `usda_basis` | How the record was found: keyword search, historical mapping, or no match. The owner separately confirmed each recorded mapping on 2026-11-23. |
| `usda_alternates` | Other records the search found, for the reviewer to compare. |
| `notes` | Known approximations, for example a cut of meat or a proxy species or product. |
| `base_unit_reviewer` | Owner-confirmed manual review on 2026-11-23; individual reviewer unspecified for candidate rows. Empty for reference rows. |
| `usda_reviewer` | Owner-authorized manual mapping review on 2026-11-23 for each row with an FDC ID; individual reviewer unspecified where not previously recorded. |

Of the 338 worksheet rows, 312 have a reviewed FDC mapping and 26 have none.
Red onion uses a USDA Foundation Foods record and has no value in the SR Legacy-only
nutrition extract. Name matching alone can select the wrong food, a different cut
or a proxy; the owner separately confirmed the recorded mappings on 2026-11-23.
This approval does not convert historical reference rows into active catalog
identities. The offline checker validates every candidate/reference row and keeps
identity/allergen decisions on candidates only; USDA mapping approval may be
recorded for either origin.

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

Identity and base-unit approval for the 167 candidate rows is recorded as an
owner-confirmed decision, with individual reviewers unspecified. USDA mapping
approval is recorded separately. Allergen assessment requires its own evidence;
`unknown` remains unknown until supported. The 171 historical reference rows are
not active identities. Recheck accepted candidate names against the actual current
team catalog and resolve conflicts before a separate migration.
