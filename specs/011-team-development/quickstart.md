# Start a task using these standards

1. Open [architecture](../../docs/architecture.md) and
   [team workflow](../../docs/development/team-workflow.md); identify your task owner.
2. Find the task in [delivery register](contracts/delivery-backlog.md) and its
   feature preparation key in [product plan](../../docs/product-plan.md).
3. Reserve a spec number, create a branch/worktree from latest dev and select
   its feature explicitly. Do not redirect another worktree's tracked pointer.
4. Clarify blocking product/privacy decisions. Merge producer contracts before
   consumers; prepare fakes where independent work can proceed.
5. Fill spec/plan/tasks from the project templates and run the analysis pass.
   Put scope, review, data/schema and test evidence in the PR.
6. For a documentation change, run:

```bash
python3 scripts/check-docs.py
git diff --check
```

For app/backend changes, use [quality gates](../../docs/development/quality-gates.md)
and the existing pre-commit hook. A successful document check proves links and
register integrity, not application acceptance, correct RLS or balanced workload.
