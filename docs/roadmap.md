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
  chain test that generates a sample recipe and shows the attempt log.
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
- **Hide built-in keys** (PR #4): the keys page never shows built-in keys;
  "Probaj AI" removed from the keys page.
- **Dev process**: Spec Kit, constitution, AGENTS.md, CLAUDE.md,
  `docs/flutter-best-practices.md`, strict lints, `scripts/check.sh`, git rules
  (branch from latest `main`, squash-merge, delete branch after merge).

## In progress

- **005 Themes & animations** (`005-themes-animations`, implemented locally,
  awaiting review): three themes — Bosiljak (default), Šafran, Borovnica — each
  light and dark, switchable in Profil (Svetla / Tamna / Kao sistem); recipe
  screens restyled; eight animations (photo scan chips, simmering pot, check →
  cart, full bag, empty fridge, pull-to-refresh spoon, meal plan plate, egg
  timer) plus a themed intro; respects reduced motion.
- **006a Account & login + server storage** (`006-account-login`, implemented
  locally, awaiting review): email-code sign-in, personal household, mandatory
  name, all user data saved to Supabase with an offline outbox, download on
  any device, one-time move of local data, sign-out, delete account, session
  renewal. 006b (Apple and Google) follows; see below.
- **007 Keep screen on** (`007-keep-screen-on`, PR #6, awaiting review): "Ne gasi
  ekran" toggle on a recipe keeps the display awake while cooking.

## Next

An account is required to use the app, so the account comes first: every
feature, including the shopping list, is available only after sign-in, and all
of the user's data is always saved to the server under the account (constitution
2.0.0, principle II). drift stays the local offline cache.

1. **006 Account & login + server storage of all the user's data**
   - **006a — email code** (`specs/006-account-login`): sign-in right after the
     intro with a 6-digit email code; session in Keychain/Keystore; personal
     household ("Moje domaćinstvo", role Vlasnik) created at sign-up; mandatory
     name step "Kako da te zovemo?"; profile with initials avatar. All user data
     (recipes with versions and photos, shopping lists, pantry, meal plans,
     ratings, preferences) stored on Supabase (EU, RLS on every table, explicit
     grants): local write + outbox, upload when online, download on sign-in on
     any device. Data from before accounts moves into the account once. Sign-out
     keeps all data (server and per-account device cache); AI keys stay on the
     device. Delete account in the app (simple dialog with a red "Obriši nalog")
     deletes server and device data and the user's AI keys.
   - **006b — Apple and Google**: Sign in with Apple and Google (after the Apple
     Developer account).
2. **007 Keep screen on** (PR #6): see In progress.
3. **008 Household invites & roles**: invite by link, 6-character code or QR
   (expires in 7 days, revocable); join with a confirmation screen; roles
   Vlasnik / Član; leave, remove a member, transfer ownership. Shared: shopping
   list, pantry, meal plan, recipes. Not shared: AI keys, theme, personal
   preferences.
4. **009 Realtime sharing between members**: realtime "something changed" per
   household so members see each other's changes without restarting; conflict
   handling for simultaneous edits by several people or devices (last write
   wins per field instead of per record, soft deletes, UUID v7 ordering).
5. **Ingredient checklist → shopping list**: tick ingredients on a recipe and
   send the missing ones to a shopping list grouped by store category. Built
   shared per household and stored on the server from the start.
6. **Pantry-based suggestions**: pantry (Ostava) management and AI suggestions
   for dishes from what is at home. Shared per household.
7. **Meal plan**: weekly or monthly plan with breakfast/lunch/dinner toggles,
   calendar view, lock/cooked flags, and shopping lists per plan (and per week
   for monthly plans). Shared per household.
8. **Preferences**: taste profile (diet, dislikes, allergies, household size)
   used in prompts. Personal, with household size taken from the household.
9. **Ratings & comfort food**: rate cooked dishes, mark comfort food, feed
   ratings back into suggestions and plans.
10. **AI models screen**: reorder/enable models in the chains, persisted in
    `AppSettings`.
11. **Cloudflare key proxy**: Worker that holds provider keys and forwards
    OpenAI-compatible requests; it verifies the user's account token and limits
    calls per user; the app drops built-in keys from `secrets.json`.
12. **Store release**: privacy policy and terms on the app domain, App Store
    privacy labels and privacy manifest, Google Play data safety form and web
    page for deletion requests, demo account for review, data export, crash
    reporting, optional push notifications ("Ana added milk").

## Decisions (account & household)

Proposal: <https://claude.ai/artifact/A9M8mfChMncTQW43DRVV6d>
Full plan with flows: <https://claude.ai/artifact/KLvzjyHrPn6HWjnDwFvF5z>

Decided (2026-10-30):

- Backend: Supabase (Auth, Postgres with RLS, Storage), EU region. Local
  development with `supabase start` in this repo (ports 5532x).
- Account mandatory; all user data on the server, drift as offline cache with an
  outbox; sign-out keeps data; deletion only by the user (item or account).
- Sign-in methods: email code (006a), Apple + Google (006b).
- One household per user in the first version (schema allows more).
- AI keys stay on the device on sign-out, deleted on account deletion.

Still open:

- Recipes shared by default with a "private" option (008).
- Whether members (not only the owner) can invite (008).
- App domain (for invite links, sign-in emails and the privacy policy).

Prerequisites: Supabase account and EU project (006a), app domain and a custom
email sender (before release), Apple Developer account (006b).
