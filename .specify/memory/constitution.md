<!--
Sync Impact Report
- Version change: (template) → 1.0.0
- Ratified principles: I–VIII (all new)
- Added sections: Platform & Technology Constraints, Development Workflow, Governance
- Templates requiring updates: plan-template.md "Constitution Check" gate should list principles I–VIII (✅ referenced by name; no template edits required)
- Follow-up TODOs: none
-->

# Tavli Constitution

Tavli is a personal Flutter app (Android, iOS, macOS) for recipes, meal planning,
pantry and shopping lists, with AI help that runs on free provider tiers.

## Core Principles

### I. Serbian UI (NON-NEGOTIABLE)

All user-facing text — labels, buttons, messages, errors, empty states, AI output
shown to the user — MUST be in Serbian, Latin script (ćčđšž, never Cyrillic).
AI prompts MUST instruct the model to answer in Serbian (Latin). Code identifiers
are English; code comments may be Serbian (the existing codebase uses Serbian
comments) or English. Specs and agent docs may be written in English but every
spec MUST state the Serbian (Latin) copy for any new UI text it introduces.

**Rationale**: the app is built for a Serbian-speaking household; mixed-language
UI is a defect, not a style choice.

### II. Offline-First Local Data

All user data (recipes, versions, pantry, shopping lists, meal plans, ratings,
profile, settings, model status) lives in the local drift (SQLite) database.
The app MUST be fully usable for browsing and editing existing data with no
network. Network is needed only for AI calls. No backend account or cloud sync
is assumed. Schema changes MUST bump `schemaVersion` and ship a migration.

**Rationale**: free AI tiers and connectivity are unreliable; the user's data must not be.

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

**Rationale**: free tiers hit rate limits constantly and model names change; resilience is the product.

### IV. Secrets Never Committed

API keys MUST NEVER appear in the repository, logs, test fixtures, screenshots,
or commit messages. User keys are stored in the platform secure store
(Keychain on iOS/macOS, Keystore on Android) via `KeyStore`. Any build-time key
file (e.g. `secrets.json`, `*.env`) MUST be gitignored. Tests use
`InMemoryKeyStore` with obviously fake values.

**Rationale**: the repo may become public; a leaked key burns a free quota or worse.

### V. Test-First for Domain and AI Parsing

Domain logic (`lib/domain/`), AI parsing (`fromAiJson`, prompt/JSON handling),
router behaviour and error mapping MUST be developed test-first: write the
failing test, then the code. AI is always faked in tests (fake `ChatClient` or
the `fake_adapter` Dio adapter) — tests MUST NOT hit the network. Widgets get
widget tests for key flows. `flutter analyze` MUST be clean and `flutter test`
MUST be green before every commit.

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

### VIII. One Feature = One Spec = One Branch

Each feature starts with a Spec Kit spec in `specs/NNN-short-name/` on a branch
of the same name, and follows specify → clarify → plan → tasks → analyze →
implement. Scope changes update the spec first.

## Platform & Technology Constraints

- Flutter (Dart ≥ 3.13), Material 3, targets Android, iOS, macOS.
- State: Riverpod (`flutter_riverpod`); routing: `go_router` with a
  `StatefulShellRoute`; persistence: drift; HTTP: dio; keys:
  `flutter_secure_storage`.
- AI providers: Gemini, Groq, OpenRouter — free tiers only — through one
  OpenAI-compatible `/chat/completions` client.
- New dependencies require a one-line justification in the feature's `plan.md`.

## Development Workflow

1. Branch from `main` as `NNN-feature-name` (Spec Kit numbering) or `chore/…` / `fix/…`.
2. `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks`
   → `/speckit-analyze` → `/speckit-implement`.
3. Before each commit: `dart run build_runner build` (if drift tables changed),
   `flutter analyze`, `flutter test`.
4. A feature is done when its tasks are checked off, acceptance scenarios pass,
   UI text is Serbian, and it runs on macOS debug (`flutter build macos --debug`).

## Governance

This constitution overrides other conventions in the repo. `AGENTS.md` is the
operational guide and MUST stay consistent with it. Amendments are made by
editing this file with a Sync Impact Report, bumping the version (MAJOR: a
principle removed or redefined; MINOR: a principle or section added; PATCH:
wording), and updating dependent templates and docs in the same commit. Every
`plan.md` Constitution Check MUST evaluate principles I–VIII; violations go in
its Complexity Tracking table with justification.

**Version**: 1.0.0 | **Ratified**: 2026-10-30 | **Last Amended**: 2026-10-30
