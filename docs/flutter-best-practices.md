# Flutter / Dart best practices for Tavli

Binding for humans and AI agents. The constitution
(`.specify/memory/constitution.md`, principle IX) makes this document normative;
`analysis_options.yaml` enforces what can be enforced automatically.

## 1. Architecture

- **Feature-first folders**: `lib/features/<feature>/` holds that feature's
  screens, widgets and feature-level providers. Shared layers stay in
  `lib/ai/`, `lib/data/`, `lib/domain/`, `lib/app/`.
- **Layers**: UI → providers (Riverpod) → domain / services (`RecipeAI`,
  `AIRouter`) → data (drift, secure storage, HTTP). Dependencies point inward only.
- **No business logic in widgets.** Widgets render state and forward intents.
  Parsing, calculations, AI calls and DB writes live in domain/services and are unit-tested.
- **Domain is pure Dart**: no `package:flutter` imports in `lib/domain/`.
- Inject collaborators (clock, client, stores) through constructors/providers so they can be faked.

## 2. Riverpod

- Never call `ref.read` inside `build` to get state; use `ref.watch`.
  Use `ref.read` only in callbacks (onPressed, initState-triggered async work).
- Use `autoDispose` for screen-scoped state (forms, detail screens);
  keep app-wide singletons (database, router, key source) as plain `Provider`.
- Expose async state as `AsyncValue` (`FutureProvider` / `AsyncNotifier`) and
  render all three states with `.when(data:, loading:, error:)`. No silent
  `valueOrNull ?? []` that hides errors.
- Override providers in tests with `ProviderScope(overrides: [...])`.
- Keep `lib/providers.dart` for shared wiring; feature providers go next to the feature.

## 3. Immutability and null safety

- Domain classes are immutable: `final` fields, `const` constructors, `copyWith`.
  `freezed` may be introduced when models grow (needs a plan.md justification).
- Prefer `final` locals; `const` widgets and literals wherever possible.
- No `!` unless the invariant is local and obvious; prefer early returns and pattern matching.
- Analyzer runs with `strict-casts`, `strict-inference`, `strict-raw-types`:
  cast JSON explicitly (`json['x'] as String?`) and validate.

## 4. Errors

- Use typed errors (`sealed class AIError`, `FormatException` for bad input).
  Throw only `Exception`/`Error` subclasses.
- Never swallow exceptions: no empty `catch`, no `catch (e)` without `on`.
  Catch what you can handle; let the rest surface.
- Every user-facing error is a short **Serbian** message (`aiErrorText` pattern).
  Technical detail goes to debug logs, never to the user verbatim.

## 5. Async

- No unawaited futures: `await` them, or wrap in `unawaited(...)` when fire-and-forget is intended
  (`unawaited_futures` and `discarded_futures` are errors).
- After any `await` in a `State`, check `if (!mounted) return;` before `setState`
  or using `context` (`use_build_context_synchronously` is an error).
- Dispose controllers, subscriptions and sinks in `dispose`.
- Inject time (`DateTime Function() clock`) instead of calling `DateTime.now()` in logic.

## 6. Performance

- `const` constructors for static subtrees.
- Long or unbounded lists use `ListView.builder` / `SliverList`; small fixed
  forms may use `ListView(children:)`.
- Keep `build` cheap: no I/O, parsing or sorting in `build`; select narrowly
  (`ref.watch(provider.select(...))`) to avoid rebuilds.
- Images: downscale before sending to AI and before storing; use `cacheWidth`/`cacheHeight`
  for thumbnails; store files on disk, paths in the DB.

## 7. Accessibility

- Tap targets ≥ 48×48 dp; Material components already comply — keep it that way for custom widgets.
- Icon-only buttons need `tooltip` (also used as the semantic label); custom
  visuals get `Semantics(label: ...)` in Serbian.
- Layouts must survive text scale 2.0 (no fixed-height text containers; test with `textScaler`).
- Use theme colors (`ColorScheme`) only; they keep contrast in light and dark mode.

## 8. Responsive / adaptive layout

- Breakpoints: < 720 px bottom `NavigationBar`; ≥ 720 px `NavigationRail`; ≥ 1000 px extended rail.
- Use `MediaQuery.sizeOf` / `LayoutBuilder`; never hard-code screen widths.
- Wide screens: constrain reading width (≈ 720 px) or use list–detail layouts.
- Widget tests cover phone (e.g. 400×800) and wide (e.g. 1200×800) sizes for new screens.

## 9. Internationalization readiness

- UI is Serbian (Latin) only for now. Keep strings out of logic: UI text lives in widgets
  or a per-feature strings file so a later move to `flutter_localizations`/ARB is mechanical.
- Format numbers/dates for `sr_Latn` (decimal comma, `dd.MM.yyyy.`).
- Never build sentences by concatenating translated fragments with grammatical case logic in code.

## 10. Database (drift)

- Every schema change: bump `schemaVersion`, add a step in `MigrationStrategy.onUpgrade`,
  regenerate with `dart run build_runner build --delete-conflicting-outputs`,
  and add a test that opens the DB and exercises the changed table.
- Never edit `*.g.dart` by hand. Commit generated files with the source change.
- Lists in rows are JSON text only when always read with the parent row.

## 11. Networking and AI

- All AI goes through `AIRouter` (constitution III). No direct `dio` calls to AI providers from features.
- Timeouts are set on the client (connect 15 s, receive 90 s). Retries happen only
  in the client (one transient retry) and router (fallback chain) — not in features.
- Responses are validated by parse functions that throw `FormatException`.

## 12. Security

- No secrets in code, tests, fixtures, logs, screenshots, commit messages.
- Own keys: Keychain/Keystore via `KeyStore`. Built-in keys: gitignored
  `secrets.json` via `--dart-define-from-file`; `secrets.example.json` holds empty values only.
- Never log request headers, full request bodies, keys, or personal data
  (recipes and pantry are personal data — log ids, not content).
- Don't display keys after saving (obscured fields, no "show saved key").

## 13. Testing

- Pyramid: many **unit** tests (domain, parsing, router), fewer **widget** tests
  (key flows per screen), few **golden** tests (only for stable visual components),
  and **integration** tests (`integration_test/`) for end-to-end happy paths when screens exist.
- Fakes over mocks: hand-written fakes (`FakeClient`, `FakeAdapter`, in-memory stores)
  — no network, no real keys, no real Keychain in tests.
- Test names in Serbian describing behaviour (existing convention).
- Coverage target: ≥ 80 % for `lib/ai/` and `lib/domain/`; check with `flutter test --coverage`.
- Never skip or delete a failing test to get green; fix the code or the test's wrong assumption.

## 14. Platform configuration

- Declare only needed permissions, each with a Serbian usage string (iOS `Info.plist`).
- macOS entitlements: add capabilities explicitly in both `DebugProfile` and `Release`.
- Android: keep `INTERNET`; add runtime permissions only with a feature that needs them.

## 15. Dependencies

- Minimal: a new package needs a one-line justification in the feature's `plan.md`.
- Caret constraints in `pubspec.yaml`, exact versions in the committed `pubspec.lock`.
- Review `flutter pub outdated` at least once per phase; upgrade in a separate commit.
- Prefer first-party / Flutter Favorite packages.

## 16. Logging

- Use `debugPrint`/`dart:developer` `log` behind `kDebugMode`; `print` is an error.
- Log events and ids, never secrets or personal content.

## 17. Git and commits

**Branching**

- Every new branch starts from the latest `main`:
  `git fetch origin && git switch -c <branch> origin/main`.
  Never branch from another feature branch (no stacked branches). If new work
  depends on an unmerged branch, merge that PR first (or ask the owner).
- Branch names: `NNN-short-name` (Spec Kit feature), `chore/…`, `fix/…`, `docs/…`.
- One branch = one topic = one PR into `main`. Keep branches short-lived.
- Never commit directly to `main`; everything lands through a pull request.
- Before opening or updating a PR, bring the branch up to date with `main`
  (`git fetch origin && git rebase origin/main` on your own unshared branch,
  otherwise `git merge origin/main`) and run `scripts/check.sh`.

**Commits**

- Small commits that each build and pass `scripts/check.sh`; one logical change per commit.
- Subject in imperative mood, ≤ 72 chars, with a type and optional scope:
  `feat(003): …`, `fix(ai): …`, `spec(004): …`, `docs: …`, `chore: …`, `test: …`, `refactor: …`.
- The body explains *why*, not what the diff already shows.
- Generated code (`*.g.dart`) is committed with the source change that produced it.
- Never commit secrets, `secrets.json`, build output or IDE files (keep `.gitignore` current).

**Pull requests and history**

- PR title follows the commit convention; the body says what changed, why, and how it was tested.
- Merge only with green `scripts/check.sh`; resolve conflicts on the branch, not on `main`.
- No force-push to `main`. On your own feature branch use `--force-with-lease`, and only after asking.
- No history rewrite of shared branches, no branch deletion, no `reset --hard` without asking.
- Delete a branch after its PR is merged (ask first if someone else might use it).
