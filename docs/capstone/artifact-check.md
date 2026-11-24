# Build artifact and clean-clone check (CAP-06, CAP-07)

Recorded on 2026-11-24 from a fresh clone of `dev` at `216a9abd`, on macOS
with Flutter 3.50.0. It covers one platform and one commit. It does not cover
Android, iOS, Windows or the hosted project.

## README steps from a clean clone

| Step | Result |
| --- | --- |
| `flutter pub get` | Dependencies resolved |
| `scripts/check.sh` | "No issues found" from `flutter analyze` |
| `flutter test` | 1484 passed, 1 skipped, 0 failed |
| `deno test supabase/functions` | 143 passed, 0 failed |
| `flutter build macos --release --dart-define-from-file=secrets.json` | Exit 0, `tavli.app` 63.1 MB |

`supabase start` was not run in this check. `secrets.json` held only a local
URL (`http://127.0.0.1:55321`) and a placeholder anon key, because the README's
`cp -n secrets.example.json secrets.json` produces empty values.

## Key-free artifact

Three canary provider keys were exported in the shell that ran the build
(`GROQ_API_KEY`, `GEMINI_API_KEY`, `OPENROUTER_API_KEY`). The built
`tavli.app` (66 files) was then searched with `grep -rlaE`.

| Search | Files found |
| --- | --- |
| Positive control: the anon placeholder passed with `--dart-define-from-file` | 1 (`Contents/Frameworks/App.framework/Versions/A/App`) |
| The three canary values | 0 |
| `gsk_…`, `AIza…`, `sk-or-v1-…`, `sk-proj-…`, `sk-ant-…` key shapes | 0 |
| JWT shape `eyJ….eyJ`, and the text `service_role` | 0 |
| Any file named `secrets*` inside the bundle | 0 |

The positive control shows the search can find a value that was compiled in.
It means a provider key in the environment or the shared-key path does not
reach the app binary. It does not prove that a future build is clean, and it
does not cover keys from older builds, which still need rotation (see
[security.md](../development/security.md)).

## Not covered

- Other platforms and the signed distribution artifact.
- The hosted Supabase project and its auth settings (SEC-05).
- The CI gate before deploy (SEC-08).
