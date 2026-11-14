# Testing quickstart

## Commands that exist now

```bash
flutter pub get
scripts/check.sh
flutter test
flutter test test/domain/shopping_demand_test.dart
scripts/test-changed.sh origin/dev
flutter test --coverage
python3 scripts/check-docs.py
```

Affected selection compares committed branch changes against origin/dev; without
an argument it reads staged paths, not all uncommitted edits. Do not use an empty
selection as proof that a dirty working tree was tested. Full Flutter is the PR gate.

Local SQL requires Docker and the repository-local Supabase stack. Confirm the
local target before using reset; never point these commands at a hosted project:

```bash
supabase start
supabase db reset
supabase test db
```

## Proposed commands, not implemented

The implementation will add explicit integration/local-backend entry scripts
with endpoint guards, deterministic fixtures and cleanup. Do not run a guessed
integration target or claim its success until the harness/dependency exists.
The plan justifies the SDK integration_test dependency; no package is added now.

Native permissions/deep links, real secure storage and wake lock need device
proof beyond fake/widget tests. Capture build SHA/device and redacted results.
See [journey matrix](contracts/journey-matrix.md) and the security 012 matrix.
