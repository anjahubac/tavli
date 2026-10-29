# Feature Specification: Foundation — app shell, database and AI router

**Feature Branch**: `001-foundation-ai-router` (implemented on `feat/foundation-ai-router`)
**Created**: 2026-10-30 (backfilled from commits `daf701e`, `594438c`)
**Status**: Implemented
**Input**: "Set up the app skeleton, local database and an AI layer that uses free
Gemini/Groq/OpenRouter tiers with automatic fallback, plus a screen to enter AI keys."

> All UI text is Serbian (Latin script). Quoted strings below are the exact UI copy.

## User Scenarios & Testing

### User Story 1 — Navigate the app on phone and desktop (P1)

The user opens Tavli and sees five sections: "Recepti", "Plan", "Ostava",
"Kupovina", "Profil". Sections not built yet show "Uskoro".

**Independent test**: launch at phone width and at desktop width.

**Acceptance scenarios**
1. **Given** a window narrower than 720 px, **when** the app opens, **then** a bottom tab bar shows the five tabs and "Recepti" is selected.
2. **Given** a phone layout, **when** the user taps "Ostava", **then** the Ostava screen is shown.
3. **Given** a window ≥ 720 px wide, **when** the app opens, **then** a side navigation rail is shown instead of bottom tabs (extended at ≥ 1000 px).

### User Story 2 — Enter and check AI keys (P1)

From "Profil" → "AI ključevi" the user enters a key for Gemini, Groq and/or
OpenRouter. Keys are stored only on the device in the system secure store. The
screen explains: "Ključevi se čuvaju samo na ovom uređaju, u sistemskom sigurnom
skladištu. Dovoljan je jedan, a sa više ključeva Tavli ima rezervu kad se
potroši besplatni limit."

**Acceptance scenarios**
1. **Given** no key, **when** the user saves a valid key, **then** it is stored and checked by listing the provider's models; chain models found/missing for that key are shown.
2. **Given** a wrong key, **when** it is checked, **then** a clear Serbian message is shown ("Ključ nije ispravan ili je opozvan.").
3. **Given** a saved key, **when** the user deletes it, **then** it is removed from secure storage.
4. **Given** at least one key, **when** the user runs the chain test with a dish name (default "palačinke"), **then** a sample recipe is generated, nothing is saved, and the attempt log shows which models were tried and which answered.

### User Story 3 — Resilient AI on free tiers (P1, no UI of its own)

Any AI task (recipe from photo, from dish name, refine by instruction) keeps
working when individual models hit rate limits, keys are invalid, or models disappear.

**Acceptance scenarios**
1. **Given** the first model in the chain answers, **then** no other model is called.
2. **Given** a 429 from Gemini Pro, **then** the router moves to the next model and the cooldown is persisted.
3. **Given** a paused model, **then** it is skipped until its pause expires, also after restart.
4. **Given** a daily limit on Gemini, **then** it is paused until the next 08:00 UTC; a minute limit without Retry-After pauses 60 s.
5. **Given** a rejected key, **then** all models of that provider are skipped; a provider with no key is skipped silently.
6. **Given** a 404 model, **then** it is not called again.
7. **Given** invalid JSON, **then** the same model is asked once more, then the next model.
8. **Given** an image task, **then** only vision-capable models are used.
9. **Given** the parser rejects the content as non-recipe, **then** the chain stops and the user sees "Na slici nije pronađen recept."
10. **Given** every model is exhausted, **then** the user sees "Svi besplatni limiti su potrošeni. Pokušaj ponovo posle HH:MM." or "Nijedan model nije dostupan. Proveri ključeve."

### Edge cases

- AI returns JSON wrapped in a ```json block or surrounded by text → extracted.
- Quantities as fractions ("1/2") or with comma decimals → parsed; unknown category → "ostalo".
- Recipe with no title or no ingredients → treated as invalid output.
- Network error or 5xx → one quick retry on the same model before the router decides.

## Requirements

### Functional

- **FR-001**: App MUST provide five top-level sections with responsive navigation (bottom tabs < 720 px, rail ≥ 720 px).
- **FR-002**: App MUST store all data locally in a drift database with tables for recipes, recipe versions, pantry items, shopping lists/items, meal plans/entries, ratings, user profile, app settings and model statuses.
- **FR-003**: AI calls MUST use one OpenAI-compatible client for Gemini, Groq and OpenRouter with JSON-object responses.
- **FR-004**: AI calls MUST go through a router with separate vision and text chains, ordered by strength and user-adjustable at runtime.
- **FR-005**: Router MUST persist per-model cooldowns and daily request counts.
- **FR-006**: HTTP errors MUST map to typed errors (rate limit with retry-after/daily flag, auth, model not found, transient, bad request, invalid output).
- **FR-007**: Keys MUST be stored in Keychain/Keystore only; the user can save, check and delete per provider.
- **FR-008**: `RecipeAI` MUST support recipe from image, from dish name (servings, notes) and refine with an instruction, stamping the answering model's label.
- **FR-009**: All user-visible errors MUST be Serbian messages.

### Key entities

- **ModelSpec** — provider, model id, label, vision support, enabled, daily reset hour.
- **ChainConfig** — vision and text lists of ModelSpec.
- **Recipe / Ingredient** — title, servings, prep time, ingredients (name, quantity, unit, category, note), steps, source (photo/ai/manual), image path, answeredBy.
- **ModelStatus** — provider+model, blockedUntil, requestsToday, usageDay, lastError.

## Success criteria

- **SC-001**: With one valid key, a sample recipe is produced from the chain test.
- **SC-002**: Router behaviour scenarios 1–10 are covered by automated tests (no network).
- **SC-003**: `flutter analyze` clean, `flutter test` green (33 tests).
