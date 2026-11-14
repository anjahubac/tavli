# Tavli

**From meal planning to organized shopping and cooking.**

Tavli is a Flutter application for Android, iOS and macOS. Its interface is in
Serbian (Latin script); engineering documentation is in English. An account is
required. Supabase stores synced business data; drift supplies the account-scoped
offline cache and transactional outbox. Credentials stay in device secure storage.

## Current development baseline

On `dev`, recipes support photo/name/manual input, AI refinement and history.
Planning includes generation, review and a calendar. Shopping supports plans
and individual recipes, contribution tracking and receipt provenance. The
current tabs are Plan, Nabavka, Recepti, Ostava; pantry UI is still a placeholder.
Spec 010 has implemented code and remaining acceptance work; this is not a
claim that every planned behavior or platform release has shipped.

The next direction adds central Početna, a simple pantry without expiry tracking,
a food catalog, household collaboration and richer planning. The AI gateway,
optional nutrition diary, cookbooks, voice and Windows are future work. See
[product plan](docs/product-plan.md) and [roadmap](docs/roadmap.md).

## Start development

Read [AGENTS.md](AGENTS.md), [architecture](docs/architecture.md),
[team workflow](docs/development/team-workflow.md) and your active spec.
Normal work branches start from latest `origin/dev` and PRs target `dev`;
`main` is production. Never stack work on an unmerged feature branch.

```bash
flutter pub get
git config core.hooksPath .githooks
scripts/check.sh
flutter test
flutter run -d macos
```

Account-backed use needs the team's gitignored local configuration passed with
`--dart-define-from-file`. Humans provision it using empty example placeholders;
agents must not read or expose credentials. For a local backend, run
`supabase start` (Docker required). Ports are API 55321, DB 55322, Studio 55323,
mail 55324. Default Flutter unit/widget tests use fakes; database tests run only against local Supabase.

After drift changes, regenerate with
`dart run build_runner build --delete-conflicting-outputs` and test migrations.
See [quality gates](docs/development/quality-gates.md) for all applicable checks.

## Documentation

- [Documentation index](docs/README.md): canonical reading order and status.
- [Product design](docs/product-design.md): intended flows and UI decisions.
- [Architecture](docs/architecture.md): actual layers, paths, data and AI flows.
- [Spec Kit index](specs/README.md): features, historical evidence and reservations.
- [Four-developer standardization](specs/011-team-development/spec.md): rules revision.
- [AI development](docs/development/ai-development.md): task briefs and verified handoffs.

Run `python3 scripts/check-docs.py` after active document/template changes.
