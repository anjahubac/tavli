# Tavli roadmap

Updated 2026-11-13. Baseline: `main` `1eca2c3`; `dev` `207c94c`.
See [product plan](product-plan.md), [architecture](architecture.md) and
[Spec Kit index](../specs/README.md). This replaces old expiry/Cloudflare/four-tab
future directions; completed acceptance history remains intact.

## Current code

001–004 provide shell, AI/keys and recipe workflows. 005 themes/animations,
006 account/server/offline sync and 007 keep-screen-on are in the baseline.
010 has implementation for plan generation/review/calendar and plan/recipe
shopping, including snapshots, source contributions and supply allocation.
Its full UX/pantry/preferences/cooking acceptance is unfinished.

Current navigation has four tabs (Plan, Nabavka, Recepti, Ostava); profile is
behind the avatar. Home is not implemented; pantry has repository/receipt
support but placeholder UI. drift is version 5. Catalog, member invitations,
tracker, prices, voice, cookbooks and Windows are not implemented here.
This is code evidence, not a declaration of production QA or successful tests.

## Next deliveries

1. Foundation: active defects, contracts, strict AI/schema, Edge gateway spike,
   calendar dates, kitchen units, shared-file refactor, meal tags/snacks/rules,
   current-design UI standards and Home navigation.
2. Catalog: identity/aliases/conversions, reviewed seed/matcher/backfill,
   unresolved UI and nutrition provenance. Household invites/roles (008),
   preferences and Home/cooking can proceed against approved contracts.
3. Catalog consumers: shopping/pantry, nutrition per portion, allergies/favorites,
   plan inputs and realtime invalidation (009), preserving the existing ledger.
4. Extensions: prices/QR spike, cookbook RAG, personal tracker, voice, Windows,
   calorie strip and store-ready website links. Split large work and review
   remaining effort by person/phase; counts are not capacity estimates.
5. Cycle: opt-in device-only data, approved hints and local indicator.
6. Nutritionist import: reviewed image/text then PDF/alternatives/repeats;
   preserve grams, original wording and locked meals.

Separate UI package construction waits for team agreement. Apple/Google sign-in,
recipe media separation and store release are separate features; existing email
code and original-photo behavior remain usable meanwhile.

## Evidence and team setup

The [87-ticket register](../specs/011-team-development/contracts/delivery-backlog.md)
records source order/phase/owner and links into feature preparation. It does not
mark source tasks finished. Statuses are Proposed, Clarification needed, Ready,
In progress, In review, Integrated and Released, with blockers recorded separately.

Before parallel work: agree producer contracts, reserve spec numbers, verify
reviewer GitHub identities and protect dev/main where the account plan supports
it. Local SQL/Edge automation, macOS smoke and future Windows CI are dedicated
infrastructure tasks; this documentation does not silently enable those jobs.
No deployment, credential change or Trello reassignment is part of this revision.

## Security track (012)

Additional cross-cutting work requested after the source plan: see
[security assessment](development/security.md) and
[012 tasks](../specs/012-security-baseline/tasks.md). Fix high-priority file/error
boundaries, complete gateway key cutover and gate backend deployment on local
security evidence before affected release. Isolation/storage, auth/deletion and
future household/RAG/privacy tests accompany their feature slices. These are
open tasks, not completed hardening or changes to the 87 imported cards.

## Specifications prepared — 2026-11-14

All 87 source cards now map to focused requirements and implementation tasks in
[the source mapping](development/source-task-map.md). The [spec index](../specs/README.md)
allocates 001–033. Testing 013 and release/operations 033 add shared delivery work;
new runtime specs remain drafts where product, source or platform decisions are
open. No features are marked complete by this preparation.
