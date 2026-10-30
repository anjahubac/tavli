# Tavli roadmap

Each phase below becomes one or more Spec Kit features (`specs/NNN-name/`).

## Done

- **Phase 0 — project setup**: Flutter project for Android, iOS, macOS.
- **Phase 1 — foundation** (`specs/001-foundation-ai-router`): app shell with
  responsive tabs/rail, drift schema for all planned data, AI layer
  (OpenAI-compatible client, vision/text fallback chains, persisted cooldowns),
  `RecipeAI` (photo, dish name, refine), recipe domain model.
- **AI keys screen**: enter/check/delete Gemini, Groq, OpenRouter keys
  (Keychain/Keystore), compare chain models with the provider's model list,
  chain test that generates a sample recipe and shows the attempt log.
- **Built-in Tavli AI keys** (`specs/002-builtin-ai-keys`): local gitignored
  `secrets.json` via `--dart-define-from-file`; own key first, built-in second
  per model; cooldowns per key. Cloudflare proxy remains the final phase.
- **Phase 2 — recipe screens** (`specs/003-recipe-screens`): recipe list with
  search and detail (list–detail on wide windows); add from a photo, a dish
  name or manually with a preview before saving; AI chat edits with version
  history, undo and restore; delete.
- **AI keys list** (`specs/004-ai-keys-list`): one generic "API ključ" field
  (service detected from the key), any number of keys per service, list of
  added keys with check/delete; keys used in order with per-key cooldowns.

## Next

1. **Ingredient checklist → shopping list**: tick ingredients on a recipe and
   send the missing ones to a shopping list grouped by store category.
2. **Pantry-based suggestions**: pantry (Ostava) management and AI suggestions
   for dishes from what is at home.
3. **Meal plan**: weekly or monthly plan with breakfast/lunch/dinner toggles,
   calendar view, lock/cooked flags, and shopping lists per plan (and per week
   for monthly plans).
4. **Preferences**: taste profile (diet, dislikes, allergies, household size)
   used in prompts.
5. **Ratings & comfort food**: rate cooked dishes, mark comfort food, feed
   ratings back into suggestions and plans.
6. **AI models screen**: reorder/enable models in the chains, persisted in `AppSettings`.
7. **Cloudflare key proxy** (after the app is feature-complete): Worker that
   holds provider keys and forwards OpenAI-compatible requests; app drops
   built-in keys from `secrets.json`.
