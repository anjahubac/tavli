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

## Next

1. **Default built-in keys** — *decided 2026-10-30*:
   - **Now (A)**: keys live locally in a gitignored `secrets.json`, injected at
     build time via `flutter run/build --dart-define-from-file=secrets.json`.
     User keys from the AI keys screen take precedence over built-in ones.
   - **Later (B)**: once the app is tested and feature-complete, move the keys
     to a Cloudflare Worker proxy so no key ships in the app binary. Keep the
     `KeyStore`/`ChatClient` seam so this is a client-side swap of base URL and
     auth, not a rewrite of the router.
2. **Phase 2 — recipe screens**: recipe list and detail; add a recipe from a
   photo (camera/gallery), from a dish name, or manually; edit via chat with
   the AI (`refine`) and keep previous versions (`RecipeVersions`) for undo.
3. **Ingredient checklist → shopping list**: tick ingredients on a recipe and
   send the missing ones to a shopping list grouped by store category.
4. **Pantry-based suggestions**: pantry (Ostava) management and AI suggestions
   for dishes from what is at home.
5. **Meal plan**: weekly or monthly plan with breakfast/lunch/dinner toggles,
   calendar view, lock/cooked flags, and shopping lists per plan (and per week
   for monthly plans).
6. **Preferences**: taste profile (diet, dislikes, allergies, household size)
   used in prompts.
7. **Ratings & comfort food**: rate cooked dishes, mark comfort food, feed
   ratings back into suggestions and plans.
8. **AI models screen**: reorder/enable models in the chains, persisted in `AppSettings`.
9. **Cloudflare key proxy** (after the app is feature-complete): Worker that
   holds provider keys and forwards OpenAI-compatible requests; app drops
   built-in keys from `secrets.json`.
