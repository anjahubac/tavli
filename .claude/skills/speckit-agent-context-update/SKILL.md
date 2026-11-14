---
name: speckit-agent-context-update
description: Refresh the managed Spec Kit section in the coding agent context file
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: github-spec-kit
  source: agent-context:commands/speckit.agent-context.update.md
---

## Tavli project policy

The repository constitution and AGENTS.md override generic examples below. Read
`docs/architecture.md` and the active spec selected by `SPECIFY_FEATURE_DIRECTORY`.
Use current Tavli templates and existing Flutter folders, English engineering
prose and Serbian Latin UI copy. Domain/AI parsing/router tests and applicable
local two-account access tests are mandatory, even if generic text calls tests
optional. Reuse the existing checkout with one active writer; create additional
worktrees/clones only when explicitly requested. Start normal branches from origin/dev, name owners
and independent human reviewers, and coordinate shared contracts/migrations.
Feature-file creation here does not create a Git branch. Never rewrite completed
spec history or claim planned infrastructure exists. See
`docs/development/ai-development.md` for evidence and handoff requirements.


# Update Coding Agent Context

Refresh the managed Spec Kit section inside the active coding agent's context/instruction file (e.g. `CLAUDE.md`, `.github/copilot-instructions.md`, `AGENTS.md`).

## Behavior

The script reads the agent-context extension config at
`.specify/extensions/agent-context/agent-context-config.yml` to discover:

- `context_file` — the path of the coding agent context file to manage.
- `context_markers.start` / `.end` — the delimiters surrounding the managed section. Defaults to `<!-- SPECKIT START -->` and `<!-- SPECKIT END -->` when the field is missing.

It then creates, replaces, or appends the managed block so that the section points at the most recent plan path when one can be discovered (`specs/<feature>/plan.md`).

If `context_file` is empty or the file cannot be located, the command reports nothing to do and exits successfully.

## Execution

- **Bash**: `.specify/extensions/agent-context/scripts/bash/update-agent-context.sh [plan_path]`
- **PowerShell**: `.specify/extensions/agent-context/scripts/powershell/update-agent-context.ps1 [plan_path]`

When `plan_path` is omitted, the script auto-detects the most recently modified `specs/*/plan.md`.