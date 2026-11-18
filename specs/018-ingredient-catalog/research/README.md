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

## Offline checks

From the repository root:

```sh
python3 scripts/check_catalog_candidates.py
python3 -m unittest scripts.test_check_catalog_candidates
```

The checker detects invalid rows, missing evidence in rows marked reviewed,
unrecognized allergen codes and normalized exact duplicate names against this
historical reference or another candidate. A rejected candidate may remain as
history if it has a reason. The scripts CI job runs the checker against all three CSV files via the test suite.
The current expected output is 171 reference rows,
163 proposals and zero marked reviewed.

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
