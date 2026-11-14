# Specification: Private cookbook library and grounded retrieval

**ID**: 026-cookbook-library | **Feature key**: COOKBOOKS
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 2 | **Proposed independent reviewer**: Dev 3

## Scope and source

Implements the COOKBOOKS portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Upload cookbook files**. Source D2-015; Dev 2; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Process cookbook files for retrieval**. Source D2-016; Dev 2; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-003**: Deliver **Answer cookbook questions with book/page provenance**. Source D2-017; Dev 2; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-004**: Deliver **Save a cookbook result through recipe review**. Source D2-018; Dev 2; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Upload approved PDF/EPUB formats with size/page/processing budgets; show processing progress, retry/cancel and unsupported-file errors.
- **FR-102**: RAG is part of the first accepted cookbook slice, not generic AI answering without retrieval; filter authorization before retrieval/ranking.
- **FR-103**: Answer with book/page provenance; save as recipe only through the shared validated preview/matcher path.
- **FR-104**: Treat book content as untrusted instructions, limit quoting/output under reviewed source rights and keep keys/embedding services behind the approved transport.

## User scenarios and acceptance

- **US1 / SC-001**: A member asks about an authorized book and gets attributable context; another household cannot retrieve its chunks.
- **US2 / SC-002**: After a book is deleted, retrieval stops and derived files/chunks are cleaned up; failed jobs can resume without duplication.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Private household storage, authorized book/chunk retrieval and resumable jobs. Source book/page provenance is preserved; deleting a book removes derivatives and access.

## Exact UI copy carried forward

“Kuvari”, “Dodaj kuvar”, “Obrada je u toku”, “Sačuvaj kao recept”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [015](../015-ai-server-gateway/spec.md), [018](../018-ingredient-catalog/spec.md)

- **Q1** (Dev 2 with reviewer): Initial text PDF/EPUB versus scanned OCR, source rights, embeddings/quotas, retry/resume policy and provider retention must be accepted.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
