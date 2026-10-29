# Data Model: Built-in Tavli AI keys

## KeyOrigin (enum, Dart)

| Value | Meaning | UI label |
|---|---|---|
| `user` | key saved by the user (Keychain/Keystore) | (none; default) |
| `builtIn` | key compiled in from `secrets.json` | "Tavli AI" |

Persisted by `name` (`user`, `builtIn`).

## ApiCredential (value object, Dart)

| Field | Type | Notes |
|---|---|---|
| provider | `AIProvider` | |
| value | `String` | never logged, never displayed; `toString` omits it |
| origin | `KeyOrigin` | |

## BuiltInKeys (Dart)

Map `AIProvider → String`, empty values dropped. `fromEnvironment()` reads
`GEMINI_API_KEY`, `GROQ_API_KEY`, `OPENROUTER_API_KEY`.

## ModelStatuses (drift table) — schema v2

| Column | Type | Change |
|---|---|---|
| provider | text | PK |
| model | text | PK |
| keyOrigin | text, default `'user'` | **new**, PK |
| blockedUntil | datetime? | |
| requestsToday | int, default 0 | |
| usageDay | text? (yyyy-mm-dd) | |
| lastError | text? | |

Primary key: (provider, model, keyOrigin).

**Migration 1 → 2**: drop and recreate `model_statuses` (cache only; see research R4).

## Router in-memory state

- `_invalidKeys`: set of `provider/origin`
- `_unavailableModels`: set of `provider/model/origin`
- `invalidProviders` getter: providers whose **own** key is rejected
