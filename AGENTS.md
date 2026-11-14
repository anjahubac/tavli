# AGENTS.md — Tavli

Canonical guide for AI coding agents (Claude Code, Copilot, Cursor, Codex, …)
working in this repo. The rules in `.specify/memory/constitution.md` take
precedence; this file explains how to follow them day to day.

## Project overview

Tavli is a Flutter app (Android, iOS, macOS) for recipes, meal plans, pantry
and shopping lists. AI turns a photo or a dish name into a recipe and edits
recipes via chat. AI runs on free tiers of Gemini, Groq and OpenRouter through
one OpenAI-compatible client and a router with fallback chains.

**An account is required.** After the intro the user signs in (email with a
one-time code; Apple/Google later) and synced business data is stored on
Supabase (Auth, Postgres with Row Level Security, Storage; EU region) under the
account. drift is the offline cache: changes are written locally plus an outbox
and uploaded when online; data is downloaded on sign-in. Sign-out keeps the data
(server and per-account device cache); only deleting an item or the account
deletes data. See constitution principle II and `specs/006-account-login/`.

**All UI text is Serbian, Latin script.** Code identifiers are English;
existing comments are mostly Serbian — match the surrounding file.

## Product direction

Read [docs/product-design.md](docs/product-design.md),
[docs/product-plan.md](docs/product-plan.md) and the active spec before planning.
Current `dev` has Plan, Nabavka, Recepti, Ostava; Plan is the initial tab. Planning
and linked/standalone shopping code exist, while 010 acceptance remains partial.
The latest target adds central/default Početna: Plan, Nabavka, Početna, Recepti,
Ostava. Pantry stays simple: no expiry dates or “use first” UI, optional quantity.
The gateway, food catalog, household invitations, nutrition diary, voice,
cookbooks and Windows remain planned. Read the
[010 overlay](specs/010-plan-and-shopping/current-direction.md) for superseded
requirements; never rewrite historical checked tasks to imply new work shipped.

All new/revised engineering documentation is English; exact UI copy remains
Serbian Latin. Architecture evidence and current paths are in
[docs/architecture.md](docs/architecture.md).

## Structure

```
lib/
  main.dart               ProviderScope + TavliApp
  providers.dart          Riverpod wiring (db, key store, chain config, router, RecipeAI, MealPlanAI)
  app/                    MaterialApp, go_router config, responsive HomeShell, placeholders
    theme/                  palettes, TavliColors extension, buildTavliTheme, ThemeController
    animations/             reduced-motion aware CustomPainter animations (MotionBuilder)
  ai/                     AI layer
    ai_models.dart          AIProvider, ModelSpec, AIRequest, AIImage, TaskKind
    ai_errors.dart          sealed AIError hierarchy, AttemptLog, AllModelsExhausted
    chat_client.dart        OpenAICompatibleClient (dio), HTTP → AIError mapping
    chain_config.dart       default vision/text model chains
    ai_router.dart          AIRouter: fallback, cooldowns, retry-on-bad-JSON
    model_status_store.dart cooldown/usage store interface (+ in-memory)
    key_store.dart          KeyStore interface, SecureKeyStore (Keychain/Keystore)
    model_check.dart        compare chain models with provider /models list
    prompts.dart            system prompt + recipe JSON schema + task prompts
    recipe_ai.dart          RecipeAI: fromImage, fromDishName, refine
    meal_plan_ai.dart       MealPlanAI and planning schema
  account/                Supabase config/client, AuthGateway (email code), SessionStore
                          (Keychain), AccountApi, AccountService, AuthController + AccountScope
  sync/                   entity registry, SyncedWriter (outbox), Supabase SyncRemote/PhotoRemote,
                          Uploader, Downloader, PhotoSync, LegacyMover, SyncEngine
  data/                   drift database (all tables, per-account cache + outbox),
                          DriftModelStatusStore, RecipeRepository, RecipePhotoStore, photo downscaling
  domain/                 pure Dart models (Recipe, Ingredient, Account, ids)
  features/<feature>/     screens, widgets and feature providers
                          (recipes/, planning/, shopping/, settings/, account/)
supabase/                 config.toml, migrations/ (schema, RLS, grants, storage),
                          tests/ (pgTAP: `supabase test db`), functions/delete-account/, templates/
test/                     mirrors lib/; helpers/fake_adapter.dart fakes dio,
                          helpers/fake_backend.dart fakes Supabase (auth, tables, storage),
                          helpers/test_app.dart pumps the whole app signed in (testTavli/pumpTavli)
specs/NNN-name/           Spec Kit specs (spec.md, plan.md, tasks.md)
docs/                     architecture, product plan/design, development standards
.specify/                 Spec Kit memory (constitution), templates, scripts
```

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after drift table changes
flutter analyze                                             # must be clean
flutter test                                                # must be green
flutter build macos --debug                                 # smoke build
flutter run -d macos
flutter run -d macos --dart-define-from-file=secrets.dev.json   # tavli-dev backend + built-in AI keys (see secrets.example.json)
flutter run -d macos --dart-define-from-file=secrets.json       # local stack (`supabase start`) or your own config
scripts/check.sh                                            # format check + analyze (fast, no tests)
scripts/test-changed.sh                                     # tests affected by staged changes
scripts/test-changed.sh origin/dev                          # tests affected by the whole branch
git config core.hooksPath .githooks                         # once per clone: pre-commit runs both scripts above

supabase start          # local Supabase in Docker (API :55321, DB :55322, Studio :55323, mail :55324)
supabase status         # local URL and anon key to copy into your own secrets.json
supabase db reset       # re-apply supabase/migrations from scratch
supabase test db        # RLS / grant tests (pgTAP) against the local stack
supabase stop
```

The local stack uses ports 5532x so it does not clash with other Supabase
projects on the same machine (default 5432x). Sign-in emails from the local
stack land in the mail catcher (Mailpit, :55324), not in a real inbox.

## Branches and environments

| Branch | Backend (Supabase) | App config | Updated by |
|---|---|---|---|
| work branch | local stack (`supabase start`) | `secrets.json` | you |
| `dev` (integration) | `tavli-dev` | `secrets.dev.json` | squash-merged PRs; CI deploys migrations |
| `main` | production | `secrets.prod.json` | release PR `dev` → `main` (merge commit), approval required |

- PRs into `dev` and `main` must pass `check`, `branch-name` and `pr-title`
  (`.github/workflows/check.yml`, `pr-conventions.yml`).
- Merging into `dev` applies new migrations and edge functions to `tavli-dev`;
  merging into `main` applies them to production after approval in the
  `production` environment (`deploy-supabase.yml`). Required reviewers/rulesets
  must be verified in GitHub settings; a workflow file does not configure them.
- `secrets.*.json` are gitignored and shared through a password manager.
  Until the app has flavors, sign out before switching between dev and prod
  config: both builds share the Keychain session and the drift cache.
- macOS debug signing: copy `macos/Runner/Configs/Local.xcconfig.example` to
  `Local.xcconfig` (gitignored) and set your own `DEVELOPMENT_TEAM`, so Keychain
  "Always Allow" survives rebuilds.

## Code conventions

Full rules: [docs/flutter-best-practices.md](docs/flutter-best-practices.md).
Lints are strict (`analysis_options.yaml`: strict casts/inference/raw types,
unawaited futures and context-after-await are errors).

- Riverpod providers live in `lib/providers.dart` until a feature needs its own
  file; prefer `Provider`/`Notifier`; inject fakes via `ProviderScope(overrides:)`.
- Routes are declared in `lib/app/router.dart`; tabs come from the `tabs` list.
- Domain classes are immutable, pure Dart, no Flutter imports.
- AI-facing parsing throws `FormatException` on schema mismatch (router retries once).
- Errors shown to the user go through `aiErrorText` or an equivalent Serbian mapping.
- Inject time (`DateTime Function() clock`) where behaviour depends on it.
- Keep generated `lib/data/database.g.dart` committed and in sync.
- UI reads from drift (the offline cache); never from the network directly.
  Every synced business-data write goes through a repository that writes the row and an
  outbox entry in one transaction. Record ids are client-generated (UUID).
- Backend access only through the data layer (Supabase client wrapped behind an
  interface so tests can fake it); no Supabase calls from widgets.
- Follow `flutter_lints`; no `// ignore:` without a reason in the comment.

## Spec Kit workflow

One feature = one canonical spec. Each implementation slice has one owner/branch/PR. **Every new branch is
created from the latest `dev`** (`git fetch origin && git switch -c NNN-name origin/dev`),
never from another feature branch, and its PR targets `dev`; full git rules are in
[docs/flutter-best-practices.md §17](docs/flutter-best-practices.md).

1. Create/verify the branch from `origin/dev` first; `/speckit-specify <what and why>`
   prepares `specs/NNN-name/spec.md`. The installed script does not create a branch.
2. `/speckit-clarify` — resolve open questions before planning.
3. `/speckit-plan <tech notes>` — `plan.md` (+ research, data model, contracts);
   must pass the Constitution Check.
4. `/speckit-tasks` — `tasks.md`, tests first for domain/AI parsing.
5. `/speckit-analyze` — cross-check spec/plan/tasks consistency.
6. `/speckit-implement` — work through tasks, checking them off.

`specs/001-foundation-ai-router/` is a backfilled example of the finished format.

## Four developers and AI sessions

- Follow [team workflow](docs/development/team-workflow.md) for owners, contracts,
  migration ordering, independent review and remaining-effort planning.
- Switch branches in the existing repository folder; do not create additional
  worktrees, clones or branch-specific folders unless explicitly requested. Allow
  only one active writer in a checkout. Preserve unrelated edits; if they block
  switching branches, ask rather than automatically stashing or resetting them.
- Set `SPECIFY_FEATURE_DIRECTORY`
  to your spec explicitly; do not overwrite tracked `.specify/feature.json` to
  redirect someone else's work. Reserve the next number in `specs/README.md`.
- Shared-file changes name paths and coordinator before implementation. Existing
  feature providers stay under `lib/features/`; do not invent a replacement layout.
- Follow [AI development](docs/development/ai-development.md) for briefs, untrusted
  input, validation and handoff; an agent's claim is not test or review evidence.
- Reuse [UI standards](docs/development/ui-standard.md) and existing theme/motion
  components. Validate phone, wide screen, 2× text and reduced motion.
- Device-only settings/secrets and the planned cycle privacy exception follow
  constitution II; do not route them into the user-data outbox.
- Read [quality gates](docs/development/quality-gates.md). Documentation changes
  run `python3 scripts/check-docs.py` and `git diff --check`; runtime changes keep
  their applicable Flutter, local SQL and platform gates.

## Guardrails for AI agents

- Never commit secrets: no keys in code, tests, fixtures, docs or commit messages;
  never read, print or edit `secrets*.json` or Keychain entries.
- Never disable, skip or delete tests to get green, and never add `// ignore:`
  without a reason comment on the line above.
- Never edit generated `*.g.dart` by hand — change the source and run
  `dart run build_runner build --delete-conflicting-outputs`.
- No new dependency without a one-line justification in the active `plan.md`.
- No drift schema change without a `schemaVersion` bump, a migration step and a test.
- No server table without RLS enabled, policies, explicit `GRANT`s to
  `authenticated` only, and a `supabase test db` test with two accounts; schema
  changes only as new files in `supabase/migrations/` (never edit an applied one).
- Never put the Supabase service-role key in the app, tests or repo; never call
  the hosted (production) project from tests or scripts.
- Before each commit: `dart format lib test`; the pre-commit hook
  (`.githooks/pre-commit`) then runs `scripts/check.sh` (format check,
  `flutter analyze`) and `scripts/test-changed.sh` (tests affected by the staged
  files, following imports). Never bypass it with `--no-verify`.
- The full `flutter test` suite runs in CI on every PR; run it locally
  (`flutter test`) before opening a PR that touches shared code.
- Keep changes scoped to the active spec/branch; note unrelated issues instead of fixing them in passing.
- Branch only from the latest `dev`; never stack a branch on another unmerged branch.
  Never commit directly to `dev` or `main` — open a PR into `dev`. Only the
  release PR (`dev` → `main`) and `hotfix/…` branches target `main`; agents
  never open or merge those unless asked.
- Never run migrations, `supabase db push`, `supabase link` or
  `supabase config push` against a hosted project; hosted projects are updated
  only by `.github/workflows/deploy-supabase.yml`.
- Ask before destructive git operations (reset --hard, force push, branch deletion, history rewrite).
- All new UI text in Serbian (Latin); AI only through `AIRouter`.

## Definition of done

Apply the change-specific quality matrix; runtime criteria below apply to app changes.
An independent human review and merged PR are required for delivery Done.

- All tasks in `tasks.md` checked; acceptance scenarios in `spec.md` satisfied.
- New UI text is Serbian (Latin) and listed in the spec.
- Works on phone width and wide (rail) layout.
- `scripts/check.sh` and the full `flutter test` pass (CI green);
  `flutter build macos --debug` succeeds.
- AI calls go through `AIRouter`; failures show a Serbian message.
- User-data changes reach the server via the outbox and work offline; new server
  tables have RLS, grants and `supabase test db` tests.
- Small commits with clear messages; generated code included.

## Security rules for keys and backend

- Never write, print, log, or commit an API key — not in code, tests, fixtures,
  docs, commit messages, or chat output.
- User keys and the auth session live only in secure storage (`SecureKeyStore`,
  Keychain/Keystore). Tests use `InMemoryKeyStore` and fake backends with fake values.
- Current build-time values (Supabase URL and anon key, built-in AI keys) go in the
  gitignored `secrets.json` passed via `--dart-define-from-file`;
  `secrets.example.json` has empty placeholders only; never read them in tests.
- The Supabase service-role key never goes into the app, the repo or chat output.
- Never log session tokens, email codes, or personal data (recipes, lists, names, emails).
- Don't add logging of request headers or full request bodies.
- Agents must not edit, rotate or test real keys unless the user explicitly asks.

Built-in provider credentials will move behind the planned AI gateway. This is
not deployed yet; preserve `AIRouter` and fakeable transport during migration.

Spec Kit state caveat: the installed `get_feature_paths` persists an explicit
`SPECIFY_FEATURE_DIRECTORY` into the current checkout's `.specify/feature.json`, even
when a command only checks prerequisites. Inspect the resulting diff; keep this
session pointer out of a feature PR unless intentionally updating shared default
context. Set the environment selection for each session; it does not make the
helper read-only. Serialize writers in the same checkout. Do not overwrite another person's existing pointer edit.

## Security review for every feature

Read [security baseline](docs/development/security.md) and the
[012 specification](specs/012-security-baseline/spec.md). Existing source-level
gaps are recorded there, not fixed by these rules. No shared provider secrets in
new client features; gateway cutover is required before wider distribution.
Validate synced file names/root containment; never display/log raw provider
bodies or exception strings. Server grants/RLS and private storage enforce
ownership independently of UI. New remote endpoints have auth/limits and negative
tests. Use local synthetic accounts and fake providers; never probe production.
Record privacy, abuse, credential, file and deployment impact in every active
spec/PR, with explicit N/A where appropriate. Verify real hosted controls before
claiming enforcement. Security implementation stays in separately reviewed slices.

Testing infrastructure is specified in `specs/013-testing-strategy/`; use
`docs/development/testing.md` and the critical journey matrix. Default unit/widget
suites are network-free; only the explicitly invoked guarded local-backend lane
may contact ephemeral local Supabase with synthetic accounts and fake AI.
All roadmap specs are indexed in `specs/README.md`; source tasks map through
`docs/development/source-task-map.md`. Release/operations use spec 033. Drafts
need their recorded decisions before dependent code; never treat them as shipped.
