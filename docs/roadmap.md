# Tavli roadmap

Each phase below becomes one or more Spec Kit features (`specs/NNN-name/`).
Spec numbers are assigned when a feature is specified, in the order it is started.

Last updated: 2026-10-30.

## Done (on `main`)

- **Phase 0 — project setup**: Flutter project for Android, iOS, macOS.
- **Phase 1 — foundation** (`specs/001-foundation-ai-router`): app shell with
  responsive tabs/rail, drift schema for all planned data, AI layer
  (OpenAI-compatible client, vision/text fallback chains, persisted cooldowns),
  `RecipeAI` (photo, dish name, refine), recipe domain model.
- **AI keys screen**: enter/check/delete Gemini, Groq, OpenRouter keys
  (Keychain/Keystore), compare chain models with the provider's model list,
  chain test that generates a sample recipe and shows the attempt log
  (the "Probaj AI" test was removed from the keys page on 2026-10-30).
- **Built-in Tavli AI keys** (`specs/002-builtin-ai-keys`): local gitignored
  `secrets.json` via `--dart-define-from-file`; own key first, built-in second
  per model; cooldowns per key. Cloudflare proxy remains a later phase.
- **Phase 2 — recipe screens** (`specs/003-recipe-screens`): recipe list with
  search and detail (list–detail on wide windows); add from a photo, a dish
  name or manually with a preview before saving; AI chat edits with version
  history, undo and restore; delete.
- **AI keys list** (`specs/004-ai-keys-list`): one generic "API ključ" field
  (service detected from the key), any number of keys per service, list of
  added keys with check/delete; keys used in order with per-key cooldowns.
- **Keep screen on while cooking** (`specs/007-keep-screen-on`): "Ne gasi ekran"
  toggle on the recipe screen, remembered in `AppSettings`.
- **Dev process**: Spec Kit, constitution, AGENTS.md, CLAUDE.md,
  `docs/flutter-best-practices.md`, strict lints, `scripts/check.sh`, git rules
  (branch from latest `main`, squash-merge, delete branch after merge).

## In progress

- **Hide built-in keys** (branch `fix/hide-builtin-keys`, PR #4): the keys page
  never shows built-in keys. Awaiting merge.
- **Themes & animations** (`005-themes-animations`, implemented locally, 194 tests, awaiting review): three themes — Bosiljak
  (default), Šafran, Borovnica — each light and dark, switchable in Profil
  (Svetla / Tamna / Kao sistem); recipe screens restyled; eight animations
  (photo scan chips, simmering pot, check → cart, full bag, empty fridge,
  pull-to-refresh spoon, meal plan plate, egg timer) plus a themed splash;
  respects reduced motion.

## Next

The account comes first: every feature, including the shopping list, is
available only after sign-up and sign-in, because all data is saved to the
account and shared per household.

1. **Account & login**: an account is required from first launch, because all
   data is saved to it. Passwordless sign-in: Sign in with Apple, Google, and
   email with a 6-digit code. Existing local data moves into the account once,
   on first sign-in. Profile (name, avatar), sign out, delete account in the
   app (store requirement), data export.
2. **Household (domaćinstvo)**: every user always belongs to one household; a
   personal one is created at sign-up, so "alone" and "with family" use the
   same model. Invite by link, 6-character code or QR (expires in 7 days,
   revocable); join with a confirmation screen; roles Vlasnik / Član; leave,
   remove a member, transfer ownership. Shared: shopping list, pantry, meal
   plan, recipes. Not shared: AI keys, theme, personal preferences.
3. **Sync**: drift stays the local source of truth (offline first); outbox for
   local changes, pull by cursor, realtime "something changed" per household,
   client-generated UUID v7, soft deletes, last write wins per field. Existing
   recipes (and photos) first. Backend: Supabase (auth, Postgres with Row Level
   Security, realtime, EU region) unless decided otherwise.
4. **Ingredient checklist → shopping list**: tick ingredients on a recipe and
   send the missing ones to a shopping list grouped by store category. Built
   shared per household and synced from the start.
5. **Pantry-based suggestions**: pantry (Ostava) management and AI suggestions
   for dishes from what is at home. Shared per household.
6. **Meal plan**: weekly or monthly plan with breakfast/lunch/dinner toggles,
   calendar view, lock/cooked flags, and shopping lists per plan (and per week
   for monthly plans). Shared per household.
7. **Preferences**: taste profile (diet, dislikes, allergies, household size)
   used in prompts. Personal, with household size taken from the household.
8. **Ratings & comfort food**: rate cooked dishes, mark comfort food, feed
   ratings back into suggestions and plans.
9. **AI models screen**: reorder/enable models in the chains, persisted in
   `AppSettings`.
10. **Cloudflare key proxy**: Worker that holds provider keys and forwards
    OpenAI-compatible requests; it verifies the user's account token and limits
    calls per user; the app drops built-in keys from `secrets.json`.
11. **Store release**: privacy policy and terms on the app domain, App Store
    privacy labels and privacy manifest, Google Play data safety form and web
    page for deletion requests, demo account for review, crash reporting,
    optional push notifications ("Ana added milk").

## Open decisions (account & household)

Proposal: <https://claude.ai/artifact/A9M8mfChMncTQW43DRVV6d>
Full plan with flows: <https://claude.ai/artifact/KLvzjyHrPn6HWjnDwFvF5z>

- Backend: Supabase (recommended), all Cloudflare, or Firebase.
- Sign-in methods: Apple + Google + email code (recommended).
- One household per user in the first version (recommended; schema allows more).
- Recipes shared by default with a "private" option.
- Whether members (not only the owner) can invite.
- App domain (for invite links, sign-in emails and the privacy policy).

Prerequisites before Account & login: domain, Apple Developer account, Supabase account.
