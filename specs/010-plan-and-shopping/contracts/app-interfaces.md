# App/service contracts (planned)

> Direction review, 2026-11-13: read the [current direction overlay](../current-direction.md)
> before new work. This document retains the original 010 scope and acceptance
> history; implemented code and unchecked acceptance must be assessed separately.


These are future internal interfaces, not new public HTTP endpoints. Pure Dart
models carry immutable data; widgets forward intents through Riverpod. Backend
access stays behind repositories/remote interfaces with fake implementations.

## Planning

- **PlanRequest**: civil range, selected meal types, servings, use-pantry choice,
  explicit requests and the current user's private taste inputs. Validate range
  and nonempty meal selection before asking AI. Never include other users' profiles.
- **PlanDraft**: slot proposals, referenced/new recipe summaries, progress and
  missing work, optional base fingerprint for replacements. It is in-session,
  not a saved plan or an outbox record.
- **MealPlanAI.propose(request)**: use existing AIRouter with TaskKind.text;
  expose progress and cancellation. Generate outlines in clipped-week batches,
  then missing recipe summaries in batches of at most three. Reuse approved
  library recipes; do not invent their ids or treat them as another household's.
- Parse strictly structured JSON. Reject missing/duplicate/out-of-range slots,
  unknown referenced ids, invalid portions and malformed ingredients with
  FormatException so router retry/fallback remains authoritative. UI uses Serbian
  AI error mapping; no provider keys, raw HTTP errors or request logs are shown.
- Retry continues only missing work in the still-open draft. Cancel/leave never
  commits data. Leave asks to discard unapproved work. Closing the app does not
  promise draft recovery; only approved saved data has durable account storage.
- **MealPlanRepository.approve(draft, allowPartial=false)**: re-read affected
  scoped rows, compare the base fingerprint and protected states, then persist
  accepted recipe data, plan/entries and existing-shopping reconciliation in
  one transaction with parent-first outbox entries. No network in the transaction.
- A partial approval requires the separate "Sačuvaj nepotpun plan" action and
  visibly empty remaining slots. Failed/stale approval leaves the old plan intact.
- **replaceEntry / changeServings / setLocked / setCooked / removeEntry**:
  act on a household-scoped entry. Marking cooked stops outstanding demand for
  that entry, preserves purchases and holds reservations until explicit stock
  review; later reconciliation never reopens demand merely because stock changed.
  Proposed destructive/protected changes are
  reviewed first. Regeneration never changes locked/cooked/past slots.
- **watchPlans / watchPlan / watchEntries** read drift. Civil-date codecs retain
  year/month/day when device timezone changes; event timestamps remain instants.

## Standalone recipe shopping

- **inspectIngredients(recipeOrDraft, servings)** is read-only and needs no
  plan. Saved/search results, image/name imports and generated previews can use it.
- **ShoppingRepository.addRecipePreparation(snapshot, originId, servings,
  have, preparationId)** is an explicit shopping approval. Persist/reuse a
  ShoppingSource and reconcile only its delta, without creating a library recipe
  or plan. A discarded recipe preview does not erase separately approved shopping.
- Origin is a library recipe id or stable draft id; repeated adds reuse the
  preparation. **repeatPreparation** creates a new id only on deliberate
  "Ponovi nabavku". Bought/manual items are never reset to make repetition work.
- If a recipe is already planned, offer its planned shopping context or an
  explicitly separate preparation. Do not add both automatically.
- Source mode is "Po planu" or "Po receptu"; the latter works with zero plans.
  Household supply capacities/allocations are shared across both modes.

## Shopping and supply

- **ShoppingRepository.reconcilePlan(planId)** derives per-entry requirements
  from approved snapshots and servings, applies current confirmed allocations
  and returns the delta. Stable source identities and transactions make retries
  idempotent. Bought/manual rows are retained, not rebuilt from scratch.
- **watchPeriod / watchWholePlan** expose canonical weekly rows; whole-month
  groups retain their underlying item ids. Checking an aggregate buys its
  currently outstanding underlying rows in one transaction, without making a
  second month-level purchase. Mixed bought/open groups show the remaining
  amount and let the person inspect source weeks; repeated checks are no-ops.
- **confirmHave(contributionIds, quantity, unit)** records confirmed home supply
  and allocations with capacity checked across all weeks/affected plans. Unknown
  quantity may cover only explicitly confirmed contributions, not inferred stock.
- **addManual / editManual / removeManual** preserve their own identity and
  outbox writes. They are independent of plan-derived contributions.
- **markBought(itemId)** freezes the displayed whole quantity and purchaseProvenanceJson as a purchase
  fact and covers matching demand once. Additional demand becomes an outstanding
  row; an already bought row is not enlarged by a plan edit.
- **undoPurchase(itemId)** releases purchase allocations and reconciles the
  outstanding amount. A linked pantry receipt requires stock review first;
  corrected/used stock is never silently erased. After confirmation, affected
  receipt/allocation/demand updates are atomic.
- **PantryRepository.receivePurchase(itemId, confirmedQuantity)** returns the
  existing receipt for a repeated call. The purchase and receipt share one
  supply identity; transfer does not increase demand coverage a second time.
- **PantryRepository.confirmStock / create / update / delete / watch** scope
  by household and write row + outbox together. Correcting supply releases or
  revalidates affected allocations. Cooking flags do not silently consume stock.
- **TasteRepository.watch/save** and **saveRating** are scoped to current user.
  Favorite uses existing isComfortFood semantics; ratings are optional, 1–5.
  If the original library recipe was deleted or never saved, rating requires
  explicit "Sačuvaj kao recept" first; do not silently restore/create it.
  Shared plan rows never contain a private profile/ratings dump.

## Navigation and compatibility

| Address | Target behavior |
| --- | --- |
| /plan | Default post-auth home; select week/month/today/saved plan |
| /plan/new | Essentials setup, optional detail, generation preview |
| /shopping | Nabavka, with selected plan/period; old links remain valid |
| /pantry | Search/add/edit/confirm inventory |
| /recipes and existing child routes | Library and existing recipe/history flows |
| /plan/:planId/entries/:entryId/cook | Cook the approved entry snapshot even if its library source is gone |
| /shopping/sources/:sourceId | Standalone ingredient/shopping context without a plan |
| /recipes/:id/cook | Cooking saved recipe; optional approved entry context |
| /profile and existing child routes | Avatar access; old links still work |
| /sign-in and /sign-in/name | Existing mandatory auth/name gates and return link |

Carry selected plan/entry through route state or scoped providers; a missing or
foreign id gives the existing Serbian not-found/selection state. Never fall back
to another account's row. /plan defaults only when no explicit valid return
route is requested.

## Deletion and conflicts

Explicit meal removal releases that entry's demand/allocations, preserving bought
and manual history. Library deletion nulls source references but retains approved
snapshot content. Sign-out keeps account cache/outbox; account deletion/wipe
includes new child entities in dependency order. Retain tombstones/delete-wins.

Known local stale drafts are rejected before saving. Keep 006a record-level
conflict semantics until 009; after downloaded capacity conflicts, request stock
review. Do not imply realtime collaborative reservation guarantees in 010.
