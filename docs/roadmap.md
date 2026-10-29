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

## Next

1. **Phase 2 — recipe screens**: recipe list and detail; add a recipe from a
   photo (camera/gallery), from a dish name, or manually; edit via chat with
   the AI (`refine`) and keep previous versions (`RecipeVersions`) for undo.
2. **Ingredient checklist → shopping list**: tick ingredients on a recipe and
   send the missing ones to a shopping list grouped by store category.
3. **Pantry-based suggestions**: pantry (Ostava) management and AI suggestions
   for dishes from what is at home.
4. **Meal plan**: weekly or monthly plan with breakfast/lunch/dinner toggles,
   calendar view, lock/cooked flags, and shopping lists per plan (and per week
   for monthly plans).
5. **Preferences**: taste profile (diet, dislikes, allergies, household size)
   used in prompts.
6. **Ratings & comfort food**: rate cooked dishes, mark comfort food, feed
   ratings back into suggestions and plans.
7. **AI models screen**: reorder/enable models in the chains, persisted in `AppSettings`.
8. **Cloudflare key proxy** (after the app is feature-complete): Worker that
   holds provider keys and forwards OpenAI-compatible requests; app drops
   built-in keys from `secrets.json`.
