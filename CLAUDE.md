@AGENTS.md

# Claude Code notes

AGENTS.md is the operational entry point; `.specify/memory/constitution.md`
takes precedence. Follow `docs/development/ai-development.md` and the current
architecture in `docs/architecture.md`. Reply to the user in Serbian unless
asked otherwise. Write engineering documents in English; app UI copy is Serbian Latin.

The installed `.claude/skills/speckit-*` workflows use `.specify/` templates and
scripts. Set `SPECIFY_FEATURE_DIRECTORY` to the task's spec in this checkout;
verify it before running a workflow. The tracked feature pointer is not proof
of the active task. Feature creation does not create a Git branch here.
Normal branches start from current `origin/dev`; PRs target `dev`.

Read `docs/product-design.md`, `docs/product-plan.md` and the active spec.
010 has existing planning/shopping implementation and incomplete acceptance;
its `current-direction.md` records later product changes. Do not call the full
010 feature unimplemented or complete. Historical specs retain their evidence.

Use existing folders/providers; name changed files, contract owner and reviewer.
Never read secrets, hand-edit generated files, bypass checks or treat AI output
as trusted code/data. Use the shared quality matrix and report actual results.

<!-- SPECKIT START -->
Resolve the current plan from explicit `SPECIFY_FEATURE_DIRECTORY` in this
checkout. Read that spec's `spec.md`, `plan.md`, `tasks.md` and contracts before work.
<!-- SPECKIT END -->

Security work follows `docs/development/security.md` and spec 012. Findings are
source evidence, not proof of exploitation or completed remediation. Include
negative authorization/input tests and never use real secrets to reproduce issues.

Testing infrastructure is specified in `specs/013-testing-strategy/`; use
`docs/development/testing.md` and the critical journey matrix. Default unit/widget
suites are network-free; only the explicitly invoked guarded local-backend lane
may contact ephemeral local Supabase with synthetic accounts and fake AI.
All roadmap specs are indexed in `specs/README.md`; source tasks map through
`docs/development/source-task-map.md`. Release/operations use spec 033. Drafts
need their recorded decisions before dependent code; never treat them as shipped.
