# Feature specification: security baseline and release protection

**ID**: 012-security-baseline | **Created**: 2026-11-13
**Status**: Draft for implementation; security documentation prepared only
**Baseline**: dev 207c94c | **Lead**: Dev 3 (Matija)
**Review**: Anja + affected domain owner; never author-only approval
**Source**: owner's request to protect Tavli and add a dedicated specification

## Scope

Close verified trust-boundary gaps in the existing architecture and make security
checks part of delivery. This spec coordinates security slices; it does not
replace the product gateway/household specs, create a new service architecture,
or authorize production probing, key rotation, deployment or a database wipe.
The 87 source product tasks are unchanged; 012 is additional cross-cutting work.
See [security assessment](../../docs/development/security.md) for evidence SEC-01–08.

## User scenarios and acceptance

### US1 — My household and personal data stay private (P1)

Given two unrelated households, a signed-in user cannot read or mutate the
other household's rows, object paths or referenced parent records by editing
request IDs. Personal records remain owner-only even within one household.
Revoked membership cannot upload queued old-household writes after reconnect.

### US2 — Login and AI cannot expose credentials or abuse quota (P1)

Expired/replayed OTP and invalid tokens are rejected. Invalid/over-limit gateway
requests cause zero provider calls. A release after gateway cutover contains
no built-in provider secrets. Provider replies containing synthetic secrets or
personal text do not appear in UI, logs or error serialization.

### US3 — Synced content cannot escape its data boundary (P1)

A malicious photo path cannot read/write/delete outside the allowed root, from
recipe metadata or a version snapshot. Invalid input yields a safe error;
legitimate photos, offline retry and deletion still work. A new account or
backend environment cannot recover another environment's session/cache.

### US4 — The team can prove and maintain protection (P1)

A failing access/function test blocks deployment of that commit. A release has
named review and evidence, and operators can contain/recover without exposing
credentials or deleting unreviewed data. Documentation alone never marks a
security control implemented.

## Requirements

- **FR-001**: Preserve server-enforced least-privilege grants/RLS and private storage;
  cover forged ownership, RPCs, parent references and personal/household isolation.
- **FR-002**: Complete the planned authenticated gateway cutover for built-in AI
  secrets with bounded cost/size/concurrency and no arbitrary provider destinations.
- **FR-003**: Replace raw provider/error propagation with safe typed categories in
  UI/diagnostics; verify synthetic-sensitive fixture redaction end to end.
- **FR-004**: Validate photo paths and containment for all filesystem operations,
  including sync/snapshot input; bound file decoding and processing.
- **FR-005**: Verify OTP expiry/replay/throttling, exact redirect allowlists,
  confirmation and session recovery separately for local/dev/prod. Define a
  recent-auth requirement for destructive account/ownership operations.
- **FR-006**: Isolate session/cache/secret scope by environment and account where
  personal; preserve sign-out retention and unsynced data through migration.
- **FR-007**: Review platform storage/backup and choose documented protection before
  sensitive diary data ships; cycle raw data stays secure/device-only.
- **FR-008**: Test account deletion identity, idempotent retries and partial failures;
  validate household leave/remove/transfer and outbox behavior before 008 ships.
- **FR-009**: Block hosted backend deployment until same-SHA local SQL/function
  security checks and independent review pass; verify real GitHub settings.
- **FR-010**: Add stack-appropriate secret/dependency checks, least-privilege CI,
  reviewed supply-chain pins and release-signing/restore evidence.
- **FR-011**: Keep future RAG, voice and import authorization/input boundaries in
  their feature contracts; untrusted content never executes arbitrary actions.
- **FR-012**: Maintain risk ownership, containment/recovery runbook and explicit
  residual-risk decisions; do not equate code presence with proven protection.

## UI and product constraints

No extra prompts for routine cooking/shopping. New security flow copy is Serbian
Latin and must be finalized in its slice before implementation. Candidate safe
error: “Zahtev nije uspeo. Pokušaj ponovo.” Do not expose provider bodies.
Device cache retention and normal offline operation remain product requirements.
No runtime UI strings change in the documentation delivery.

## Success criteria

- **SC-001**: Matrix tests include allowed and denied cases, pass on local synthetic
  accounts, and include membership/account/environment transitions.
- **SC-002**: Traversal inputs perform no filesystem operation outside the test root;
  synthetic secrets never reach errors/UI/log sinks.
- **SC-003**: Post-cutover release has no compiled built-in AI secrets; rejected
  gateway cases invoke no provider work, including concurrent limit attempts.
- **SC-004**: A deliberately failing security check prevents same-SHA deployment;
  reviewer and release evidence are recorded without credentials.
- **SC-005**: Every High finding is fixed and tested before affected release, or a
  release is deferred. Lower residual risks need explicit owner/reviewer decisions.

## Decisions before dependent implementation

Agree environment/cache migration, OS-only versus DB encryption, recent-auth UX,
gateway budgets/rotation, retained-file policy and actual hosted controls. They
block only dependent slices. New dependencies and schema changes require plan
updates and applicable migrations/tests, not blanket permission from this spec.
