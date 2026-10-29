# Tavli architecture

## Layers

```mermaid
flowchart TD
  UI["UI — lib/app, lib/features/*<br/>(widgets, go_router, HomeShell)"]
  P["Riverpod providers — lib/providers.dart"]
  F["Feature façades — RecipeAI (fromImage, fromDishName, refine)"]
  D["Domain — lib/domain (Recipe, Ingredient, categories)<br/>pure Dart"]
  R["AIRouter — chains, cooldowns, retries"]
  C["ChatClient — OpenAICompatibleClient (dio)"]
  K["KeyStore — SecureKeyStore (Keychain / Keystore)"]
  S["ModelStatusStore — DriftModelStatusStore"]
  DB[("drift / SQLite — lib/data/database.dart")]

  UI --> P
  P --> F
  P --> DB
  F --> R
  F --> D
  R --> C
  R --> K
  R --> S
  S --> DB
  UI --> D
```

- **UI** reads state through Riverpod and never calls `ChatClient` or providers directly.
- **Domain** is pure Dart; `Recipe.fromAiJson` throws `FormatException` on bad AI output.
- **Data**: one drift database (`tavli`) with tables for recipes, recipe versions,
  pantry, shopping lists/items, meal plans/entries, ratings, user profile,
  app settings and model status. Lists inside rows (ingredients, steps, meal
  types) are stored as JSON text.

## Navigation

`StatefulShellRoute.indexedStack` with five tabs: Recepti, Plan, Ostava,
Kupovina, Profil. `HomeShell` shows a bottom `NavigationBar` below 720 px and a
`NavigationRail` at ≥720 px (extended at ≥1000 px). `/profile/ai-keys` is the
AI keys screen.

## AI router and fallback chains

```mermaid
flowchart LR
  REQ["AIRequest<br/>(system, prompt, images?)"] --> KIND{images?}
  KIND -- yes --> VC["Vision chain<br/>Gemini Pro → Groq Llama 4 Maverick →<br/>Gemini Flash → Gemini Flash-Lite →<br/>OpenRouter Gemma 3 (free)"]
  KIND -- no --> TC["Text chain<br/>Gemini Pro → Groq GPT-OSS 120B →<br/>Gemini Flash → Groq Llama 3.3 70B →<br/>Gemini Flash-Lite → OpenRouter Gemma 3 (free)"]
  VC --> LOOP
  TC --> LOOP
  subgraph LOOP["for each enabled model"]
    direction TB
    SKIP{"provider key invalid?<br/>model 404?<br/>no key?<br/>cooling down?"} -- yes --> NEXT[next model]
    SKIP -- no --> CALL["ChatClient.complete<br/>(1 quick retry on network/5xx)"]
    CALL --> PARSE{"parse JSON"}
    PARSE -- ok --> DONE["AIResult(value, model, attempts)"]
    PARSE -- FormatException --> RETRY["ask same model once more"] --> PARSE2{ok?}
    PARSE2 -- no --> NEXT
    PARSE2 -- yes --> DONE
    CALL -- "429" --> COOL["persist cooldown:<br/>Retry-After / 60 s / daily reset (08:00 UTC Gemini) / 1 h"] --> NEXT
    CALL -- "401/403/bad key" --> INV["mark provider invalid"] --> NEXT
    CALL -- "404" --> MISS["mark model unavailable"] --> NEXT
  end
  NEXT --> END["AllModelsExhausted(attempts, nextAvailableAt)"]
```

Key points:

- Chains live in `ChainConfig` (`defaults`), filtered by `enabled` and, for
  vision, `supportsVision`. The config is read through a function so the user
  can change it at runtime.
- Cooldowns and per-day request counts persist in the `ModelStatuses` table and
  survive restarts.
- Invalid providers / missing models are remembered in memory until
  `resetProvider` (called when the user saves a new key).
- Errors thrown by `parse` other than `FormatException`/`TypeError` (e.g.
  `NotARecipeException`) stop the chain and reach the UI.
- `aiErrorText` maps every error to a Serbian message.

## Secrets

Keys are entered by the user on the AI keys screen and stored with
`flutter_secure_storage` under `api_key_<provider>`. Nothing secret is in the
repo. Bundled default keys are an open decision (see `roadmap.md`).
