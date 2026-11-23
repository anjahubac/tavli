# Tasks: Simple pantry and reversible consumption

Status: implemented in one slice (2026-11-23), awaiting independent review.
Lead: Dev 4; proposed reviewer: Dev 1. Function list and evidence: spec.md.

- [x] T001 Record decisions (presence = have, optional quantity, no expiry, manual count wins, receipt first, one PR) in spec.md. Owner Dev 4.
- [x] T002 [US1] D4-014 / FR-001: tests for list, count, search, catalog search and add/merge (`test/features/pantry/pantry_screen_test.dart`, `test/data/pantry_repository_test.dart`, `test/data/food_catalog_reader_test.dart`).
- [x] T003 [US1] D4-014 / FR-001: Ostava screen (phone list, wide table) and add sheet.
- [x] T004 [US3] D4-015 / FR-002: tests for swipe/hover remove, "Vrati" and deferred outbox delete.
- [x] T005 [US3] D4-015 / FR-002: remove with undo; `TavliTableRow.onRemove` in tavli_ui.
- [x] T006 [US5] D4-016 / FR-003: tests for receiving into an existing food and for removing a received purchase (`test/data/pantry_repository_test.dart`); existing idempotency coverage in `test/data/shopping_repository_test.dart`.
- [x] T007 [US5] D4-016 / FR-003: one row per food (`pantryEntriesFrom`); removal keeps a received purchase as quantity 0 instead of deleting it.
- [x] T008 [US4] D4-017 / FR-004: tests for the quantity edit sheet, `setEntryQuantity` and `setQuantity` unit change; cooking consumption covered by `test/data/cooking_repository_test.dart`.
- [x] T009 [US4] D4-017 / FR-004: quantity edit sheet on row tap.
- [x] T011 [US6] D4-014 / FR-005: test for "šta imam" with a fake catalog matcher.
- [x] T012 [US6] D4-014 / FR-005: `PantryRepository.whatIHave`, `pantryStockProvider`.
- [ ] T013 Canvas boards for the edit sheet approved by Anja.
- [ ] T010 Independent review, merged PR, Trello cards moved; record check results.

## Sequencing and effort

Do not treat this file's order as permission to run every task concurrently.
Dependencies are contracts plus phase/feature gates in the product plan. Tests
for future behavior land with that behavior; do not weaken current tests to make
it appear implemented. For research/infrastructure tasks use meaningful evidence
checks, not artificial Dart tests. Add task-specific subtasks when a source card
exceeds a 1–2-day reviewable slice. Cross-owner/shared-file changes need coordination.

Each Ready task records: exact files, named reviewer, producer PR, remaining days
(implementation + tests + review/integration), confidence and risk. Estimates are
not invented from ticket counts. Done requires accepted behavior, actual evidence
and merged PR; checkbox completion alone is not a release or an external approval.
