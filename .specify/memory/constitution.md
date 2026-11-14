<!--
Sync Impact Report — 2026-11-14
- Version: 3.0.0 → 3.0.1 (PATCH: clarify existing-checkout branch workflow).
- Previous revision: 2.1.0 → 3.0.0 (MAJOR: narrow the all-data-sync rule with explicit
  device-only privacy exceptions; allow independently owned feature slices).
- Added principle X: four-developer collaboration and shared contracts.
- Clarified current client AI transport versus the planned server gateway.
- Updated AGENTS.md, CLAUDE.md, architecture/product/development docs,
  Spec Kit templates, PR template and local Spec Kit skill policy.
- Historical completed specs retain their original acceptance evidence.
- Security assessment/spec 012 adds explicit boundary and release-test requirements.
- Spec 013 distinguishes network-free default tests from guarded local integration;
  all roadmap specs and release/operations 033 are prepared with open gates.
- No runtime, schema, credential, hosted settings or deployment change here.
-->

# Tavli Constitution

Tavli is a Flutter app (Android, iOS, macOS) for recipes, meal planning,
pantry and shopping lists, with AI help that runs on free provider tiers. Using
the app requires an account; the user's data is stored on the server under that
account and cached on the device for offline use.

## Core Principles

### I. Serbian UI (NON-NEGOTIABLE)

All user-facing text — labels, buttons, messages, errors, empty states, AI output
shown to the user — MUST be in Serbian, Latin script (ćčđšž, never Cyrillic).
AI prompts MUST instruct the model to answer in Serbian (Latin). Code identifiers
are English; code comments may be Serbian (the existing codebase uses Serbian
comments) or English. New and revised engineering docs, specs and agent guidance MUST be in English; every
spec MUST state the Serbian (Latin) copy for any new UI text it introduces.

**Rationale**: the app is built for a Serbian-speaking household; mixed-language
UI is a defect, not a style choice.

### II. Offline-First, Account-Backed Data

An account is REQUIRED to use the app: nothing except the intro and the sign-in
flow is reachable without a signed-in session. Synced business data (recipes, versions,
photos, pantry, shopping lists, meal plans, ratings, preferences, profile) is
stored durably on the server (Supabase, EU region) under the account — household
data under the household, personal data under the person. The local drift
(SQLite) database is the offline cache the UI reads from: every change is
written locally and to an outbox in one transaction, and the outbox is uploaded
when online; on sign-in the account's data is downloaded. Existing cached operations MUST remain usable offline. A new capability that
requires a remote service (for example invitations or future book processing)
MUST document its offline state, retry and recovery behavior in its spec.
Sign-out MUST NOT delete data; data is deleted only when the user deletes it or
deletes the account. Records use client-generated ids so retries never duplicate.

Explicit device-only exceptions are credentials/session secrets in secure
storage and device settings/cooldowns according to their existing stores. The
planned cycle feature MUST keep raw consent/dates in secure device storage;
it MUST NOT add those fields to drift sync, Supabase or AI requests. New
exceptions require an explicit privacy decision, retention/deletion behavior
and tests. Personal diary/targets, when implemented, remain private to their
owner; household membership alone MUST NOT expose them.

Server rules: every table in an exposed schema MUST have Row Level Security
enabled with policies limiting access to the owning person or to members of the
owning household; new tables are NOT exposed automatically
(`auto_expose_new_tables = false`) — access for `authenticated` is granted
explicitly per table, and `anon` gets no table access. Storage buckets are
private with the same rules. Schema changes go through migrations in
`supabase/migrations/`; drift schema changes MUST bump `schemaVersion` and ship
a migration.

**Rationale**: the user's data must survive a lost device and follow the user to
any device, while free AI tiers and connectivity stay unreliable — so the app
works offline and the server is the durable copy, protected per row.

### III. AI Only Through AIRouter

Every AI call MUST go through `AIRouter` (`lib/ai/ai_router.dart`) — via
`RecipeAI` or a similar feature-level façade — never by calling a provider or
`ChatClient` directly from UI or domain code. The router owns the vision/text
fallback chains, per-model cooldowns (persisted in drift), invalid-key and
missing-model handling, and the one-retry-on-bad-JSON rule. No feature may take
a hard dependency on a single provider or model; model names live only in
`ChainConfig`. Every AI response MUST be a JSON object parsed by a function that
throws `FormatException` on schema mismatch. AI failures MUST degrade gracefully
with a Serbian message (see `aiErrorText`), never a crash.

Current code uses the client router and compatible HTTP transport. The planned
gateway moves built-in provider credentials to a server function; BYOK stays in
device secure storage. Preserve the router/facade boundary, bounded retries,
structured schema/semantic validation and fakeable transport in that migration.
Do not describe the gateway as deployed until code and operational evidence exist.

**Rationale**: free tiers hit rate limits constantly and model names change; resilience is the product.

### IV. Secrets Never Committed

API keys and backend credentials MUST NEVER appear in the repository, logs, test
fixtures, screenshots, or commit messages. User AI keys are stored in the
platform secure store (Keychain on iOS/macOS, Keystore on Android) via
`KeyStore`; the auth session (access/refresh tokens) is stored only in the same
secure store. Current build-time values (built-in AI keys, Supabase URL and anon key)
come from a gitignored `secrets.json` passed with `--dart-define-from-file`;
`secrets.example.json` holds empty values only. The Supabase service-role key
MUST NEVER be in the app or the repository. Tests use `InMemoryKeyStore` and
fake backends with obviously fake values.

Build-time injection does not make a distributed client a safe store for a
shared provider secret. The accepted gateway migration moves built-in provider
keys server-side; never add new shared provider keys to client features.

Security requirements in `docs/development/security.md` apply at trust boundaries:
validate synced file paths, sanitize diagnostics, authenticate/limit endpoints
and prove server authorization independently of client checks. Record negative
tests and release evidence using spec 012; new rules do not imply existing gaps
are already fixed.

**Rationale**: the repo may become public; a leaked key burns a free quota or
exposes other people's data.

### V. Test-First for Domain and AI Parsing

Domain logic (`lib/domain/`), AI parsing (`fromAiJson`, prompt/JSON handling),
router behaviour and error mapping MUST be developed test-first: write the
failing test, then the code. AI is always faked in tests (fake `ChatClient` or
the `fake_adapter` Dio adapter). Default Flutter unit/widget tests fake the
backend and MUST NOT hit the network. Only an explicitly invoked integration
lane may contact a verified ephemeral local Supabase endpoint with synthetic
accounts, fake AI and a fail-closed endpoint guard (spec 013); never hosted
projects, real keys or production data. Server access rules (RLS policies, grants,
storage policies) MUST have database tests run against the local Supabase stack
(`supabase test db`) with at least two test accounts. Widgets get widget tests
for key flows. `flutter analyze` MUST be clean and the tests affected by the
change (`scripts/test-changed.sh`, run by the pre-commit hook) MUST be green
before every commit; the full `flutter test` suite MUST be green in CI before
a pull request is merged.

**Rationale**: AI output is messy; parsers and fallback logic are where bugs hide.

### VI. Responsive by Default

Every screen MUST work on a phone and on a wide window (macOS, tablet). The
shell uses bottom navigation tabs below 720 px width and a `NavigationRail`
at 720 px and above (extended at ≥1000 px). New screens MUST NOT assume a
fixed width and SHOULD be checked at both sizes.

### VII. Small, Reviewable Commits

Each commit does one thing, builds, passes analyze and tests, and has a clear
message. Generated code (`*.g.dart`) is committed together with the source
change that caused it. No drive-by refactors mixed into feature commits.

### VIII. One Feature = One Spec; Independently Owned Branches

Each feature has one canonical Spec Kit directory in `specs/NNN-short-name/`
and follows specify → clarify → plan → tasks → analyze → implement. Scope
changes update the spec first. A feature may be delivered as small, sequential
or independent slices: each branch has one owner, one topic and one PR, links
the same spec and distinct task IDs, and starts from current `origin/dev`.
Dependent consumers wait for producer contracts to merge, rather than stacking
branches. Reserve spec numbers centrally and set explicit Spec Kit feature context
per session. Switch branches in the existing repository directory; do not create
additional worktrees, clones or branch-specific folders unless the user explicitly
requests them. Each developer uses their existing checkout with one active writer
at a time. Preserve unrelated local edits; if they block a branch switch, stop
and ask how to handle them instead of automatically stashing or resetting them.

### IX. Flutter Best Practices & Agent Guardrails

Code MUST follow `docs/flutter-best-practices.md` (architecture layers, Riverpod
rules, async safety, error handling, accessibility, drift migrations, security,
testing). The strict lint set in `analysis_options.yaml` MUST NOT be loosened
without amending this constitution. AI agents MUST follow the guardrails in
`AGENTS.md`: no secrets, no skipped/disabled tests, no hand-edited generated
code, no unjustified dependencies, no schema change without migration and test,
changes scoped to the active spec, and confirmation before destructive git
operations.

**Rationale**: AI agents write most of the code; guardrails keep quality from drifting.

### X. Shared Contracts and Independent Review

Every Ready task names one implementer, a different human reviewer, spec/task
IDs, dependencies, changed paths and acceptance/test evidence. Cross-owner
interfaces (food identity/units, planning/member inputs, shopping/pantry,
cooked/undo, AI schemas and privacy) require a producer/consumer contract
before implementation. Coordinate schema versions and shared-file merges under
`docs/development/team-workflow.md`; do not split the existing app into new
layers/packages merely to match team roles. AI review supplements human review.
Done means accepted behavior, applicable checks and a merged PR, not generated
code or ticket count. Track remaining effort and integration risk per phase.

## Platform & Technology Constraints

- Flutter/Dart versions are defined in `pubspec.yaml` and the lockfile; Material 3.
  Existing targets: Android, iOS, macOS. Windows is planned and needs platform
  scaffolding, plugin/security validation and CI before it is supported.
- State: Riverpod (`flutter_riverpod`); routing: `go_router` with a
  `StatefulShellRoute`; local cache: drift; HTTP: dio; keys and session:
  `flutter_secure_storage`.
- Backend: Supabase (Auth with email one-time code, Postgres with RLS, Storage),
  hosted project in the EU region. Local development uses the Supabase CLI stack
  started with `supabase start` in this repo (`supabase/config.toml`, ports
  5532x so it does not clash with other local Supabase projects); schema lives in
  `supabase/migrations/`, email templates in `supabase/templates/`.
- AI providers: Gemini, Groq, OpenRouter — free tiers only — through one
  OpenAI-compatible `/chat/completions` client.
- New dependencies require a one-line justification in the feature's `plan.md`.

## Development Workflow

1. Every normal work branch MUST be created from the latest `dev`
   (`git fetch origin && git switch -c <branch> origin/dev`), named
   `NNN-feature-name` (Spec Kit numbering) or `<type>/…` (`feat`, `fix`,
   `chore`, `docs`, …), and its pull request MUST target `dev`. `main` is
   production: it only receives the release pull request from `dev` (merge
   commit) or a `hotfix/…` branch. Branches MUST NOT be stacked on other
   unmerged branches; nothing is committed directly to `dev` or `main` — every
   change lands through a pull request. Hosted Supabase projects (`tavli-dev`,
   production) change only through `.github/workflows/deploy-supabase.yml`. Git
   conventions (commit messages, rebasing, force-push rules) are in
   `docs/flutter-best-practices.md` §17.
2. `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks`
   → `/speckit-analyze` → `/speckit-implement`.
3. Before each commit: `dart run build_runner build` (if drift tables changed),
   `dart format lib test`, then the pre-commit hook (`.githooks/pre-commit`:
   `scripts/check.sh` format check + analyze, `scripts/test-changed.sh`
   affected tests). CI runs the full test suite on every pull request.
4. Apply `docs/development/quality-gates.md`: runtime features need acceptance,
   Serbian UI, relevant offline/security/UI checks and a macOS debug smoke build.
   Documentation-only changes need document/link/register and diff checks;
   do not claim unrun app tests. CI's full Flutter gate still applies to the PR.
5. New/revised contracts must separate implemented behavior from targets and
   unresolved decisions. Preserve completed specs as history; add a dated overlay
   when future direction changes rather than rewriting old acceptance evidence.

## Governance

This constitution overrides other conventions in the repo. `AGENTS.md` is the
operational guide and MUST stay consistent with it. Amendments are made by
editing this file with a Sync Impact Report, bumping the version (MAJOR: a
principle removed or redefined; MINOR: a principle or section added; PATCH:
wording), and updating dependent templates and docs in the same commit. Every new or revised active
`plan.md` Constitution Check MUST evaluate principles I–X; violations go in
its Complexity Tracking table with justification.

**Version**: 3.0.1 | **Ratified**: 2026-10-30 | **Last Amended**: 2026-11-14
