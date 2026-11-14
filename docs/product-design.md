# Tavli product and UX decisions

Updated: 2026-11-13 from the owner's revision of 12–13 November. This is the
accepted target, not a claim that every feature exists. The verified baseline is
in [architecture](architecture.md); the six-phase sequence is in
[product plan](product-plan.md). Existing visual design/themes remain.

## Primary journeys

Plan a week/month → review and adjust → check ingredients → shop → transfer
purchases → cook → optionally record intake or feedback. Standalone recipe →
check ingredients → add missing ingredients → shop is equally supported, with
no plan or forced recipe-library save required.

A first useful plan must not require pantry/profile setup. Keep the main flow
setup → progress/review → confirmation, with one clear primary action per step.
AI suggestions are drafts and never silently alter saved data.

## Navigation

Target order: **Plan, Nabavka, Početna, Recepti, Ostava**. Home is central and
opens after sign-in/name gates. The title bar shows Tavli and the profile avatar,
not a repeated tab title. Profile/settings/household remain behind the avatar.
Current `/plan`, `/shopping`, `/recipes`, `/pantry`, `/profile` and recipe URLs
remain compatible. Desktop rail does not display shortcut badges.

Home shows today's approved meals (including snacks), the next uncooked meal,
“Kuvaj” and “Skuvano”, tomorrow's meal names and at most one useful notice.
Notice priority: today's allergen warning → missing shopping today/tomorrow →
plan ending. Without a plan offer “Napravi plan”. Optional calorie strip appears
only when tracking is enabled. Cooked meals use a green circular check and muted
card; undo remains discoverable.

## Planning

Choose week/calendar month, meal types and servings. Add morning/afternoon
snacks through a list-based meal contract, not more hard-coded slot fields.
Defaults remain editable: current week, lunch, two servings unless a saved
selection supplies them. Never pretend household member count is known.

Prompt context uses authorized household restrictions, explicit wishes and the
approved preference aggregation contract. Existing saved recipes should be
selected locally where suitable; AI fills gaps. Recipe suitability, intensity
and dish kind use closed sets, user-editable annotations and post-generation
validation. Household rules default to substantial lunch, lighter dinner,
maximum one substantial meal/day and varied dish kinds. Locked meals remain
protected; a nutritionist-imported meal is not rewritten by these defaults.

Monthly generation is bounded/batched with progress, cancellation and retry of
missing work. Review, replacement and confirmation preserve accepted snapshots,
servings, cooked/locked/past entries and concurrent edits. Never overwrite a
newer edit with an obsolete draft. A month can intersect six Monday–Sunday weeks.

Week/month switching and primary actions remain at stable locations/sizes.
Mobile shows day markers and selected-day meals for month; wide screens use a
readable calendar/detail layout. “Ponovo predloži” and “Otvori nabavku” stay in a
fixed safe-area action bar above mobile navigation.

## Ingredients and shopping

Catalog identity is a stable UUID, with readable slug, category, base unit,
aliases and ingredient-specific conversions. Preserve original ingredient text.
An alias means the same ingredient, never a similar substitute. Unresolved items
remain visibly unresolved and usable as text until reviewed. One shared matcher
serves recipes, voice, cookbooks and imported plans.

“Po planu” and “Po receptu” remain reversible modes. Quantities aggregate only
when dimensions are compatible; approximate conversions display “~”, unknown
ones display “Proveri količinu”. Standard kitchen measures: glass 200 ml, cup
250 ml, tablespoon 15 ml, teaspoon 5 ml; dl/dkg are exact dimensional conversions.

Allocate supply once across the whole plan and standalone preparations. A known
pantry quantity reduces demand; presence without quantity produces a check hint,
not certain complete coverage. Keep manual/bought entries and source history.
Repeated Add reconciles only the delta; intentional repeat creates a new
preparation identity. Recipe changes do not rewrite approved plan snapshots.

Bought entries form a separate undoable group. “Prebaci u ostavu” explicitly
transfers checked purchases, once per receipt identity; it stays in the mobile
fixed action bar. Checking a shopping item alone does not silently transfer it.
A purchase and its pantry receipt are one supply and cannot cover demand twice.

## Pantry

Presence means available; do not display a redundant “imam” badge. Quantity is
optional. Search/add from the catalog, group by category and display plain names
when quantity is unknown. There is no expiry entry, expiry warning or “use first”
feature in this target. Legacy expiry columns are not dropped by documentation:
a later migration must preserve data and older-client compatibility explicitly.

Swipe to remove on phone; accessible delete action on desktop; offer undo.
Tap a numeric entry to edit quantity with minus/plus and direct input. Cooking
consumes known quantities once, never below zero; undo restores them once.
Unknown quantities persist until the person removes the item. Repeated events,
partial failures and offline replay must not duplicate consumption or receipts.

## Recipes and cooking

Keep photo/name/manual input, search, AI edit preview, history/restore and
original source-photo access. Phone offers camera/gallery; desktop uses file
selection. A scanned recipe is not displayed as a confirmed dish photograph.

“Dodaj u plan” selects date/meal and confirms replacing an occupied entry.
“Kuvaj” uses readable steps, previous/next, accessible ingredients and the
existing keep-screen-on choice with lifecycle cleanup. Wide view can show
steps and ingredients side by side. A recipe without preparation steps remains
valid for shopping/intake; do not force AI to invent steps to unlock these flows.

Catalog mapping, allergies, personal favorite and optional calories use separate
widgets/services within the current recipes feature. Later cookbook and voice
inputs feed the same validation/preview/persistence path.

## Household and personal data

Invitation by link, six-character code or QR: seven-day validity and revocation,
review household name before joining. Joining moves recipes as specified, not
old plan/shopping/pantry. Owner can remove members/transfer ownership; member
can leave. Review offline queues and account scope before switching household.

Household shares recipes, plans, shopping and pantry. Taste preferences,
favorites, ratings, diary/targets and cycle data are personal. Planning receives
only the authorized minimum aggregate; the open choice between creator/all-member
favorites must be clarified before that consumer is implemented. Do not solve
this by granting broad access to personal rows. Allergy codes are structured;
separate the fixed allergen vocabulary from lactose avoidance and other dietary
preferences, with the final vocabulary/provenance reviewed before implementation.

## Optional later capabilities

- Nutrition tracking: off by default, no sixth tab, “Samo pratim”, “Ručno” or
  optional “Kalkulator”. Values carry sources/method/coverage; AI does not invent
  nutrition numbers. Private diary and meal-intake events are idempotent.
- Cookbook RAG: private household books, bounded background processing,
  authorized retrieval with book/page provenance and preview before saving.
- Voice: press-to-talk, validated closed commands update only a draft, response
  text plus platform speech; permission/cancel/failure paths on all targets.
- Prices/receipt QR: attributed estimates, coverage and date; QR starts as a
  time-boxed feasibility spike. Do not promise an integration before verified.
- Cycle rhythm: explicit opt-in, secure device-only dates, no health promises,
  generic optional dietary hints only, allergies/meal restrictions take priority.
- Nutritionist plan import: review “Proveri” items, preserve exact source text and
  quantities, lock imported meals, discard original upload under the approved
  retention policy; PDF/alternatives/repeat are later slices.

## Acceptance

Use [UI standards](development/ui-standard.md): phone/wide, light/dark, 2× text,
keyboard/screen reader, reduced motion, safe areas and offline/error states.
Existing warm palette and typography stay; accessibility fixes are not a redesign.
From a saved plan to weekly shopping and from today's meal to available cooking
steps should require at most two actions. Record additional generation/review
steps honestly when steps are missing.

Observe five first-time users on the complete planning and standalone shopping
journeys; target at least four completing without explaining controls. Record
failures and retest. This remains a future release gate, not a completed result.
