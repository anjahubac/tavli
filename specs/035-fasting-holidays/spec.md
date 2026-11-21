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
  Friday fasts with fast-free weeks, and a dietary rule per day. Distinguish
  unrestricted days, water, oil, fish, and Cheesefare (fish, eggs and dairy
  allowed, meat excluded). Represent time-limited abstinence separately.
  For Great Friday, use the SPC rule confirmed in Q1. Show the abstinence
  period and any later allowance. If a plan cannot represent the time
  restriction, leave its automatic suggestions empty for that date and
  keep manual entries available. Dev 2.
- **FR-002**: Deliver a **fasting and holidays knowledge base**: per-year
  calendar chunks generated from FR-001 for the current and next two years,
  plus team-written explanatory texts, stored with embeddings in Supabase
  (pgvector), sharing the embedding model and table design of
  [026](../026-cookbook-library/spec.md), subject to Q2 and separate access
  rules for global reference and private cookbook data. Dev 2.
- **FR-003**: Deliver **grounded answers** through the `ai-gateway` function
  of [015](../015-ai-server-gateway/spec.md): new request type
  `fasting_question`, retrieval of relevant chunks, and one generation
  attempt per gateway call. The model selects referenced calendar facts or
  explanatory passages. The server validates those references and renders
  dates and source labels from the approved material. This task uses the
  gateway for every account, including accounts with provider keys. Dev 2.
- **FR-004**: Deliver a **recipe fasting label** with a closed set: `water`
  (na vodi), `oil` (na ulju), `fish` (riba), `meatless` (bez mesa, for
  dishes with dairy or eggs), `none` (mrsno). Each label states the least
  permissive dietary rule that admits the recipe. AI fills it for
  new recipes as it does the [019 labels](../019-meal-selection-rules/spec.md);
  the user can correct it. User values are never overwritten by AI. Dev 2.
- **FR-005**: Deliver the **“Pratim post” household setting**, off by default:
  scope (fasting days that fall on Wednesday or Friday, or all calendar
  restrictions) and strictness (follow the calendar, or at least as strict as
  “na ulju”). The oil option keeps water days and time restrictions and caps
  fish and Cheesefare allowances at oil on applicable days. Unrestricted days
  stay unrestricted. Dev 3.
- **FR-006**: **Plans respect fasting**: use the household setting as the
  default and apply any explicit per-plan override. On restricted days,
  candidate recipes and replacements must have a compatible known label
  under the [019](../019-meal-selection-rules/spec.md) rules. Save the plan's
  effective fasting options so subsequent replacements apply the same rules.
  Dev 2.
- **FR-007**: Deliver the **Home status card and the question screen/panel**
  per D2. Dev 4.
- **FR-008**: **Compute the recipe fasting label from catalog food
  categories** (meat, dairy, eggs, fish, oil) once the catalog exists, keeping
  user corrections. Dev 1.

## Behavioral requirements

- **FR-101**: The Home card shows the label “Post i praznici”, today's state
  and the current or next named fasting period, for example
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
  line, and two follow-up actions: “Napravi posni plan” (opens a Plan draft
  with fasting enabled for that plan) and “Posni recepti” (opens Recepti
  filtered by fasting label). The draft carries the enabled preference's
  scope and strictness or defaults to all fasts and the calendar rule. The
  action leaves the saved preference unchanged.
  It keeps only the last few answers on the device; it is not a chat history.
- **FR-104**: Offline, or when the gateway refuses (`quota_exceeded`,
  `gateway_unavailable`, `timeout`), the screen uses the corresponding
  existing Serbian AI message. The card still shows the computed state.
  A per-model `model_unavailable` goes through the usual `AIRouter` fallback.
- **FR-105**: If retrieval returns nothing relevant, or the date check fails,
  the answer says the app does not know, and no invented date is shown.
- **FR-106**: When “Pratim post” is off, planning applies fasting only when
  explicitly enabled for a plan. The card computes the same calendar
  information regardless of the setting. Its visibility is open in Q4.
- **FR-107**: A short note under answers states these are general rules of
  the church calendar and that the sick, pregnant women and children are
  usually exempt. No medical or religious advice beyond the calendar.

## User scenarios and acceptance

- **US1 / SC-001**: On Thursday, 12 November 2026, the card shows
  “Danas mrsno · Božićni post od 28. nov.” without network. On Friday,
  13 November 2026, it shows a fasting state and previews the same named
  period. On 2 December 2026, it shows a fasting state within that period.
- **US2 / SC-002**: Asking “Kada počinje Božićni post?” returns 28 November
  with its source line; asking about a date outside the knowledge base returns
  “ne znam”. A real date for a different event is rejected. An explicit
  query for the last indexed year retrieves that year. A question about the
  end of a Nativity fast in January resolves to the same occurrence as its
  November start.
- **US3 / SC-003**: With “Pratim post” on (all fasts), a generated week inside
  a fast contains only recipes whose label is allowed for each day; a
  replacement offers only allowed recipes. With the setting off, generate
  a plan via “Napravi posni plan”, confirm that replacements honor its
  fasting rules and that the next ordinary plan still defaults to off.
- **US4 / SC-004**: Pascha fixtures: 2026-04-12, 2027-05-02, 2028-04-16, and
  further years checked against the official SPC calendar; fixed fasts and
  fast-free weeks match the same source for at least five years. Include
  Cheesefare, Great Friday, and both sides of the civil year boundary for the
  same Nativity fast. Check water and fish days under both strictness options.
- **US5 / SC-005**: At 320 logical pixels and 2× text the card, the answer
  card and both actions remain readable and reachable; the desktop panel
  closes with its button and Escape.

Include empty/error/offline/cancel/retry and repeated questions. Use synthetic
fixtures and a fake AI. Acceptance is unverified until evidence is linked.

## Security and privacy impact

- **Privacy**. The calendar is device reference data. The authenticated
  gateway receives the question and civil date and sends the question to the
  embedding and generation providers as needed. Do not attach account,
  household or recipe details to provider requests. Keep question and answer
  content out of server logs and usage records. Last answers stay on the
  device, scoped to the account. The fasting preference syncs under the
  household or member access rules selected in Q3.
- **Abuse**. Treat questions and retrieved passages as untrusted data. Apply
  authenticated request, size and usage limits before provider work. Validate
  selected facts and sources within the fasting corpus and use “ne znam”
  when validation fails. Test unauthorized and over-limit requests, prompt
  injection, invalid fact references and isolation from private cookbook
  chunks under [012](../012-security-baseline/spec.md).
- **Credentials**. App requests use the signed-in account's JWT. Embedding
  and generation credentials are server-side and this task uses the gateway
  for accounts with user keys as well.
- **Files**. N/A. No user file upload, download or file-path input.
- **Deployment**. Agree on the vector schema and ownership with 026. Apply
  the migration and grant model through the deployment workflow, then publish
  the generated corpus and enable the gateway task. Test access locally
  with synthetic accounts. Fasting reference data is readable by authenticated
  users and writable only through the maintenance process.

## Exact UI copy carried forward

“Post i praznici”, “Danas mrsno”, “Danas posno, na ulju”, “Napravi posni plan”,
“Posni recepti”, “Pitaj još”, “Izvor: crkveni kalendar”, “Pratim post”,
fasting labels “na vodi”, “na ulju”, “riba”, “bez mesa”, “mrsno”. Other copy is finalized
in Serbian Latin before its UI task becomes Ready.

## Dependencies and open decisions

Producer specs: [015](../015-ai-server-gateway/spec.md),
[019](../019-meal-selection-rules/spec.md),
[026](../026-cookbook-library/spec.md) (shared vector table/model),
[018](../018-ingredient-catalog/spec.md) (FR-008 only),
[021](../021-home-and-cooking/spec.md) (Home layout).

- **Q1**: Who verifies the calendar rules against the official SPC calendar
  and guidance, including Cheesefare, Great Friday and fish/oil allowances?
  The [Visoki Dečani fasting guide](https://www.spc-ticino.ch/download/post.pdf)
  describes abstinence on Great Friday until the shroud is brought out, then
  a light meal “na vodi”. Confirm the timing rule used in the app before
  fixing the expected Great Friday result.
- **Q2**: Who creates the shared vector table first, Dev 2 (fasting) or
  Dev 1 (cookbooks, per Trello)? The second consumer reuses it.
- **Q3**: Is “Pratim post” per household or per member?
- **Q4**: Is the Home card hidden when the household does not follow fasts?
- **Q5**: What are the question size and daily usage limits, and how do
  embedding attempts and `AIRouter` retries count under the 015 `ai_calls`
  contract?
- **Q6**: Does the user's slava (family patron saint day) belong in scope?
- **Q7**: Where on the canvas are the “Pratim post” switch and the recipe
  fasting label drawn? They are not on the canvas yet.
- **Q8**: Which slices should ship: the offline calendar, fasting-aware
  planning and AI Q&A? Record the product owner's decision for each slice.

Unresolved questions block their dependent code, not research or tests.
