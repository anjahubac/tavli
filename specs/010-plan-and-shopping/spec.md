# Feature Specification: Meal plans and linked shopping

**Feature Branch**: `010-plan-and-shopping` (from latest `main`)
**Created**: 2026-11-02
**Status**: Specified; documentation only, implementation not started.
**Input**: The owner made weekly/monthly recipe planning and the corresponding
shopping a key product goal, accepted the revised Plan-first proposal, and asked
to record it in project documents and Spec Kit. [Product direction](../../docs/product-design.md).

> All UI text is Serbian, Latin script. This feature delivers one connected
> plan → shopping journey, with supporting pantry/preferences/cooking actions.
> It does not claim these features are implemented by this documentation change.

## Clarifications

### Session 2026-11-02

- Owner correction: weekly/monthly planning and shopping are central; the
  earlier Today-first proposal is superseded. "Danas" belongs inside Plan.
- Owner request: document the revised proposal and implementation work; do not
  implement the app as part of this documentation task.
- Existing rule retained: "imam" means already at home; repeated additions
  add only the difference, preserving bought/manual shopping.
- Planning defaults, chosen for this spec: current Monday–Sunday week, lunch,
  two servings or the selected plan's servings, all editable. Month means a
  calendar month. A month may touch six calendar weeks.
- Personal profiles/ratings remain private. Use the creator's own preferences
  and explicit plan requests; do not infer access to other members' profiles.
- In-session AI drafts are not saved until confirmation. A partial draft needs
  an explicit partial-save action. Already saved plans remain unchanged on failure.
- Owner addition: shopping can follow a week/month plan or a single saved,
  searched, imported or newly generated recipe, with no plan required.
- Owner emphasis: UI/UX must be easy and intuitive. First-plan setup cannot
  require pantry/preferences onboarding. Prototype and real-user usability
  evaluation are acceptance gates, not assumed results of visual styling.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Generate and approve a plan (Priority: P1)

A signed-in person selects week/month, dates, breakfast/lunch/dinner, servings,
their preferences and whether to use confirmed pantry stock. They receive meal
suggestions arranged by day, inspect them and save the accepted plan.

**Why this priority**: the central reason to use Tavli beyond collecting recipes.
**Independent Test**: generate with a fake AI, inspect a full week and month,
save, restart offline and see exactly the approved meals and portions.

**Acceptance Scenarios**:

1. **Given** no plan, **When** Plan opens, **Then** "Napravi plan" is the primary action.
2. **Given** chosen dates and meal types, **When** generation succeeds, **Then**
   every selected date/type has one suggested meal; there are no extra slots.
3. **Given** a monthly draft, **When** a batch fails, **Then** completed batches
   and inputs remain in the open preview; retry requests only missing work.
4. **Given** any draft, **When** it is discarded or generation fails, **Then**
   the existing plan, recipe library and shopping have not changed.
5. **Given** a reviewed draft, **When** saved, **Then** approved meals and their
   required recipe data are saved together. Partial saving is separately named
   and shows the remaining empty slots.

### User Story 2 — Review and adapt the calendar (Priority: P1)

The person browses days/weeks/month, opens today's meals, replaces a meal with
an AI suggestion or a library recipe, changes servings, locks a choice and
marks cooked meals. The plan retains the approved recipe content.

**Why this priority**: plans need to adapt without undoing household decisions.
**Independent Test**: use a seeded plan, replace one meal, regenerate the rest
and verify all protected entries and approved shopping quantities.

**Acceptance Scenarios**:

1. **Given** a phone, **Then** week is a day list and month is a compact calendar
   with selected-week details; a wide window supports calendar + recipe detail.
2. **Given** locked, cooked or past-date entries, **When** regenerating, **Then**
   those entries do not change; only eligible selected slots receive proposals.
3. **Given** an approved plan, **When** its library recipe changes or is deleted,
   **Then** approved recipe content and portions remain available in the plan.
4. **Given** a newer local edit while a proposal is prepared, **When** accepting,
   **Then** stale changes are not silently applied; the person reviews again.
5. **Given** multiple saved plans, **Then** each is selectable; default to the
   newest plan containing today, otherwise the most recently saved plan.

### User Story 3 — Shop for the plan without duplication (Priority: P1)

The person opens Nabavka for the plan, chooses the whole period or a week,
checks home supplies, adds missing amounts, checks off purchases and can add
unrelated items manually. Changes to the plan update only outstanding demand.

**Why this priority**: a plan must produce useful, trustworthy shopping quantities.
**Independent Test**: repeat a recipe at different servings/weeks, reconcile
repeatedly, replace it and verify totals, provenance and retained purchases.

**Acceptance Scenarios**:

1. **Given** repeated recipes, **Then** every occurrence contributes its scaled
   quantities. Compatible quantities combine; different unit dimensions do not.
2. **Given** a month crossing six weeks, **Then** all dates have a weekly
   shopping period. Month and week views show the same underlying purchases.
3. **Given** confirmed home stock, **When** it covers demand, **Then** that stock
   is allocated once across the plan rather than subtracted again in each week.
4. **Given** 300 g demand, 100 g confirmed pantry and 200 g purchased,
   **When** demand increases to 400 g after purchase-to-pantry transfer,
   **Then** the amount still to buy is 100 g. Repeating any confirmation changes nothing.
5. **Given** manual/bought items, **When** meals are replaced or removed,
   **Then** those items remain and bought items never become unbought implicitly.
6. **Given** a purchased item, **When** transferred to pantry twice,
   **Then** one receipt is created; month/week views cannot create a second receipt.

### User Story 4 — Shop for a recipe without a plan (Priority: P1)

A person opens a saved/searched/imported/generated recipe, reviews ingredients
at chosen servings, confirms what they have and adds only missing amounts to
Nabavka. Creating a plan or saving an AI preview into the recipe library is not required.

**Why this priority**: planning ahead and spontaneous recipe shopping are both
primary jobs; neither can force the other workflow.
**Independent Test**: with no plan, review a saved recipe and an unsaved generated
preview, add shopping twice, change one "imam" choice and verify only the delta.

**Acceptance Scenarios**:

1. **Given** no saved plan, **When** a recipe is opened, **Then** ingredients,
   portions and "Proveri sastojke" are available; no plan setup is required.
2. **Given** an unsaved generated/imported preview, **When** ingredients are
   inspected, **Then** nothing is saved. Explicitly adding shopping stores a
   frozen shopping source, not a hidden library recipe or a fake meal plan.
3. **Given** the same preparation, **When** Add is repeated or one "imam" choice
   is undone, **Then** the same source is reconciled and only the new missing
   demand is added; existing bought/manual rows remain.
4. **Given** a deliberate later preparation of the same dish, **When** the
   person chooses "Ponovi nabavku", **Then** it has a new source identity;
   earlier purchases/history remain and are not mistaken for a double click.
5. **Given** the recipe already appears in the selected plan, **Then** the
   person can view its planned shopping or explicitly add a separate preparation.
   Merely inspecting a recipe does not duplicate the plan's demand.
6. **Given** Nabavka, **Then** source/period controls offer "Po planu" and
   "Po receptu". Recipe mode remains usable without any plan; plan mode keeps
   week/month dates visible. Confirmed supply is not reused across both modes.

### User Story 5 — Maintain pantry and personal preferences (Priority: P2)

The person searches/adds/edits pantry stock, confirms quantities and expiry,
and uses "Iskoristi u planu". They manage their own diet/dislikes/allergies.

**Why this priority**: usable supply information and tastes improve the central plan.
**Independent Test**: seed pantry and two users' profiles; edit offline, confirm
supply, generate a draft and check only the current person's preferences are read.

**Acceptance Scenarios**:

1. **Given** expired, unknown or unconfirmed quantities, **Then** they do not
   silently reduce shopping. Expiring-within-seven-days stock is highlighted.
2. **Given** the same confirmed supply in two weeks, **Then** allocating it to
   one occurrence reduces availability for all others.
3. **Given** a cooked flag, **Then** actual pantry quantities do not decrease
   without confirmation. The person can correct stock explicitly. Marking
   cooked closes that meal's outstanding shopping; its held stock allocations
   await explicit review, and later corrections cannot reopen cooked demand.
4. **Given** shared household membership, **Then** other people's private taste
   profiles and ratings remain inaccessible and are not copied into shared plans.

### User Story 6 — Connect recipes, cooking and feedback (Priority: P2)

A person chooses a library recipe for a date/meal, cooks the approved version
with readable steps and records optional personal feedback.

**Why this priority**: completes the plan → shopping → cooking loop.
**Independent Test**: insert a saved recipe into a slot, cook it offline, mark
cooked and save a private rating; existing edit/version/undo flows still work.

**Acceptance Scenarios**:

1. **Given** "Dodaj u plan", **Then** date and meal are chosen and replacing an
   occupied/protected slot requires explicit review; existing recipe data stays.
2. **Given** saved steps, **When** cooking starts, **Then** Previous/Next,
   ingredients and wake-lock choice are available, including offline.
3. **Given** a recipe summary without steps, **Then** the person can request
   steps online and approve the result; offline does not invent instructions.
4. **Given** completed cooking, **Then** marking cooked is separate from the
   optional personal star rating and favorite flag; feedback informs later proposals.
   If the library source was deleted, cooking still uses the entry snapshot;
   rating/favorite requires explicitly saving it as a recipe first.
5. **Given** an unclassified/source image, **Then** it opens as the original
   and is not represented as a confirmed photograph of the finished dish.

### User Story 7 — Navigate the same experience on every device (Priority: P2)

Four task-focused tabs, avatar access and readable light/dark layouts support
the same household journey on phones and wide windows.

**Why this priority**: the connected workflow must remain usable in the kitchen/store.
**Independent Test**: complete the seeded journey at 320/400/1200 px, text 2×,
light/dark and reduced motion; old recipe/profile links still reach their screens.

**Acceptance Scenarios**:

1. **Given** sign-in/name completion, **Then** Plan opens; tabs are Plan,
   Nabavka, Recepti, Ostava, and the avatar opens profile/settings/household.
2. **Given** "Danas", **Then** it selects today's part of the plan without
   removing access to weekly/monthly planning.
3. **Given** saved data and no connection, **Then** viewing and manual changes
   work; AI actions explain the missing connection without losing form inputs.
4. **Given** old /shopping, /profile or recipe links, **Then** navigation and
   auth redirects remain valid. Save banners and sign-out/delete rules remain.
5. **Given** a first-time signed-in person, **Then** essentials fit one setup
   screen, optional detail is expandable and a first plan needs no pantry or
   preference data entry. Setup, progress/preview and confirmation use at most
   three stages with one primary action per screen.
6. **Given** an opened plan/today's meal, **Then** current-week shopping/cooking with approved saved steps
   are each reachable in at most two navigation taps, excluding typing/auth.
7. **Given** five representative first-time participants, **Then** at least
   four complete both the plan-based journey and standalone recipe shopping
   without coaching; failures are recorded, corrected and retested before release.

### Edge Cases

- February with 28/29 days, 30/31-day months, six-week spans, year boundaries
  and daylight-saving changes do not shift civil meal dates or lose slots.
- Partial pantry amounts, quantities "po ukusu", unknown units and incompatible
  units require explicit review rather than unsafe numerical subtraction.
- A changed meal/portion, repeated recipe, bought row and manual row retain
  separate provenance. Surplus purchases remain visible, never silently deleted.
- AI limits, malformed replies, cancellation and navigation away preserve saved
  data; an in-session draft can be retried or explicitly discarded.
- Deleted source recipes retain plan snapshots. Missing images get a neutral
  fallback. No data reset is a migration strategy. Cooking from a plan uses its entry
  snapshot even after source deletion; optional rating requires an existing
  library recipe or explicit save-as-recipe first.
- Sign-out keeps caches and pending changes; deletion remains explicit and
  account-scoped. 009's advanced simultaneous-edit handling is not claimed here.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Provide Plan-first four-tab navigation and avatar access to profile/settings/household.
- **FR-002**: Support full weeks and calendar months, including six clipped Monday–Sunday shopping periods and civil-date stability.
- **FR-003**: Select meal types and editable default/per-entry servings; count each planned occurrence separately.
- **FR-004**: Use the creator's private preferences/ratings and explicit requests; do not read or expose other members' private data.
- **FR-005**: Generate suggestions with progress, cancellation and retry of missing draft work, retaining inputs on failure.
- **FR-006**: Preview before atomic approval; no saved plan/recipe/shopping mutations on discard; explicitly confirm partial saving.
- **FR-007**: Preview replacements/regeneration and preserve locked, cooked and past entries; detect known stale edits before approval.
- **FR-008**: Provide selectable saved plans, week/month calendars and today's cooking within Plan.
- **FR-009**: Retain approved recipe content/servings independently of later library edits or deletion.
- **FR-010**: Derive shopping from each planned occurrence and expose its source meals.
- **FR-011**: Sum compatible units only; keep incompatible/unknown quantities reviewable and do not invent quantities.
- **FR-012**: Maintain canonical weekly shopping; whole-plan/month views aggregate the same records without duplicate purchases.
- **FR-013**: Apply confirmed pantry coverage once across affected plans/periods and do not credit one supply twice.
- **FR-014**: Reconcile only the change in outstanding demand; preserve manual/bought records and idempotent repeated actions.
- **FR-015**: Group shopping by store category, support manual quick-add and separate bought items with an explicit undo.
- **FR-016**: Transfer confirmed bought quantities to pantry once; purchases and receipts represent the same supply.
- **FR-017**: Search/add/edit pantry quantities/expiry and offer expiring stock for planning; unknown/stale stock needs confirmation.
- **FR-018**: Add a library recipe to a chosen slot with replacement review; preserve existing editing/history and open original images honestly.
- **FR-019**: Provide readable cooking steps, ingredients and existing screen-on choice; saved steps work offline and missing steps need approved completion.
- **FR-020**: Allow optional personal rating/favorite after cooking and use that feedback in future suggestions.
- **FR-021**: Save user changes under the account, support offline editing/retry and keep household data isolated.
- **FR-022**: Preserve auth/name gates, old deep links, profile actions, sync visibility and sign-out data retention.
- **FR-023**: Apply the warm light/dark design, body text ≥16, 2× text, phone/wide layouts, meaningful state labels and reduced motion without artificial waits.
- **FR-024**: Keep Serbian errors actionable, inputs recoverable and explicit deletion limited to the selected item/account.
- **FR-025**: Do not automatically consume pantry stock merely because cooking is marked complete; confirmation/correction changes actual stock.
- **FR-026**: Meet the short-setup, primary-action, two-tap, recoverable-state and real-user usability gates in US7 and the UX contract; do not require pantry/preferences before first success.
- **FR-027**: Support standalone recipe shopping without a plan, including read-only ingredient review of unsaved/generated/imported previews.
- **FR-028**: Give each preparation a stable source identity; repeated adds reconcile it, while explicit repeat creates a new occasion. Keep planned and standalone provenance distinguishable.
- **FR-029**: Expose Plan/Recipe shopping source modes; explicit shopping approval may save a source snapshot without silently saving a library recipe.

### Key Entities

- **Meal plan**: household, civil date range, selected meal types and use-pantry choice.
- **Planned meal**: date/type, resolved servings, approved recipe content, optional library source, locked/cooked state.
- **Shopping period**: one plan's clipped calendar week; whole-period views aggregate these periods.
- **Shopping source**: a planned occurrence or a standalone preparation with approved servings/content; a preview becomes a source only after explicit shopping approval.
- **Ingredient demand**: a planned occurrence's scaled ingredient need and shopping group.
- **Supply allocation**: confirmed pantry/purchased stock covering demand once.
- **Purchase/receipt**: a bought item and its optional one-time pantry receipt, sharing a supply identity.
- **Personal taste/feedback**: current person's preferences, ratings and favorite choices.

### New UI copy (Serbian, Latin)

Navigation: "Plan", "Nabavka", "Recepti", "Ostava", "Profil", "Podešavanja",
"Domaćinstvo", "Danas", "Nedelja", "Mesec", "Izaberi plan".

Planning: "Napravi plan", "Otvori nabavku", "Period", "Obroci", "Doručak",
"Ručak", "Večera", "Broj porcija", "Koristi ostavu", "Preference",
"Način ishrane", "Ne volim", "Alergije", "Posebni zahtevi", "Predloži plan",
"Pripremam plan…", "Pripremljeno {n} od {ukupno} obroka", "Prekini",
"Nastavi generisanje", "Sačuvaj plan", "Sačuvaj nepotpun plan", "Odbaci",
"Nije planirano", "Zameni jelo", "Predloži drugo", "Iz mojih recepata",
"Zaključaj", "Otključaj", "Zaključano", "Skuvano", "Označi kao skuvano",
"Ponovo predloži", "Pregled izmena", "Prihvati", "Otkaži", "Promeni porcije",
"Novi plan", "Još nemaš plan", "Više opcija", "Predlog plana",
"predlog još nije sačuvan", "Nov recept", "Promeni izbore", "Nazad na predlog",
"Odbaciti predlog?", "{n} obroka ostaje prazno.", "Plan je sačuvan.",
"Nepotpun plan je sačuvan.", "Napravi novi plan", "Nije skuvano",
"Ukloni iz plana", "Ukloniti obrok iz plana?", "Ukloni", "Obrok",
"Izaberi obrok da vidiš recept.", "Jelo je zamenjeno.", "Izmene su sačuvane.",
"Tražim drugo jelo…", "Prethodna nedelja", "Sledeća nedelja",
"Za zamenu ili uklanjanje prvo otključaj obrok.", "Skuvan obrok se ne menja.",
"Ovaj recept u planu nema korake pripreme.", "Obrok nije pronađen.".

Shopping/pantry: "Ceo plan", "Za nabavku", "Kupljeno", "Dodaj stavku",
"Naziv", "Količina", "Jedinica", "Kategorija", "Imam", "Proveri količinu",
"Dodaj nedostajuće u kupovinu", "Sve je u kupovini", "Imaš sve sastojke",
"Za ove obroke", "Dodaj kupljeno u ostavu", "Već je dodato u ostavu",
"Vrati u nekupljeno", "Iskoristi u planu", "Uskoro ističe rok", "Rok trajanja",
"Potvrdi stanje", "Sačuvaj", "Izmeni", "Obriši", "Ponovi nabavku".

Source selection: "Izaberi recept", "Nabavka za recept", "Po planu", "Po receptu", "Proveri sastojke", "Prikaži nabavku plana", "Dodaj zasebnu pripremu", "Za ocenu prvo sačuvaj recept.", "Sačuvaj kao recept".

Cooking/feedback: "Dodaj u plan", "Kreni sa kuvanjem", "Prethodni", "Sledeći",
"Sastojci", "Priprema", "Dopuni korake", "Otvori original", "Oceni jelo",
"Omiljeno jelo", "Preskoči", "Napomena", "Ne gasi ekran".

Errors/empty states: "Još nema plana", "Napravi prvi plan obroka.",
"Nabavka je spremna.", "Nema stavki za nabavku.", "Plan nije sačuvan. Pokušaj ponovo.",
"Plan je u međuvremenu promenjen. Pregledaj izmene.",
"Unesi količinu koju imaš.", "Količina nije poznata. Proveri stavku.",
"Koraci pripreme još nisu dostupni.", "Nema interneta. Sačuvani podaci su dostupni.",
"Otvaram aplikaciju…", "Ranija lista", "Proveri stanje ostave pre vraćanja kupovine.",
"Generisanje je prekinuto. Pripremljeni deo plana je sačuvan u ovom pregledu.",
"Odbaciti predlog plana?", "Ukloniti obrok iz plana?", "Obrisati stavku?",
"Ovaj obrok je zaključan ili skuvan. Potvrdi izmenu.", "Pokušaj ponovo".

Calendar labels: "Ponedeljak", "Utorak", "Sreda", "Četvrtak", "Petak",
"Subota", "Nedelja"; "Januar", "Februar", "Mart", "April", "Maj", "Jun",
"Jul", "Avgust", "Septembar", "Oktobar", "Novembar", "Decembar".
Dates use dd.MM.yyyy.; quantities use decimal comma. Accessible icon names use
the matching action above. Existing Serbian auth/sync/AI error mappings remain.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Weeks and 28/29/30/31-day months have exactly the selected meal slots, including six-week and year-boundary fixtures.
- **SC-002**: Repeating shopping reconciliation or confirming the same purchase/receipt causes zero duplicate rows or extra quantities in every acceptance fixture.
- **SC-003**: The 300 g demand / 100 g pantry / 200 g purchase / 400 g revised demand example leaves exactly 100 g outstanding in week and month views.
- **SC-004**: Every locked/cooked/past slot remains unchanged after regeneration and library edits do not mutate approved quantities.
- **SC-005**: All saved-data/manual-edit/cooking flows remain usable offline and synchronize once connectivity returns without loss or duplication.
- **SC-006**: The full seeded journey works at 320/400/1200 px, text 2×, light/dark and reduced motion, without overflow or unreachable actions.
- **SC-007**: Two unrelated accounts cannot read/write each other's household data or personal taste/ratings; sign-out retains each account's cache.
- **SC-008**: Existing auth, recipe editing/history, save indicators and screen-on behavior pass their regression scenarios after the navigation change.
- **SC-009**: At least four of five representative first-time users complete both plan → weekly shopping → today's cooking and standalone recipe shopping without coaching; observed blocking issues are fixed and retested.
- **SC-010**: Essentials use one setup screen and at most three stages through confirmation; current-week shopping and today's cooking with approved saved steps each take at most two navigation taps. Missing steps reach completion/review within two navigation taps, with AI/review separately visible.

- **SC-011**: Without any saved plan, saved and unsaved generated recipes can reach ingredient review/shopping without forced plan/library creation; repeated add is idempotent and explicit repeat is separate.

## Assumptions

- This feature can start with the existing solo household. 008 invitations and
  009 realtime/conflict resolution remain separate; their advanced guarantees
  are not implied. Schema/policies still respect household membership from day one.
- AI drafts are in-session; closing/discarding loses only unapproved work, with
  a leave confirmation. AI needs a connection; saved data and manual work do not.
- Whole-row purchase/undo is sufficient initially. Partial purchase UI, prices,
  budgets, nutrition calculations and semantic ingredient substitutions are outside 010.
- Existing library-photo display is preserved honestly. Full separate dish/
  document photo storage is a later feature in the roadmap/product design.
- The 005 theme branch must land through main before 010 app implementation.
  No existing historical specification or applied migration is rewritten.
