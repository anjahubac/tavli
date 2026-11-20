# Specification: Orthodox fasts and holidays

**ID**: 035-fasting-holidays | **Feature key**: FAST
**Created**: 2026-11-20 | **Baseline**: dev 36c9c7c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 2 | **Proposed independent reviewer**: Dev 4 and Dev 1

## Scope and source

Owner request of 2026-11-20: users can ask the app about Orthodox fasts and
holidays (for example “kada je koji post”), and meal planning can respect
fasting days. Planning document:
[Plan: pitanja o postovima i praznicima](https://claude.ai/artifact/Vp6kR6fVkrtPpY2rWWzmHW).
Visual reference: the “Predlog: pitanja o postu i praznicima” section of the
[design canvas](https://claude.ai/artifact/LYWX2feRv4ZUKSkRXTbsK7).

This spec does not claim anything is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder
reorganization. Calendar rules follow the Serbian Orthodox Church (SPC)
calendar, shown in civil (Gregorian) dates.

## Decisions recorded

- **D1** (Anja, 2026-11-20): Questions are answered with retrieval-augmented
  generation (RAG). Dates in the knowledge base are generated from a computed
  calendar, never typed by hand, so retrieved dates are exact.
- **D2** (Anja, 2026-11-20): Home has exactly one entry point, the
  “Post i praznici” status card. No separate button, text field or “Na umu”
  fast notice repeats it. Questions are typed only in the
  “Post i praznici” screen (phone) or side panel (desktop).
- **D3** (Anja, 2026-11-20, desktop Home): the right column (“Na umu”, then
  “Sutra”) has no section labels above its cards; labels sit inside the cards,
  so the column starts level with the meal cards.

## Requirements

- **FR-001**: Deliver an **Orthodox calendar module** on the device: Pascha by
  the Julian computus converted to civil dates (valid 1900–2099), movable
  feasts and fasts relative to Pascha, fixed fasts and feasts, Wednesday and
  Friday fasts with fast-free weeks, and a fasting level per day. Dev 2.
- **FR-002**: Deliver a **fasting and holidays knowledge base**: per-year
  calendar chunks generated from FR-001 for the current and next two years,
  plus team-written explanatory texts, stored with embeddings in Supabase
  (pgvector), sharing the embedding model and table design of
  [026](../026-cookbook-library/spec.md). Dev 2.
- **FR-003**: Deliver **grounded answers** through the `ai-gateway` function
  of [015](../015-ai-server-gateway/spec.md): new request type
  `fasting_question`, retrieval of the closest chunks, one model call that may
  answer only from retrieved chunks, and a server check that every date in the
  answer appears in those chunks. Dev 2.
- **FR-004**: Deliver a **recipe fasting label** with a closed set: `water`
  (na vodi), `oil` (na ulju), `fish` (riba), `none` (mrsno). AI fills it for
  new recipes as it does the [019 labels](../019-meal-selection-rules/spec.md);
  the user can correct it; user values are never overwritten by AI. Dev 2.
- **FR-005**: Deliver the **“Pratim post” household setting**, off by default:
  scope (Wednesdays and Fridays only, or all fasts) and strictness (follow the
  calendar, or always at least “na ulju”). Dev 3.
- **FR-006**: **Plans respect fasting**: when the setting is on, each plan
  day's fasting level filters candidate recipes and replacements through the
  [019](../019-meal-selection-rules/spec.md) rules. Dev 2.
- **FR-007**: Deliver the **Home status card and the question screen/panel**
  per D2. Dev 4.
- **FR-008**: **Compute the recipe fasting label from catalog food
  categories** (meat, dairy, eggs, fish, oil) once the catalog exists, keeping
  user corrections. Dev 1.

## Behavioral requirements

- **FR-101**: The Home card shows the label “Post i praznici”, today's state
  and the next fast or the current fast, for example
  “Danas mrsno · Božićni post od 28. nov.” or
  “Danas posno, na ulju · Božićni post”, and a chevron. It is computed on the
  device and works offline. Tapping it opens the question screen (phone,
  full screen, tab bar kept) or side panel (desktop, about 400 px, closable).
- **FR-102**: Position: on desktop, right of “Danas” in the header row, the
  width of the right column; on phone, under today's meal cards, full width.
  It does not use the single “Na umu” slot of
  [021](../021-home-and-cooking/spec.md) FR-102.
- **FR-103**: The question screen has one text field with a send button,
  three to four suggested questions as chips, one answer card with its source
  line, and two follow-up actions: “Napravi posni plan” (opens Plan with
  fasting on) and “Posni recepti” (opens Recepti filtered by fasting label).
  It keeps only the last few answers on the device; it is not a chat history.
- **FR-104**: Offline, or when the gateway refuses (`quota_exceeded`,
  `disabled`, `timeout`), the screen shows the same message as other AI
  features, and the card still shows the computed state.
- **FR-105**: If retrieval returns nothing relevant, or the date check fails,
  the answer says the app does not know, and no invented date is shown.
- **FR-106**: When “Pratim post” is off, the card still shows calendar
  information, and planning ignores fasting levels. Hiding the card entirely
  is an open question (Q4).
- **FR-107**: A short note under answers states these are general rules of
  the church calendar and that the sick, pregnant women and children are
  usually exempt. No medical or religious advice beyond the calendar.

## User scenarios and acceptance

- **US1 / SC-001**: On 13 November 2026 the card shows
  “Danas mrsno · Božićni post od 28. nov.” without network. On
  2 December 2026 it shows a fasting state for that day.
- **US2 / SC-002**: Asking “Kada počinje Božićni post?” returns 28 November
  with its source line; asking about a date outside the knowledge base returns
  “ne znam” instead of a guessed date.
- **US3 / SC-003**: With “Pratim post” on (all fasts), a generated week inside
  a fast contains only recipes whose label is allowed for each day; a
  replacement offers only allowed recipes.
- **US4 / SC-004**: Pascha fixtures: 2026-04-12, 2027-05-02, 2028-04-16, and
  further years checked against the official SPC calendar; fixed fasts and
  fast-free weeks match the same source for at least five years.
- **US5 / SC-005**: At 320 logical pixels and 2× text the card, the answer
  card and both actions remain readable and reachable; the desktop panel
  closes with its button and Escape.

Include empty/error/offline/cancel/retry and repeated questions. Use synthetic
fixtures and a fake AI. Acceptance is unverified until evidence is linked.

## Data and privacy

The calendar is reference data on the device. The knowledge base is global
reference data on the server, readable by authenticated users, written only by
a maintenance script. Questions go through the gateway without personal data
beyond the question text; logs keep no content (as in 015). The household
setting syncs like other household preferences. Last answers stay on the device.

## Exact UI copy carried forward

“Post i praznici”, “Danas mrsno”, “Danas posno, na ulju”, “Napravi posni plan”,
“Posni recepti”, “Pitaj još”, “Izvor: crkveni kalendar”, “Pratim post”,
fasting labels “na vodi”, “na ulju”, “riba”, “mrsno”. Other copy is finalized
in Serbian Latin before its UI task becomes Ready.

## Dependencies and open decisions

Producer specs: [015](../015-ai-server-gateway/spec.md),
[019](../019-meal-selection-rules/spec.md),
[026](../026-cookbook-library/spec.md) (shared vector table/model),
[018](../018-ingredient-catalog/spec.md) (FR-008 only),
[021](../021-home-and-cooking/spec.md) (Home layout).

- **Q1**: Who checks the calendar rules against the official SPC calendar,
  especially days when fish or oil is allowed?
- **Q2**: Who creates the shared vector table first, Dev 2 (fasting) or
  Dev 1 (cookbooks, per Trello)? The second consumer reuses it.
- **Q3**: Is “Pratim post” per household or per member?
- **Q4**: Is the Home card hidden when the household does not follow fasts?
- **Q5**: Daily question limit in `ai_usage`.
- **Q6**: Does the user's slava (family patron saint day) belong in scope?
- **Q7**: Where on the canvas are the “Pratim post” switch and the recipe
  fasting label drawn? They are not on the canvas yet.

Unresolved questions block their dependent code, not research or tests.
