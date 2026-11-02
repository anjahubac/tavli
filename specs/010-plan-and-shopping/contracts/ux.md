# UX contract and acceptance gates

The owner explicitly prioritizes intuitive, easy UI/UX. These requirements apply
to prototype and production, not only to the final visual polish.

## UX-001 — Discoverable tasks

- Tabs always identify Plan, Nabavka, Recepti, Ostava; avatar has the accessible
  name/tooltip "Profil". Profile/household/settings are reachable from every tab.
- Plan is home. Today is within it. Every screen has one visually primary next
  action; edit/delete/technical options have secondary placement.
- Use ordinary Serbian labels. Provider names, API keys and sync internals stay
  in relevant advanced/settings details, not the normal planning/purchase flow.

## UX-002 — Short first success

- One setup screen contains period, meal types and servings. Pantry/preference
  details are optional expandable sections; creating the first plan does not
  require inventory entry or additional preference onboarding.
- Setup → progress/preview → approval uses at most three screen stages. Selected
  values remain visible and editable; returning to setup retains inputs.
- From an opened saved plan, reach its current-week shopping in at most two
  taps; from today's planned meal with approved saved steps, start cooking in
  at most two. Missing steps reach the completion/review flow within two
  navigation taps; AI generation and approval remain additional visible steps.
  Count navigation
  actions separately from typing, scrolling and required auth/name steps.

Standalone recipe shopping is equally discoverable: "Proveri sastojke" from
the recipe leads to portions/home-stock review and an explicit add action.
No plan setup or forced library save appears. Nabavka labels "Po planu" and
"Po receptu" clarify which source is being shown. If already planned, the
person chooses that context or a clearly separate preparation.

## UX-003 — Trust and reversibility

- Clearly distinguish AI proposal, saved plan, home stock and bought stock.
- Review changes before approval. No silent replacement of locked/cooked/past
  entries, hidden quantity guesses or hidden updates from library edits.
- Shopping checkmarks update immediately, without a confirmation dialog for
  each item. Bought items remain accessible for undo; destructive removal or
  undo with a pantry receipt explains the consequence and requests stock review.
- Saving/AI failures keep inputs and offer an actionable retry; do not show a
  blank/indefinite screen. Show actual generation progress, cancellation and
  explicit partial state. Do not add artificial waits for an animation.
- Offline use shows saved data and a plain save state. A network failure does
  not make a successfully saved local edit appear lost.

## UX-004 — Store/kitchen ergonomics and accessibility

- Tap targets ≥48×48 logical pixels; checks and quantity edits have adequate
  separation for one-handed use. Core actions do not require swipe-only gestures.
- Body text ≥16; cooking steps have generous line height. Text 2× remains usable
  at 320 px, with wrapping/scrolling and adaptive controls, not clipped labels.
- Color is supplemented by text/icons/semantics; focus and keyboard navigation
  work on macOS. Contrast targets: text 4.5:1, meaningful controls/state cues 3:1.
  See [W3C text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
  and [non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html).
- Bottom navigation below 720 px; rail from 720, extended from 1000. Month on
  phone is a compact date overview with readable selected-week details.
- Warm white/dark green/terracotta tokens, restrained borders, clear dark
  surfaces. Recipe discovery can emphasize real food photos; shopping emphasizes
  names/quantities. Unclassified original scans never pretend to be dish photos.
- Respect reduced motion; visual feedback does not require animation completion.

## UX-005 — Empty, error and interrupted states

Prototype and implement: no plan, empty pantry, no shopping, first AI run,
partial/cancelled/rate-limited generation, stale proposal, unknown quantity,
failed save, offline editing, deleted source recipe and missing image. Each
state explains what happened and offers the relevant next action without jargon.
Auth startup shows real loading feedback if needed rather than an empty page.

## UX-006 — Evaluation, not an assumed result

Use five representative first-time participants and synthetic household data.
Give tasks without naming controls: plan a month, preserve a preferred meal,
shop one week after checking stock, correct a purchase and cook today's meal. Also test finding/generating one recipe and shopping
for it with no plan. Both paths must be understandable without coaching.
At least four of five complete each path without coaching. Record:

| Task | Completed without help | Wrong turns / hesitation | Proposed correction | Retest |
| --- | --- | --- | --- | --- |
| Create/review monthly plan | Pending | Pending | After observation | Pending |
| Replace and lock a meal | Pending | Pending | After observation | Pending |
| Confirm stock and shop one week | Pending | Pending | After observation | Pending |
| Undo a purchase safely | Pending | Pending | After observation | Pending |
| Start today's cooking | Pending | Pending | After observation | Pending |
| Shop for a recipe without a plan | Pending | Pending | After observation | Pending |

"Pending" means not performed, not a claim of acceptance. Fix blocking problems
and repeat failed tasks before release. Automated tests complement this check;
passing screenshots alone does not prove users understand the app.
