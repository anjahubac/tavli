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
  K["KeySource — LayeredKeySource<br/>own key (Keychain / Keystore) → built-in (secrets.json)"]
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
- **Recipes** (spec 003): `RecipeRepository` (`lib/data/recipe_repository.dart`)
  owns recipe rows and versions. Every change (AI, manual, restore) stores the
  *previous* state in `RecipeVersions` with `changeKind`/`instruction`/`changedBy`
  (max 30 per recipe); undo applies and deletes the newest version, restore keeps
  the current state as a new version. Photos are downscaled to JPEG (≤ 1600 px)
  in an isolate and stored as files under `<documents>/recipe_photos/`; the DB
  keeps the relative path (`RecipePhotoStore`).

## Navigation

`StatefulShellRoute.indexedStack` with five tabs: Recepti, Plan, Ostava,
Kupovina, Profil. `HomeShell` shows a bottom `NavigationBar` below 720 px and a
`NavigationRail` at ≥720 px (extended at ≥1000 px). `/profile/ai-keys` is the
AI keys screen.

Recipe routes: `/recipes` (list), `/recipes/new/{name,photo,manual}`,
`/recipes/:id` (detail), `/recipes/:id/edit`, `/recipes/:id/chat`. When the
content area is ≥ 840 px wide, `/recipes/:id` shows the list and the recipe side
by side (`RecipeRoute`), otherwise the detail is a full screen.

## AI router and fallback chains

```mermaid
flowchart LR
  REQ["AIRequest<br/>(system, prompt, images?)"] --> KIND{images?}
  KIND -- yes --> VC["Vision chain<br/>Gemini Pro → Groq Llama 4 Maverick →<br/>Gemini Flash → Gemini Flash-Lite →<br/>OpenRouter Gemma 3 (free)"]
  KIND -- no --> TC["Text chain<br/>Gemini Pro → Groq GPT-OSS 120B →<br/>Gemini Flash → Groq Llama 3.3 70B →<br/>Gemini Flash-Lite → OpenRouter Gemma 3 (free)"]
  VC --> LOOP
  TC --> LOOP
  subgraph LOOP["for each enabled model × each key (own, then built-in)"]
    direction TB
    SKIP{"this key rejected?<br/>model 404 for this key?<br/>no key?<br/>this key cooling down?"} -- yes --> NEXT[next key, then next model]
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
- For each model the router tries every credential from `KeySource` in order
  (own key, then built-in Tavli key) before moving to the next model.
- Cooldowns and per-day request counts persist in the `ModelStatuses` table
  per (provider, model, key origin) and survive restarts.
- Rejected keys / missing models are remembered in memory per key origin.
  `invalidProviders` reports only rejected *own* keys; `resetProvider`
  (called when the user saves a new key) clears own-key state only.
- Errors thrown by `parse` other than `FormatException`/`TypeError` (e.g.
  `NotARecipeException`) stop the chain and reach the UI.
- `aiErrorText` maps every error to a Serbian message.

## Secrets

Keys are entered by the user on the AI keys screen and stored with
`flutter_secure_storage` under `api_key_<provider>`. Nothing secret is in the
repo.

Built-in keys (spec 002) come from a local, gitignored `secrets.json` passed
with `--dart-define-from-file=secrets.json` (see `secrets.example.json`), read
by `BuiltInKeys.fromEnvironment()`. User-entered keys take priority. The
built-in key is never shown in the UI. Later a Cloudflare Worker proxy replaces
`BuiltInKeys` behind the same `KeySource` seam, so the app ships without keys.
