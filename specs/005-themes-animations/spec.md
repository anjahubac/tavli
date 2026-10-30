# Feature Specification: Themes and ingredient animations

**Feature Branch**: `005-themes-animations`

**Created**: 2026-10-30

**Status**: Implemented

**Input**: User description: "Teme i animacije: tri teme Bosiljak/Šafran/Borovnica u svetloj i tamnoj varijanti, izbor teme i režima (Svetla/Tamna/Kao sistem) u Profilu, sačuvan u bazi; Plus Jakarta Sans, eksplicitni ColorScheme + ThemeExtension; svi ekrani koriste samo tokene teme. Animacije sastojaka (splash motiv teme, skeniranje fotografije, lonac koji krčka, štikliranje sastojka, puna kesa, prazan frižider, varjača za osvežavanje, tanjir u planu, jaje u tajmeru), sve poštuju smanjeno kretanje; galerija 'Animacije' u Profilu (debug)."

> All UI text is Serbian (Latin script). Quoted strings are the exact UI copy.
> Visual reference (approved mockup): https://claude.ai/artifact/X5eC5pkBWtf1bHcwRUPh4C

## Clarifications

### Session 2026-10-30

The owner approved the requirements (palettes, styles and the nine animations)
in the project conversation; these remaining details were decided by Claude:

- Q: Where does the choice persist? → A: In the local database's app-settings
  table (keys `theme` and `theme_mode`); no schema change.
- Q: Bundled font or downloaded at runtime? → A: Bundled (offline-first): the
  static Plus Jakarta Sans weights 400–800, SIL OFL licence shipped with them.
- Q: Does the intro show on every start? → A: Yes, briefly (≈1,8 s) while the
  app loads, then it fades; a tap skips it. With reduced motion the static end
  frame is shown for the same short time.
- Q: Branch base? → A: latest `main` (owner's rule), which already contains the
  recipe screens (#1) and the AI keys list (#2), so all of them are themed here.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose a theme and light/dark mode (Priority: P1)

In "Profil" the person opens "Izgled" and picks one of three themes —
"Bosiljak" (green, default), "Šafran" (warm orange) or "Borovnica" (blue) —
and a mode: "Svetla", "Tamna" or "Kao sistem" (default). The whole app
switches immediately, and the choice is kept after a restart.

**Why this priority**: the visible face of the app; everything else is themed by it.

**Independent Test**: change theme and mode, restart; the same theme is used.

**Acceptance Scenarios**:

1. **Given** a fresh install, **Then** the app uses "Bosiljak" and follows the system light/dark setting.
2. **Given** "Profil" → "Izgled", **When** the user taps "Šafran", **Then** the app recolours at once and the "Šafran" card shows as selected.
3. **Given** mode "Tamna", **When** the system is light, **Then** the app is still dark.
4. **Given** a chosen theme and mode, **When** the app restarts, **Then** the same theme and mode are used.
5. **Given** any of the 6 theme/mode combinations, **Then** every screen (recipes list, detail, add/edit, chat, AI keys, profile, placeholders) uses only that theme's colours — no fixed colours that clash in dark mode.

---

### User Story 2 - A calmer, consistent look (Priority: P1)

Cards are flat surfaces with a thin line border and rounded corners, chips are
pills (selected = filled primary), main buttons are tall with rounded corners,
the search field is 50 high with rounded corners, the bottom bar is a surface
with a thin top line and a pill-shaped highlight, the "Novi recept" button is
a rounded extended button, and all text uses Plus Jakarta Sans with bold,
slightly tight headings.

**Independent Test**: open each screen in each theme; components match the mockup.

**Acceptance Scenarios**:

1. **Given** the recipes list, **Then** recipe cards have the surface colour, a 1 px line border, radius 16–24 and no shadow; recipe tiles without a photo use the theme's tint colours.
2. **Given** the bottom bar on a phone, **Then** the active tab has a container-coloured pill and its label in the on-container colour.

---

### User Story 3 - Animations while waiting for AI (Priority: P2)

While the AI reads a photo, a scan line sweeps over the photo and the
"ingredients" appear one by one as chips. While it creates a recipe from a
name (or applies a chat change), a pot simmers with steam and bubbles and a
message rotates: "Seckam luk…", "Dodajem začine…", "Mešam…", "Probam da li
je slano…".

**Independent Test**: start "Iz slike" / "Po nazivu jela" with a slow fake AI; the animations show until the answer.

**Acceptance Scenarios**:

1. **Given** "Iz slike" with a photo, **When** the AI is working, **Then** the photo is shown with a moving scan line and a "Tražim sastojke…" chip; **When** the recipe arrives, **Then** the preview shows the photo with the recognised ingredients popping in one by one as chips.
2. **Given** "Po nazivu jela", **When** the AI is working, **Then** the simmering pot and a rotating message are shown with the cancel action still available.
3. **Given** reduced motion is on, **Then** the same pictures are shown still, with one fixed message.

---

### User Story 4 - Intro and empty states with ingredients (Priority: P2)

At launch a short intro shows the active theme's motif: a swaying basil sprig
with falling leaves (Bosiljak), a blooming saffron crocus (Šafran) or
blueberries dropping into a bowl (Borovnica), with "Tavli" and "Recepti, plan
obroka i kupovina na jednom mestu". The empty "Ostava" tab shows a fridge whose
door opens, its light flickers, and it is empty: "Ostava je prazna" / "Vreme je
za nabavku". The empty "Kupovina" tab shows the theme motif with "Lista je
prazna" / "Označi sastojke u receptu i pojaviće se ovde." Pulling the recipes
list down shows a wooden spoon stirring in a pot instead of the plain spinner.

**Acceptance Scenarios**:

1. **Given** app start, **Then** the intro with the active motif shows for about 1,8 s and fades; tapping it skips it.
2. **Given** the "Ostava" tab, **Then** the fridge animation and "Ostava je prazna" / "Vreme je za nabavku" are shown.
3. **Given** the "Kupovina" tab, **Then** the theme motif and "Lista je prazna" are shown.
4. **Given** the recipes list, **When** pulled down, **Then** the spoon-in-pot indicator is shown while it refreshes.

---

### User Story 5 - Ready-made animations for upcoming screens (Priority: P3)

For screens that are not built yet, the animations exist as reusable pieces and
can be seen in a debug-only "Animacije" gallery in "Profil":

- checking an ingredient: the checkmark draws in, a small chip flies to the
  "Kupovina" tab icon and its badge bumps (plugs into the ingredient checklist → shopping list spec);
- shopping list all bought: a shopping bag fills and a loaf of bread peeks out,
  "Sve je kupljeno!" (plugs into the shopping list);
- meal plan: a recipe dropped on a day lands on a plate in the calendar (plugs into the meal plan);
- cooking timer: an egg bobs in boiling water while the timer runs (plugs into a future cooking mode).

**Acceptance Scenarios**:

1. **Given** a debug build, **Then** "Profil" shows "Animacije" and the gallery lists all nine animations with their names; release builds do not show the entry.
2. **Given** reduced motion, **Then** every animation in the gallery shows its static end state.

### Edge Cases

- Saved theme value unknown (e.g. older/newer build) → fall back to "Bosiljak" / "Kao sistem".
- Database not ready yet at first frame → default theme until the setting loads (the intro covers the switch).
- Reduced motion (system "Reduce motion" / "Remove animations") → all animations static, intro still brief.
- Large text (scale 2.0) → theme cards and empty states wrap, no overflow.
- Wide window → appearance screen and gallery limited to a readable width.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST offer exactly three themes named "Bosiljak", "Šafran", "Borovnica", each with a light and a dark palette using the approved colour tokens (background, surface, primary, on-primary, container, on-container, text, muted text, line, box line, three tints).
- **FR-002**: The user MUST be able to choose the mode "Svetla", "Tamna" or "Kao sistem"; defaults are "Bosiljak" and "Kao sistem".
- **FR-003**: Theme and mode MUST be saved locally and restored at start; changes apply immediately without restart.
- **FR-004**: All screens MUST take colours only from the active theme; no fixed colours outside the theme definitions and the animation artwork (ingredient colours such as basil green or saffron red).
- **FR-005**: Typography MUST use the bundled Plus Jakarta Sans; headings weight 800 with slightly negative letter spacing.
- **FR-006**: Component styling MUST follow the mockup: flat bordered cards (radius 16–24, no elevation), pill chips (selected = primary fill), filled buttons 56 high with radius 18, search field 50 high with radius 16, navigation bar with surface background, top line and a container pill indicator with on-container label, extended FAB radius 20.
- **FR-007**: "Profil" MUST contain "Izgled" with theme cards ("Bosiljak", "Šafran", "Borovnica") showing a colour preview, and a mode selector ("Svetla", "Tamna", "Kao sistem").
- **FR-008**: The nine animations (intro motif ×3, photo scan with ingredient chips, simmering pot with rotating messages, ingredient check with flying chip and badge bump, filled shopping bag, empty fridge, spoon pull-to-refresh, plate on plan day, egg timer) MUST exist as reusable pieces.
- **FR-009**: Every animation MUST show a static end state when the platform asks for reduced motion.
- **FR-010**: The intro MUST follow the active theme, last ≈1,8 s, be skippable by tap, and never block the app on error.
- **FR-011**: The photo-scan animation MUST be shown on "Iz slike" while the AI works; the simmering pot on "Po nazivu jela" and while a chat change is being prepared.
- **FR-012**: "Ostava" and "Kupovina" tabs MUST show their animated empty states; the recipes list MUST use the spoon pull-to-refresh.
- **FR-013**: A debug-only "Animacije" gallery reachable from "Profil" MUST show every animation with its Serbian name.
- **FR-014**: Each animation MUST have a Serbian semantic label for screen readers.

### New UI copy (Serbian, Latin)

"Izgled", "Tema", "Režim", "Svetla", "Tamna", "Kao sistem", "Bosiljak",
"Šafran", "Borovnica", "Boje, tema i svetli ili tamni režim", "Animacije",
"Pregled animacija (samo za razvoj)", "Tavli", "Recepti, plan obroka i
kupovina na jednom mestu", "Tražim sastojke…", "Seckam luk…", "Dodajem
začine…", "Mešam…", "Probam da li je slano…", "Ostava je prazna", "Vreme je za
nabavku", "Lista je prazna", "Označi sastojke u receptu i pojaviće se ovde.",
"Sve je kupljeno!", "Kupovina", "Ponedeljak"…"Nedelja" (gallery), "Kuvam jaje",
"Ponovi". Animation names in the gallery: "Uvod — Bosiljak", "Uvod — Šafran",
"Uvod — Borovnica", "Skeniranje fotografije", "Lonac koji krčka", "Štikliranje
sastojka", "Sve kupljeno", "Prazna ostava", "Varjača (osvežavanje)", "Tanjir u
planu", "Tajmer sa jajetom". Semantic labels: "Grančica bosiljka", "Cvet
šafrana", "Borovnice padaju u činiju", "Skeniranje fotografije", "Lonac koji
krčka", "Prazan frižider", "Puna kesa za kupovinu", "Varjača u loncu", "Recept
na tanjiru", "Jaje se kuva".

### Key Entities

- **Theme choice**: theme id (bosiljak | safran | borovnica) and mode (light | dark | system), stored as two app settings.
- **Theme palette**: the colour tokens of one theme in one brightness.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 6 theme/mode combinations build and every existing screen renders in each without fixed colours (checked by tests and by searching the code).
- **SC-002**: A theme change is visible in under 300 ms and survives a restart in 100 % of tries.
- **SC-003**: With reduced motion on, no animation moves (verified for each piece by a test).
- **SC-004**: The intro never delays use of the app by more than 2 s.

## Assumptions

- Ingredient checklist, shopping list, meal plan and cooking timer screens are
  built in later specs; their animations are delivered as widgets and plug in
  there: `AnimatedCheckmark` + `flyChipToTarget` + `BumpBadge` into the recipe
  ingredient checklist and the "Kupovina" tab icon; `ShoppingBagFull` into the
  shopping list when all items are bought; `PlatePlanDrop` into the meal-plan
  calendar; `EggTimer` into a cooking mode.
- The recipes list has no remote data; pull-to-refresh re-reads the local list.
- Contrast of the approved palettes is accepted as designed.
