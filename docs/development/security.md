# Tavli security baseline and threat model

Reviewed 2026-11-13 against `dev` `207c94c`. This is a source-level assessment
and an implementation standard, **not a penetration-test or compliance result**.
Implementation is tracked in [012](../../specs/012-security-baseline/spec.md).
No real keys, accounts, hosted configuration or production requests were inspected.

## Trust boundaries and assets

Treat the installed app, incoming sync records, AI responses, documents, invite
codes and deep links as untrusted inputs. A modified client can call Supabase
without going through Flutter validation. Server authorization must therefore
protect every table, object and privileged operation independently.

| Asset / boundary | Protection required | Owner |
| --- | --- | --- |
| Account/session/email OTP | Secure storage, verified identity, expiry/replay handling, rate limits | Dev 3 |
| Household recipes/plans/pantry/shopping/photos | Membership RLS, ownership-preserving references, private object paths | Dev 1 + Dev 3 |
| Personal preferences/favorites/diary/targets | Owner-only rows; narrowly authorized planning aggregate | Dev 3 |
| AI provider quota/credentials | Built-in keys on server; BYOK secure on device; bounded authenticated requests | Dev 2 |
| Local cache/photos/outbox | Account/environment separation, safe filesystem paths, backup/retention policy | Dev 1 + Dev 4 |
| Cycle data | Opt-in secure device-only storage; no raw sync/export/log/AI | Dev 3 + Dev 4 |
| Release/deployment credentials | Restricted CI permissions/environments, reviewed changes and protected release | Dev 3 + Anja |

Attacker scenarios include unauthenticated abuse, a signed-in user guessing
another household's IDs, a malicious household member uploading crafted data,
a lost/shared device, stolen session, malicious AI/document content, and a
compromised dependency or CI contribution. OS sandboxing and encryption help
with device loss; they do not make a compromised/rooted device trustworthy.

## Existing controls and verified gaps

Evidence means the named source contains the control/gap; runtime effectiveness
still needs the tests in 012. Priorities describe remediation order, not a CVSS
score or proof of exploitation. No credential exposure incident is asserted.

| ID | Source evidence | Assessment / next step | Priority |
| --- | --- | --- | --- |
| SEC-01 | `lib/ai/key_store.dart`: BuiltInKeys.fromEnvironment | Shared provider values can be compiled into distributed clients. `.gitignore` is not binary protection. Complete the authenticated gateway and cut over builds before wider distribution. No real build values were read. | High |
| SEC-02 | `lib/data/recipe_photo_store.dart`: _resolve; `lib/sync/entities.dart`: photoLocalPath; `lib/sync/photo_sync.dart` | Relative names from synced records/snapshots reach filesystem operations without a containment check in this boundary. Add allowlisted leaf names and normalized root containment for read/write/delete, including traversal/symlink cases. Exploit impact has not been dynamically tested. | High |
| SEC-03 | `lib/ai/chat_client.dart`: mapDioError; `lib/ai/ai_router.dart`; `lib/features/settings/ai_error_text.dart` | Provider body snippets enter error/attempt strings; BadRequest and fallback UI interpolate raw messages/errors. Replace with stable safe categories and regression fixtures containing synthetic sensitive values. | High |
| SEC-04 | `lib/account/session_store.dart`: auth_session; `lib/ai/key_store.dart`: api_keys; `lib/data/database.dart`: driftDatabase(name: 'tavli') | Environment-independent storage names and no configured application-level DB encryption here. Validate project/account isolation, OS backup/file protection and retention before adding sensitive diary data. Do not erase retained caches at ordinary sign-out. | Medium; gate for sensitive data |
| SEC-05 | `supabase/config.toml`: local OTP length 6/expiry 600, confirmation and rate limits | Local settings exist; hosted OTP, redirects, SMTP limits, recovery and abuse controls are unverified. Verify each environment without exposing values. A resend button timer is not a security limit. | Pre-release verification |
| SEC-06 | `supabase/migrations/*rls*`, private helpers, storage migration; `supabase/tests/` | RLS, explicit grants, hardened helper search paths and two-account tests exist. Private photo bucket limits JPEG to 5 MiB. Preserve and expand tests for forged ownership, parent IDs, RPC execute, tombstones and membership transitions. | Existing foundation + regression gate |
| SEC-07 | `supabase/functions/delete-account/index.ts` | POST, server getUser(token), server-derived uid, generic failures and server-only admin access exist. Add local function-level auth/fault/retry tests and decide recent-auth UX for deletion. Future membership introduces deletion/transfer races to test. | Before expanded household release |
| SEC-08 | `.github/workflows/check.yml`, `deploy-supabase.yml` | Flutter CI exists; deploy job currently has no dependency on local SQL/function security validation. Actions use version tags, function SDK uses a major range. Add explicit same-SHA security/deploy gates, reviewed dependency pins and scanning. Hosted rulesets are unverified. | High for backend releases |

## Authentication and authorization rules

- Server identity comes from a validated token, never a body-supplied user ID.
  A publishable/legacy anon project key identifies the app; it is not a user's
  authority. Secret/service-role credentials bypass RLS and remain server-only.
  This distinction does not relax the repository rule against reading real config.
  See [Supabase API keys](https://supabase.com/docs/guides/getting-started/api-keys).
- Use least-privilege grants plus RLS on exposed tables. Cover SELECT, INSERT,
  UPDATE (USING and WITH CHECK), DELETE, foreign references, views and RPC EXECUTE.
  SECURITY DEFINER functions use fixed search_path and reviewed caller/argument
  validation. Client-provided household_id never establishes membership.
  See [Supabase API security](https://supabase.com/docs/guides/api/securing-your-api).
- Keep storage private. Check both source and destination on overwrite/move;
  use short-lived access where signed links are needed and avoid leaking paths.
- OTP: validate exact redirect allowlists, expire/reject reused codes, bound send
  and verify attempts server-side, and use neutral failure text. Verify native
  callback handling and session binding; future browser/social login must specify
  the appropriate PKCE/state flow rather than copying the current implicit setup.
- Define recent-auth protection for account deletion and future owner transfer.
  Do not add repeated prompts to normal shopping/cooking. Team/admin accounts
  should use MFA and least privilege; consumer MFA is a separate UX decision.
- Household invite codes need secure randomness, expiry/revocation, server-side
  attempt throttling, atomic claim and explicit join confirmation. A short code
  alone is insufficient protection against enumeration. Cache/outbox access after
  removal must stop at the next verified membership change; an offline device
  cannot be promised instantaneous remote erasure.

## AI gateway and untrusted inputs

The existing AIRouter boundary stays. The gateway must authenticate the caller,
allow only reviewed tasks/models/provider destinations, impose per-user request,
concurrency, image/document size and token/cost budgets, and apply bounded retries.
Reject unauthenticated, invalid-token, oversized and over-limit calls **before**
provider work. Do not trust claimed user IDs, arbitrary URLs or arbitrary system
prompts from the client. Define an operator kill switch and abuse/cost alerts.
BYOK travels only to the selected allowlisted provider, never a generic proxy
chosen by generated content. Use TLS verification; no accept-all certificates.

Validate task schema and domain meaning; AI content cannot execute tools, SQL,
shell commands or arbitrary URLs. Images/books/imports are data, not instructions.
RAG retrieval must apply household/book authorization before retrieval/ranking,
with deletion of embeddings/chunks when the original is deleted. Voice mutates
only a validated draft. Preview/approval and original-text preservation remain.

Bound files by bytes, decoded pixels/pages, processing time and format; validate
content rather than trusting extensions/MIME declarations. Strip unneeded image
metadata during re-encoding. Canonicalize file paths, reject separators/traversal
and keep all file operations under the approved root. Imported nutritionist
originals are not retained; temporary server/provider retention must be explicit.

## Device data and privacy

Review Android/iOS/macOS storage/backup defaults on actual release builds; do not
claim secure storage encrypts unrelated SQLite/photo files. Decide OS protection
versus an encrypted DB based on the threat model, compatibility and recovery.
Any DB-encryption dependency needs its own approved plan, key management and
migration tests. No custom cryptography. Before private diary/cycle rollout,
verify backup, account/environment switch, deletion, restore and screen exposure.

Separate dev/prod session and cache namespaces with a safe migration; scope
personal secrets explicitly. Ordinary sign-out retains data as the product
requires but prevents UI access by another account. A future “remove from device”
action must be distinct and confirmed. Do not silently wipe unsynced work.

Use sanitized event categories and aggregate metrics. Never log bodies, tokens,
codes, emails, recipe/health content or identifying record IDs. Error strings,
crash tools, notifications, clipboard and support exports need the same review.
Collect only data required for the feature; record purpose, retention and deletion
in its spec. No claim of regulatory compliance follows from this document.

## CI, release and incident readiness

Before backend deployment, require same-commit local SQL and function tests as
well as review. A separate workflow that merely runs near deployment is not a
dependency. Keep fork/untrusted PR jobs away from secrets; avoid executing PR
code with privileged pull_request_target. Pin reviewed external actions/SDKs,
use lockfiles and document a dependency-update cadence. Add secret scanning
with redacted output and dependency checks that cover the actual Dart and Deno
stacks. Tool choice/hosting availability must be verified before claiming coverage.

Release proof includes signed artifacts, intended environment, platform privacy
permissions, auth/deep-link tests and redacted evidence of no built-in provider
secrets after gateway cutover. Obfuscation is optional hardening, not a secret
store or replacement for authorization. Certificate pinning or device attestation
needs an explicit threat/rotation/recovery decision; not default complexity.

If compromise is suspected: Anja coordinates; Dev 3 handles identity/backend and
CI, Dev 2 disables gateway/provider abuse, Dev 1 checks data integrity, Dev 4
checks client releases. Preserve minimal redacted evidence, contain access,
rotate/revoke through authorized operators, assess affected data, communicate
verified facts and add regression tests. Never paste keys into issues or run
production repairs as an agent without explicit authorization. Practice restore
on synthetic/local data and verify the actual hosted backup/restore capability.
No invented recovery-time promise.

## Verification reference

Use [OWASP MASVS](https://mas.owasp.org/MASVS/) control groups for storage,
authentication, network, platform, code and privacy as a review framework, with
backend controls tested separately. No certification claim. The concrete
[test matrix](../../specs/012-security-baseline/contracts/security-test-matrix.md)
connects Tavli risks to requirements, owners and evidence. References were
consulted on 2026-11-13; verify APIs before implementation.
