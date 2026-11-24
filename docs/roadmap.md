# Tavli roadmap

Updated 2026-11-13; status sections brought up to date with `dev` `ebcd794` on
2026-11-24. Original baseline: `main` `1eca2c3`; `dev` `207c94c`.
See [product plan](product-plan.md), [architecture](architecture.md) and
[Spec Kit index](../specs/README.md). This replaces old expiry/Cloudflare/four-tab
future directions; completed acceptance history remains intact.

## Current code

001–004 provide shell, AI/keys and recipe workflows. 005 themes/animations,
006 account/server/offline sync and 007 keep-screen-on are in the baseline.
010 has implementation for plan generation/review/calendar and plan/recipe
shopping, including snapshots, source contributions and supply allocation.
Its full UX/pantry/preferences/cooking acceptance is unfinished.

Navigation has five tabs (Plan, Nabavka, Početna, Recepti, Ostava); profile is
behind the avatar. Home (`/home`) is the default.

Implemented on `dev` since the original baseline (code evidence; each spec's
acceptance review is tracked in the [spec index](../specs/README.md)):

- **AI:** Edge gateway with per-user quotas and a configurable provider order
  (015); app builds carry no shared provider keys; own keys for Gemini, Groq,
  OpenRouter and OpenAI with a paid-first or free-first order; strict response
  validation and bounded repair (014); AI recipe images in the background.
- **Data:** drift schema 14; calendar days as server `date` columns (016);
  reviewed ingredient catalog with aliases, base-unit conversion, nutrition
  reference values and allergen groups (018, read-only on the client); recipe
  labels, filters and meal placement rules (019).
- **Household:** onboarding step, invitation by link, QR or code, join with
  optional recipe transfer, departure and removal, photo cleanup (008); realtime
  invalidation signals (009); ratings, favorites, tastes and allergen selections;
  member tastes feed plan generation through `planning-inputs`.
- **Everyday flows:** Home with today's meals, cook and undo, notices (021);
  cooking mode with step timers; Ostava with add, edit, remove and photo
  recognition (022); "Šta da skuvam?" from the pantry; add a recipe to the plan;
  pantry consumption and undo through cooked events.
- **Knowledge and input:** household cookbooks with sourced answers (026); voice
  recipe drafting (027); fasting and holiday questions and fasting plans (035,
  partial).
- **Platforms and UI:** local `packages/tavli_ui` library and gallery (031);
  Windows runner, title bar, MSIX and CI build (028); Linux GTK runner and CI
  build (034, device evidence pending).

Not implemented: nutrition diary, targets and calorie strip (only reference
values and per-recipe calculation exist), store prices and basket comparison,
receipt QR, cycle hints, nutritionist plan import, allergen filtering inside plan
generation, website download links and public store distribution. Open pull
requests at this date cover semantic recipe search and store basket comparison;
they are not part of `dev`.
This is code evidence, not a declaration of production QA or successful tests.

## Next deliveries

1. Foundation: active defects, contracts, strict AI/schema, Edge gateway spike,
   calendar dates, kitchen units, shared-file refactor, meal tags/snacks/rules,
   current-design UI standards and Home navigation. *Status:* gateway, response
   validation, calendar dates, meal tags/snacks/rules, the UI standard and Home
   navigation are on `dev`; kitchen units are partial (base-unit conversion and
   versioned factors are in; measure aggregation acceptance is pending).
2. Catalog: identity/aliases/conversions, reviewed seed/matcher/backfill,
   unresolved UI and nutrition provenance. Household invites/roles (008),
   preferences and Home/cooking can proceed against approved contracts.
   *Status:* the catalog, seed, matcher, recipe links, invitations/roles,
   preferences, Home and cooking are on `dev`; household catalog writes are not.
3. Catalog consumers: shopping/pantry, nutrition per portion, allergies/favorites,
   plan inputs and realtime invalidation (009), preserving the existing ledger.
   *Status:* pantry CRUD, explicit transfer, consume/undo, live pantry coverage,
   favorites in plan inputs and realtime are on `dev`; nutrition per portion has a
   calculation but no screen, and allergen-safe plans are not done.
4. Extensions: prices/QR spike, cookbook RAG, fasts and holidays (035),
   personal tracker, voice, Linux desktop support, calorie strip and store-ready
   website links. Split large work and review remaining effort by person/phase.
   Counts are not capacity estimates. *Status:* cookbook RAG, voice and
   ratings are on `dev`; fasting is partial; Windows and Linux build in CI;
   prices, receipt QR, tracker, calorie strip and website links are not started
   or still in review.
5. Cycle: opt-in device-only data, approved hints and local indicator.
6. Nutritionist import: reviewed image/text then PDF/alternatives/repeats;
   preserve grams, original wording and locked meals.

The local UI package exists (031). Apple/Google sign-in,
recipe media separation and store release are separate features; existing email
code and original-photo behavior remain usable meanwhile.

## Evidence and team setup

The [87-ticket register](../specs/011-team-development/contracts/delivery-backlog.md)
records source order/phase/owner and links into feature preparation. It does not
mark source tasks finished. Statuses are Proposed, Clarification needed, Ready,
In progress, In review, Integrated and Released, with blockers recorded separately.

Before parallel work: agree producer contracts, reserve spec numbers, verify
reviewer GitHub identities and protect dev/main where the account plan supports
it. CI runs Deno tests of the Edge Functions, format and analyze, all Flutter
tests (including the `tavli_ui` image tests), Windows and Linux builds, documentation
and script tests; pgTAP (`supabase test db`) still runs only locally, and macOS smoke
is manual. The Windows and Linux build jobs do not replace real-machine acceptance.
No deployment, credential change or Trello reassignment is part of this revision.

## Security track (012)

Additional cross-cutting work requested after the source plan: see
[security assessment](development/security.md) and
[012 tasks](../specs/012-security-baseline/tasks.md). Fix high-priority file/error
boundaries, collect release evidence for the gateway cutover (the client no longer
carries shared keys) and gate backend deployment on local security evidence before
affected release. Isolation/storage, auth/deletion and
future household/RAG/privacy tests accompany their feature slices. These are
open tasks, not completed hardening or changes to the 87 imported cards.

## Specifications prepared — 2026-11-14

All 87 source cards now map to focused requirements and implementation tasks in
[the source mapping](development/source-task-map.md). The [spec index](../specs/README.md)
allocates 001–033. Testing 013 and release/operations 033 add shared delivery work;
new runtime specs remain drafts where product, source or platform decisions are
open. No features are marked complete by this preparation.
