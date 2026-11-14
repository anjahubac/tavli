# Feature specification: four-developer engineering standard

**Branch**: `docs/development-security-standards`, from latest dev.
**Created**: 2026-11-13. **Status**: documentation implemented; review pending.
**Input**: Audit all development Markdown/Spec Kit against the supplied product
revision; standardize four-developer/AI work using actual repository architecture.
All new/revised engineering prose is English; quoted app UI remains Serbian.

## Scope

Produce consistent operating rules, architecture, ownership, contracts, templates,
delivery traceability and document validation. No application code/schema change,
new dependency, hosted settings change, deployment, Trello rewrite or automatic
redistribution of workload. Historic spec acceptance is not rewritten.

## User scenarios

### US1 — Start a safe parallel task (P1)

A developer or agent finds actual paths, one owner/reviewer, a merged producer
contract and acceptance evidence before editing a feature.

Acceptance: given four developers using their existing checkouts, each session
sets explicit feature context;
no shared pointer/branch is assumed. Given two schema tasks, the coordinator
sequences versions/SQL merges rather than allocating the same version twice.
Given unrelated local edits, preserve them when switching branches in place.
If switching would conflict, ask how to handle them; do not automatically stash,
reset or create another worktree. Only one writer uses a checkout at a time.

### US2 — Implement the accepted product (P1)

A developer distinguishes existing 010 code from future Home/catalog/household
work and knows which newer decision replaces a stale future requirement.

Acceptance: the roadmap and architecture report four current tabs/schema v5;
target navigation has central Home and optional-quantity pantry without expiry.
The source's 87 tasks retain phase and assignment without being marked finished.
Cookbook/voice/cycle/import questions remain explicit gates.

### US3 — Review AI work and integrate (P1)

A reviewer can trace a card to spec, contracts, diff and real validation results.

Acceptance: templates require scope, owner, data/privacy impact and evidence;
test-first domain/parser and two-account RLS cannot become optional through a
generic skill. Unrun checks/platforms and external setup are reported honestly.
Normal PRs target dev; release/hotfix follow actual existing workflows.

## Requirements

- FR-001: One English entry point links architecture, accepted product plan,
  owners, AI workflow, UI standard, quality gates and Spec Kit index.
- FR-002: Architecture MUST cite baseline commits and distinguish current paths,
  data/sync/AI behaviors from planned transports/features.
- FR-003: Preserve current Flutter/Riverpod/drift/Supabase boundaries and
  feature-level provider placement; do not introduce a new structure by prose.
- FR-004: Record current Dev 1–4/person assignments, shared-file coordinators,
  required reviewers, handoff process and remaining-effort planning.
- FR-005: Require contract-first parallel work, schema sequencing and explicit
  per-session Spec Kit context and branch switching in existing checkouts; reserve feature numbers centrally through PRs.
- FR-006: Resolve conflicting target navigation/pantry/gateway decisions with
  an explicit 010 overlay, retaining completed history.
- FR-007: Inventory all 87 source tasks and six phases; identify future feature
  preparation/decision gates and unavailable linked proposals.
- FR-008: Update constitution/agent entry points and templates together; mandatory
  tests/security/offline gates override generic optional-test examples.
- FR-009: Add a local/CI check for active documentation links and task-register
  integrity. Report historical unresolved links separately.
- FR-010: State actual CI/release capabilities and external setup limitations;
  do not claim rulesets/platform tests were enabled merely by documentation.

## Success criteria

- SC-001: All 87 imported rows map once to an English task, phase and current role;
  expected counts are Dev 1=20, Dev 2=21, Dev 3=20, Dev 4=26.
- SC-002: Every new local Markdown link resolves; document checks and diff checks
  pass; generated inventory accounts for all tracked Markdown files at baseline.
- SC-003: Agent/PR/spec/plan/task templates point at the same source hierarchy,
  architecture and review/test requirements.
- SC-004: Diff contains no app/schema/data/secret-file changes; protected user's
  original unstaged edits are intact. Review status remains explicit.

## Assumptions and unresolved external setup

The attached plan is owner direction, not proof of implementation or external
service limits. Dev is integration, main production. Verified GitHub identities
for all four people, branch-protection availability and linked Claude proposal
details remain team setup. No runtime UI copy is introduced by this feature.

## Scope addition — security request, 2026-11-13

The owner requested explicit protection and a dedicated spec. Add the source-level
security assessment, reference guidance and draft 012 requirements/plan/tasks/test
matrix; integrate those gates into agent/PR/Spec Kit rules. Runtime remediation,
hosted configuration and security certification remain outside this revision.

## Scope addition — full specification set, 2026-11-14

The owner requested all necessary specs, including testing and release operations,
to be committed together. Prepare 008/009 and 013–033, preserve all original source
roles/phases, and map every source ticket to an existing requirement/test/implementation
task. Document independent decisions instead of pretending every feature is Ready.
Validation now covers all active specs, source mappings and dependency cycles.
