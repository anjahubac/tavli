# AGENTS.md — Tavli

Canonical guide for AI coding agents (Claude Code, Copilot, Cursor, Codex, …)
working in this repo. The rules in `.specify/memory/constitution.md` take
precedence; this file explains how to follow them day to day.

## Project overview

Tavli is a Flutter app (Android, iOS, macOS) for recipes, meal plans, pantry
and shopping lists. AI turns a photo or a dish name into a recipe and edits
recipes via chat. AI runs on free tiers of Gemini, Groq and OpenRouter through
one OpenAI-compatible client and a router with fallback chains.

**All UI text is Serbian, Latin script.** Code identifiers are English;
existing comments are mostly Serbian — match the surrounding file.

## Structure

```
lib/
  main.dart               ProviderScope + TavliApp
  providers.dart          Riverpod wiring (db, key store, chain config, router, RecipeAI)
  app/                    MaterialApp, go_router config, responsive HomeShell, placeholders
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
  data/                   drift database (all tables) + DriftModelStatusStore
  domain/                 pure Dart models (Recipe, Ingredient, categories)
  features/<feature>/     screens and widgets per feature (settings/ so far)
test/                     mirrors lib/; helpers/fake_adapter.dart fakes dio
specs/NNN-name/           Spec Kit specs (spec.md, plan.md, tasks.md)
docs/                     architecture.md, roadmap.md
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
scripts/check.sh                                            # format check + analyze + test (run before every commit)
```

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
- Follow `flutter_lints`; no `// ignore:` without a reason in the comment.

## Spec Kit workflow

One feature = one spec = one branch (`NNN-short-name`).

1. `/speckit-specify <what and why>` — creates `specs/NNN-name/spec.md` and the branch.
2. `/speckit-clarify` — resolve open questions before planning.
3. `/speckit-plan <tech notes>` — `plan.md` (+ research, data model, contracts);
   must pass the Constitution Check.
4. `/speckit-tasks` — `tasks.md`, tests first for domain/AI parsing.
5. `/speckit-analyze` — cross-check spec/plan/tasks consistency.
6. `/speckit-implement` — work through tasks, checking them off.

`specs/001-foundation-ai-router/` is a backfilled example of the finished format.

## Guardrails for AI agents

- Never commit secrets: no keys in code, tests, fixtures, docs or commit messages;
  never read, print or edit `secrets.json` or Keychain entries.
- Never disable, skip or delete tests to get green, and never add `// ignore:`
  without a reason comment on the line above.
- Never edit generated `*.g.dart` by hand — change the source and run
  `dart run build_runner build --delete-conflicting-outputs`.
- No new dependency without a one-line justification in the active `plan.md`.
- No drift schema change without a `schemaVersion` bump, a migration step and a test.
- Before each commit: `dart format lib test`, then `scripts/check.sh`
  (format check, `flutter analyze`, `flutter test`) must pass.
- Keep changes scoped to the active spec/branch; note unrelated issues instead of fixing them in passing.
- Ask before destructive git operations (reset --hard, force push, branch deletion, history rewrite).
- All new UI text in Serbian (Latin); AI only through `AIRouter`.

## Definition of done

- All tasks in `tasks.md` checked; acceptance scenarios in `spec.md` satisfied.
- New UI text is Serbian (Latin) and listed in the spec.
- Works on phone width and wide (rail) layout.
- `scripts/check.sh` passes; `flutter build macos --debug` succeeds.
- AI calls go through `AIRouter`; failures show a Serbian message.
- Small commits with clear messages; generated code included.

## Security rules for keys

- Never write, print, log, or commit an API key — not in code, tests, fixtures,
  docs, commit messages, or chat output.
- User keys live only in `SecureKeyStore`. Tests use `InMemoryKeyStore` with fake values.
- Build-time secrets (if ever added) go in gitignored files (`secrets.json`,
  `*.env`) passed via `--dart-define-from-file`; never read them in tests.
- Don't add logging of request headers or full request bodies.
- Agents must not edit, rotate or test real keys unless the user explicitly asks.
