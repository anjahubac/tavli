# Flutter / Dart best practices for Tavli

Binding for humans and AI agents. The constitution
(`.specify/memory/constitution.md`, principle IX) makes this document normative;
`analysis_options.yaml` enforces what can be enforced automatically.

## 1. Architecture

- **Feature-first folders**: `lib/features/<feature>/` holds that feature's
  screens, widgets and feature-level providers. Shared layers stay in
  `lib/ai/`, `lib/data/`, `lib/domain/`, `lib/app/`, `lib/account/`, `lib/sync/`.
- **Layers**: UI → providers (Riverpod) → repositories/services, with pure domain
  models. Repositories use drift and SyncedWriter; sync/account adapters wrap
  Supabase. AI facades use AIRouter and ChatClient. See architecture.md for the
  actual dependency map; do not introduce a new layer hierarchy for team roles.
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
  Only sanitized diagnostic categories may go to debug logs; never raw
  exceptions, provider payloads or personal data.

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
- Use `ColorScheme` and existing `TavliColors`/`TavliStatusColors` tokens; they keep contrast in light and dark mode.

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
  and test both fresh creation and upgrades from supported cache versions,
  including pending outbox rows and account scoping. Coordinate the next version
  with Dev 1 after preceding schema PRs merge.
- Never edit `*.g.dart` by hand. Commit generated files with the source change.
- Lists in rows are JSON text only when always read with the parent row.
- drift is the offline cache of server data (constitution II): user-data rows
  carry a client-generated UUID, owner (`householdId` or `userId`), `updatedAt`
  and deletion semantics defined by the entity registry. Local deletes use the
  existing outbox/tombstone mechanism; do not assume every local table has a
  soft-delete flag. Row mutations and their outbox entries share a transaction.
  Cached rows are scoped to the signed-in account. Device-only exceptions follow
  constitution II; do not sync keys, device settings or future raw cycle data.

## 10a. Backend (Supabase)

- Schema, RLS policies, grants and storage policies only via SQL migrations in
  `supabase/migrations/` (`supabase migration new <name>`); never change the
  hosted schema by hand and never edit an applied migration.
- Every table: `enable row level security`, policies per operation, and explicit
  `grant ... to authenticated`; `anon` gets nothing (`auto_expose_new_tables = false`).
- Membership checks go through a `security definer` helper (e.g.
  `is_household_member(household_id)`) to avoid recursive policies.
- Server-side work that needs elevated rights (account deletion) runs in the
  database or an Edge Function, never with a service-role key in the app.
- Develop and test against the local stack (`supabase start`, ports 5532x);
  `supabase test db` covers every policy with at least two accounts.

## 11. Networking and AI

- All AI goes through `AIRouter` (constitution III). No direct `dio` calls to AI providers from features.
- Timeouts are set on the client (connect 10 s; response per model via `ModelSpec.timeout`:
  30 s for fast models, 60 s for slow "thinking" models; a timeout is not retried). Retries happen only
  in the client (one transient retry) and router (fallback chain) — not in features.
- Responses are validated by parse functions that throw `FormatException`.

## 12. Security

- No secrets in code, tests, fixtures, logs, screenshots, commit messages.
- Own keys and the auth session: Keychain/Keystore. Built-in AI keys and the
  Supabase URL/anon key: gitignored `secrets.json` via `--dart-define-from-file`;
  `secrets.example.json` holds empty values only. The service-role key never
  enters the app or the repo.
- Never log request headers, full request bodies, keys, or personal data
  (including recipes, pantry, health data and identifying record/account IDs).
- Don't display keys after saving (obscured fields, no "show saved key").

## 13. Testing

- Pyramid: many **unit** tests (domain, parsing, router), fewer **widget** tests
  (key flows per screen), few **golden** tests (only for stable visual components),
  and **integration** tests (`integration_test/`) for end-to-end happy paths when screens exist.
- Fakes over mocks: hand-written fakes (`FakeClient`, `FakeAdapter`, in-memory stores)
  — no network, no real keys, no real Keychain, no real backend in Flutter tests
  (fake the Supabase-facing repository/remote interface).
- Server access rules are tested with `supabase test db` (pgTAP) against the
  local stack, outside `scripts/check.sh`.
- Test runs: the pre-commit hook runs only the tests affected by the staged
  files (`scripts/test-changed.sh`, which follows imports; a `pubspec` change
  runs everything). The full suite runs in CI on every PR. A test that waits on
  real time (retries, debounce, animations) uses the fake clock of `testWidgets`
  (`tester.pump(duration)`) instead of real delays.
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
- Log non-identifying event/error categories only, never secrets, user-linked IDs
  or personal content. Production telemetry needs an explicit privacy decision.

## 17. Git and commits

**Branching**

- `dev` is the integration branch (deploys to `tavli-dev`);
  `main` is production. Every normal work branch starts from the latest `dev`:
  `git fetch origin && git switch -c <branch> origin/dev`.
  Never branch from another feature branch (no stacked branches). If new work
  depends on an unmerged branch, merge that PR first (or ask the owner).
- Branch names (checked in CI by `branch-name`): `NNN-short-name` (Spec Kit
  feature), or `feat/…`, `fix/…`, `chore/…`, `docs/…`, `refactor/…`, `perf/…`,
  `test/…`, `ci/…`, `spec/…`, lowercase kebab-case; `hotfix/…` only for urgent
  production fixes.
- One branch = one topic = one PR into `dev`. Keep branches short-lived.
- Never commit directly to `dev` or `main`; everything lands through a pull request.
- Before opening or updating a PR, bring the branch up to date with `dev`
  (prefer `git fetch origin` then `git merge origin/dev`; ask before rebasing
  or any history rewrite, including on your own branch), run `scripts/check.sh` and
  `scripts/test-changed.sh origin/dev` (or the full `flutter test`).

**Releases and hotfixes**

- Release: when `tavli-dev` has been tested, open a PR `dev` → `main` and merge
  it with a **merge commit** (never squash, or `dev` and `main` drift apart).
  Migrations then deploy to production after approval in the `production`
  environment.
- Hotfix: branch `hotfix/…` from `origin/main`, PR into `main` (squash), then
  open a PR `main` → `dev` (merge commit) so the fix is not lost.

**Commits**

- Small commits that each build and pass the pre-commit hook (`scripts/check.sh`
  + affected tests); one logical change per commit.
- Subject in imperative mood, ≤ 72 chars, with a type and optional scope:
  `feat(003): …`, `fix(ai): …`, `spec(004): …`, `docs: …`, `chore: …`, `test: …`, `refactor: …`.
- The body explains *why*, not what the diff already shows.
- Generated code (`*.g.dart`) is committed with the source change that produced it.
- Never commit secrets, `secrets.json`, build output or IDE files (keep `.gitignore` current).

**Pull requests and history**

- PR title follows the commit convention (checked in CI by `pr-title`); it
  becomes the squash commit on `dev`. The body says what changed, why, and how
  it was tested (`.github/pull_request_template.md`).
- Work branches are **squash-merged** into `dev`.
- Merge only with green CI (`check`, `branch-name`, `pr-title`); resolve conflicts on the branch, not on `dev` or `main`.
- No force-push to `dev` or `main`. On your own feature branch use `--force-with-lease`, and only after asking.
- No history rewrite of shared branches, no branch deletion, no `reset --hard` without asking.
- Ask before deleting a branch, including after merge.

## 18. Shared contracts and current architecture

Follow [team workflow](development/team-workflow.md),
[AI development](development/ai-development.md),
[UI standards](development/ui-standard.md) and
[quality gates](development/quality-gates.md). New/revised engineering docs use
English; preserve Serbian Latin UI copy and surrounding code-comment conventions.

- Use existing CivilDate for calendar days; use UTC instants for event timestamps.
  Do not infer a selected meal date from UTC conversion. Test time-zone boundaries.
- Shopping contributions and explicit purchase receipts are separate from source
  recipe requirements. Test repeated add, changed servings, two recipes sharing
  an ingredient, purchase/undo and offline replay before changing aggregation.
- Keep original ingredient text while introducing food IDs/units in future work.
  Unknown pantry quantity is not zero or an unlimited confirmed supply.
- Domain/AI parsing/router/error changes are test-first, not optional. New AI
  contracts validate types and semantics; use bounded repair and fake transports.
- Built-in AI keys currently come from build configuration. The future gateway
  moves them server-side; BYOK stays secure on device. A doc is not a deployment.
- Human review is required across ownership boundaries. Reserve schema versions,
  name exact shared paths, and merge producer contracts before consumer branches.
- Coverage targets are goals, not currently enforced CI thresholds. New SQL,
  platform and hosted ruleset checks require explicit infrastructure work/evidence.

## 19. Security boundaries

Follow [security baseline](development/security.md). Treat server/AI/document
input as untrusted: validate filesystem leaf names and root containment, bound
decoding, map failures to safe categories, never interpolate raw errors in UI.
Test RLS/grants/RPC/object access with allowed and denied local cases. No shared
provider secrets in new client features; gateway cutover and safe diagnostics
are tracked in spec 012. Keep authentication, data and release checks independent
of whether the client followed the intended UI. Known current gaps require
runtime fixes; documentation is not their remediation.

Testing-lane clarification (013): normal Flutter unit/widget tests use fakes and
no network. A separately invoked endpoint-guarded integration runner may use only
ephemeral local Supabase with synthetic accounts and fake AI. This exception is
not permission to read secrets files, probe hosted services or weaken default
checks. See `specs/013-testing-strategy/` and `docs/development/testing.md`.
Release 033 coordinates artifacts and recovery; 012 owns security gates, 013
owns their execution infrastructure. Implement shared CI work once and link evidence.
