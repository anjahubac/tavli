# Implementation plan: security baseline

**Status**: proposed slices; none implemented by the documentation revision.
**Spec**: [012](spec.md) | **Baseline**: dev 207c94c
**Lead / reviewer**: Dev 3 / Anja and affected owner
Each implementation branch starts from then-current origin/dev and links task IDs.

## Keep existing architecture

Reuse AuthGateway/SessionStore, AccountScope, repositories, SyncedWriter,
AIRouter/ChatClient and Supabase adapters. No additional auth provider or generic
security middleware framework. Add validation at existing trust boundaries;
keep business logic/domain tests fakeable. No dependency is selected by this plan.

## Delivery order

1. Dev 2 fixes safe error handling; Dev 1/4 close photo containment with behavioral
   fixtures. These independent existing-file fixes can proceed before the gateway.
2. Dev 3 establishes local SQL/Edge security checks and same-SHA deployment
   dependency with Anja. Do not enable hosted changes during this planning task.
3. Dev 2 implements the separately contracted AI gateway; 012 verifies its
   authorization/limits and release cutover, avoiding duplicate gateway work.
4. Dev 3/1/4 agree environment/session/cache migration and device protection;
   implement before distributing against multiple environments or storing diary data.
5. Verify auth/deletion and actual hosted settings through authorized operators.
   Household/RAG/voice/cycle gates travel with those future feature PRs.
6. Complete release evidence and tabletop containment/restore exercise.

## File responsibilities

| Existing boundary | Owner / reviewer | Work |
| --- | --- | --- |
| lib/ai/chat_client.dart, ai_errors.dart, ai_router.dart; settings/ai_error_text.dart | Dev 2 / Dev 3 | Safe error and attempt representations |
| lib/data/recipe_photo_store.dart; lib/sync/entities.dart, photo_sync.dart | Dev 1 / Dev 4 | File validation/containment and integration fixtures |
| lib/account/session_store.dart, auth_controller.dart; providers.dart; database.dart | Dev 3 / Dev 1+4 | Scope/migration design, then reviewed slice |
| supabase/tests, functions/delete-account | Dev 3 / Dev 1 | Local authorization/deletion fault tests |
| .github/workflows | Dev 3 / Anja | Local security gate, safe same-SHA deploy dependency |
| Android/iOS/macOS and future Windows settings | Dev 4 / Dev 3 | Release storage, backup, permissions and signing proof |

## Constitution check (3.0.0)

| Gate | Plan response |
| --- | --- |
| I | English docs; Serbian safe errors and auth copy finalized per slice |
| II | Preserve cache/outbox; enforce household/personal/device-only boundaries |
| III | Gateway stays behind AIRouter with one retry policy |
| IV | No real secret inspection; server-only shared provider credentials |
| V | Test-first boundary fixes; local two-account SQL and fake provider tests |
| VI | Security dialogs/errors accessible on phone/wide/text scaling |
| VII | Separate reversible slices, no unrelated refactor |
| VIII | Canonical 012 + owned task branches from dev; producer contracts first |
| IX | Existing folders/interfaces; justified dependencies and migration review |
| X | Named owner and independent reviewer; schema coordination |

## Validation / rollout / recovery

Use [test matrix](contracts/security-test-matrix.md). Default Flutter unit/widget tests remain offline;
SQL/Edge checks use local synthetic accounts. Show failing then passing boundary
cases. Test protection without printing sensitive fixtures. File tests use a
temporary directory only, never actual user files. Deployment checks run without
production credentials in untrusted jobs. Hosted verification needs an authorized
operator; no assumption that checked-in config mirrors a hosted project.

Any encryption or namespace migration needs old-cache/outbox recovery tests and
forward-compatible rollback instructions. Retain existing user data; never use
“delete local database” as the migration. Release controls must survive a failed
provider, failed migration or revoked session without weakening validation.
