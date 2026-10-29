# Research: Built-in Tavli AI keys

## R1. How built-in keys get into the app

- **Decision**: `--dart-define-from-file=secrets.json`, read with `const String.fromEnvironment('GEMINI_API_KEY')` etc.
- **Rationale**: built into Flutter, no extra package, no asset in the bundle, file stays local and gitignored. Missing defines resolve to `''`, so tests and keyless builds just have no built-in keys.
- **Alternatives**: bundled asset `secrets.json` (ships as a readable file in the bundle — worse); `flutter_dotenv` (extra dependency, same exposure); `--obfuscate` alone (does not hide string constants).

## R2. Where the fallback between own and built-in key lives

- **Decision**: in `AIRouter`, as an inner loop over `KeySource.credentialsFor(provider)` for each model.
- **Rationale**: the router already owns all fallback decisions; trying the same (strongest) model with the second key before dropping to a weaker model gives better answers.
- **Alternatives**: duplicate every model in the chain per key (pollutes `ChainConfig` and the future "AI modeli" screen); fallback inside `ChatClient` (client would need cooldown knowledge).

## R3. Per-origin state

- **Decision**: pauses persisted per (provider, model, origin); rejected keys and missing models kept in memory per origin. `invalidProviders` keeps meaning "own key rejected" (used by the keys screen).
- **Rationale**: free-tier quotas are per key/project; a model can exist for one account and not another (OpenRouter).
- **Alternatives**: shared pause per model — would waste the built-in quota whenever the own key hits a limit.

## R4. Migration of `ModelStatuses`

- **Decision**: schema v2 drops and recreates `model_statuses` with `keyOrigin` in the primary key.
- **Rationale**: the table is only a cooldown/usage cache; the longest pause is about a day. Changing a SQLite primary key requires a table rebuild anyway.
- **Alternatives**: `TableMigration` copying rows with origin `user` — more code for data that expires within a day.

## R5. Future Cloudflare proxy

- **Decision**: keep `KeySource` as the seam. The proxy version adds a `KeyOrigin.proxy`-style credential whose requests go to the Worker; `BuiltInKeys` is then removed. Router logic stays the same.
- **Rationale**: matches the roadmap; avoids building proxy plumbing (base URL override) before it is needed.

## R6. Key file format

- **Decision**: flat JSON object with `GEMINI_API_KEY`, `GROQ_API_KEY`, `OPENROUTER_API_KEY`; `secrets.example.json` with empty strings is committed (whitelisted in `.gitignore`).
- **Rationale**: `--dart-define-from-file` requires a flat JSON object; empty strings mean "no built-in key" so copying the example unchanged is harmless.
