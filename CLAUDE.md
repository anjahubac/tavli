@AGENTS.md

# Claude Code notes

- `AGENTS.md` (imported above) is the canonical guide; the constitution in
  `.specify/memory/constitution.md` wins on conflicts.
- The user writes in Serbian. Reply in Serbian unless asked otherwise; all app UI
  text is Serbian (Latin script).
- Spec Kit slash commands are in `.claude/commands/` (`/speckit.specify`,
  `/speckit.clarify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.analyze`,
  `/speckit.implement`, `/speckit.constitution`).
- Run `flutter analyze` and `flutter test` before every commit; run
  `dart run build_runner build --delete-conflicting-outputs` after changing drift tables.
- Never read, print or modify API keys (Keychain entries `api_key_*`, `secrets.json`).
- Architecture and roadmap: `docs/architecture.md`, `docs/roadmap.md`.
