# Research: Plan-first experience and quantity-safe shopping

**Date**: 2026-11-02. Repository inspection and a read-only schema review.
No provider/production requests, new packages or credential reads were needed.

## R1 — Product hierarchy

**Decision:** Plan is home; Nabavka, Recepti, Ostava are the other tabs. Today
is inside Plan. Profile/household/settings use a labeled, accessible avatar.
**Rationale:** owner explicitly prioritized weekly/monthly planning and shopping.
**Alternative:** Today-first recommendations with planning behind a small link
would demote the primary job. Generic recipe-feed navigation has the same issue.

## R2 — Calendar semantics

**Decision:** Monday–Sunday weeks; full calendar months; clipped weekly periods
may number six. Store civil-date meaning, not instants that shift with travel/DST.
**Evidence:** current ShoppingLists.week comment says 1–5, but server SQL has no
such constraint. Calendar-month boundaries need explicit period dates.
**Alternative:** four/five fixed weeks loses days or mislabels boundary periods.

## R3 — Approved recipe snapshots and portions

**Decision:** a planned entry owns servings and an approved recipe snapshot;
library source is optional provenance. Editing the library does not edit plans.
**Evidence:** current entries have recipeId/locked/cooked but no servings or
snapshot. Recipe DetailLevel.summary already supports ingredients without steps.
**Alternative:** live library references silently alter plan and shopping needs.

## R4 — Shopping provenance and canonical lists

**Decision:** normalized per-preparation contributions grouped by ingredient/unit
dimension; canonical weekly lists and a non-persisted whole-month aggregate.
**Evidence:** existing fromRecipeIds cannot distinguish repeated occurrences;
005's ShoppingRepository de-duplicates names and does not sum quantities.
**Alternative:** another purchasable month list duplicates receipt/stock credit.

## R5 — Supply accounting

**Decision:** normalized supply allocations cover contributions with confirmed
pantry or bought stock; one canonical physical supply identity. Add a unique
purchase-origin link to a pantry receipt. Keep whole-row purchase/undo initially.
**Rationale:** a purchase transferred to pantry is not new stock. Per-period
subtraction of the same pantry stock is also wrong.
**Alternative:** provenance JSON rewritten on a grouped item cannot enforce
independent demand/allocation identities or safely query capacity across weeks.
A separate purchasing/payment/warehouse subsystem is unnecessary.

## R6 — Privacy and household size

**Decision:** use only the creator's own taste/ratings plus explicit plan input;
resolved per-plan servings default to two until edited or copied from a plan.
**Evidence:** taste_profiles and ratings are own-user RLS; households and Account
have no size field. Existing roadmap wording is a future goal, not stored data.
**Alternative:** silently reading all members' profiles violates personal scope.

## R7 — Bounded AI work and drafts

**Decision:** MealPlanAI is a façade over existing AIRouter text, not a new
provider. Weekly outline batches plus small recipe-summary batches preserve
progress. Keep drafts in-session until approved; do not promise fixed latency.
**Evidence:** TaskKind is vision/text; free-tier fallback/cooldowns already exist.
**Alternative:** one huge monthly response is difficult to retry and likely to
hit response limits; saving partially generated rows immediately violates preview.

## R8 — Minimal migration scope

**Decision:** future additive columns and three child tables; bump then-current
drift version, regenerate, add SQL migrations, RLS/grants, deletion triggers,
sync mapping/order, legacy and wipe updates. No schema changes in this doc branch.
**Evidence:** current sync registry/account cleanup enumerate entities explicitly.
**Alternative:** local-only writes or applied migration edits violate constitution II.

## R9 — Usability as a gate

**Decision:** essentials in one setup screen, optional detail progressively
disclosed, one primary action, immediate checkbox feedback and reversible
editing. Test with five representative first-time users, target ≥4 completing
the central journey without help. Record failures rather than marking a
checklist passed from visual inspection alone.
**Rationale:** the owner explicitly requires intuitive and easy UI/UX.
**Alternative:** mandatory pantry/profile setup or many equally weighted actions
adds work before the person can create a useful first plan.

## R10 — Media and existing behavior

**Decision:** open original/unclassified images honestly; full separate photo
storage is later work. Preserve recipe edit/history, auth gates, wake lock and
005 themes after main merge. Do not branch from unmerged 005.
**Alternative:** redesigning every media/storage path in the planning feature
increases scope without enabling the core plan → shopping journey.

## R11 — Standalone recipe shopping (owner addition)

**Decision:** a source header represents either a planned entry or one standalone
preparation. Contributions link to it; allocations are shared across both modes.
The third child table is justified by explicit source identity and a frozen
snapshot for unsaved recipes. No fake plan or hidden library save is needed.
**Alternative:** mandatory planEntryId cannot represent recipe-only shopping;
copying source metadata onto every ingredient loses a coherent preparation id.

## R12 — Purchase history and deleted recipe sources

**Decision:** bought rows freeze small archival source metadata independently
of live demand. Plan cooking routes use entry ids so deleted library sources
do not break approved steps. Ratings retain existing recipe FK semantics and
require an explicit save-as-recipe when the source is gone.
**Alternative:** live contribution-only history changes after reconciliation;
recipe-id-only cooking routes cannot reach a retained plan snapshot.

## R13 — Cooked demand and bounded interaction promises

**Decision:** marking a planned meal cooked closes its outstanding shopping
demand while retaining purchases and held stock allocations until explicit
stock review. Later corrections cannot generate shopping for an already cooked
entry. Do not silently decrement pantry. The two-tap cooking-start target applies
to approved saved steps; missing steps reach their completion/review flow in
two navigation taps, with generation/review additional and visible.
**Alternative:** including cooked entries in reconciliation can ask someone to
buy ingredients for meals already eaten; promising two taps through AI approval
conceals a necessary review step.
