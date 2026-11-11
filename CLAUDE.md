@AGENTS.md

# Claude Code notes

- `AGENTS.md` (imported above) is the canonical guide; the constitution in
  `.specify/memory/constitution.md` wins on conflicts.
- The user writes in Serbian. Reply in Serbian unless asked otherwise; all app UI
  text is Serbian (Latin script).
- Spec Kit 0.11.2 is installed as skills in `.claude/skills/speckit-*`
  (`/speckit-specify`, `/speckit-clarify`, `/speckit-plan`, `/speckit-tasks`,
  `/speckit-analyze`, `/speckit-implement`, `/speckit-checklist`,
  `/speckit-constitution`). Templates and scripts are in `.specify/`.
- Follow `docs/flutter-best-practices.md` and the guardrails in `AGENTS.md`.
- New branches always start from the latest `dev` (never stacked on another
  branch) and their PRs target `dev`; `main` is production and only receives
  the release PR from `dev` or a `hotfix/…` (git rules: best practices §17,
  environments: `AGENTS.md` → Branches and environments).
- Enable the pre-commit hook once per clone (`git config core.hooksPath .githooks`):
  it runs `scripts/check.sh` (format, analyze) and `scripts/test-changed.sh`
  (affected tests). The full `flutter test` runs in CI before merge; run
  `dart run build_runner build --delete-conflicting-outputs` after changing drift tables.
- Never read, print or modify API keys or backend credentials (Keychain entries
  `api_key_*`, the auth session, `secrets.json`).
- The app requires an account; all user data lives on Supabase (RLS on every
  table) and drift is the offline cache with an outbox (constitution II). Local
  backend: `supabase start` in this repo (ports 5532x).
- Architecture and roadmap: `docs/architecture.md`, `docs/roadmap.md`.
- Product direction: `docs/product-design.md`; weekly/monthly Plan and linked
  Nabavka are central. 010 is specified, not implemented. Preserve old feature
  history and treat UX usability gates as release requirements.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:
`specs/010-plan-and-shopping/plan.md`
<!-- SPECKIT END -->
