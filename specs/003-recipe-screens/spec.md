# Feature Specification: Recipe screens

**Feature Branch**: `003-recipe-screens`

**Created**: 2026-10-30

**Status**: Implemented

**Input**: User description: "Phase 2 — recipe screens. Recepti tab: list of saved recipes (search by title, newest first, empty state), recipe detail (title, servings, prep time, ingredients grouped by store category, steps, source photo, which model made it). Add a recipe three ways: from a photo (camera or gallery), from a dish name (servings + optional wishes), or manually (title, servings, prep minutes, ingredients, steps). AI-produced recipe is shown as a preview first and saved only when the user confirms. Edit via chat with the AI: each accepted change stores the previous version so the user can undo/restore older versions; chat history of instructions shown. Manual edit of an existing recipe and delete (with confirmation). All data local (offline-first); AI errors show Serbian messages. Works on phone and wide layout (list–detail on wide). Why: this is the first user-facing feature; the AI layer exists but there is no way to create, keep and edit recipes yet."

> All UI text is Serbian (Latin script). Quoted strings are the exact UI copy.

## Clarifications

### Session 2026-10-30

The owner was away; these answers are the recommended defaults, taken so work could continue, and can be changed before release.

- Q: Should an AI chat change apply immediately (with undo) or be proposed first? → A: Proposed first with "Prihvati"/"Odbaci"; only accepted changes are stored and shown in the chat history.
- Q: Do manual edits and restores also create versions? → A: Yes. Every change keeps the previous state, labelled "AI izmena", "Ručna izmena" or "Vraćena verzija", so any change can be undone.
- Q: What does "undo" do — step back or add another version? → A: "Poništi poslednju izmenu" steps back: it restores the newest kept version and removes it from history. Restoring an older version keeps the current state as a new version.
- Q: How many versions are kept? → A: The 30 most recent per recipe.
- Q: How are ingredients entered manually? → A: One entry per ingredient (name, quantity, unit, category, note) so grouping by store category works; steps are one per line.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browse and read saved recipes (Priority: P1)

The person opens the "Recepti" tab and sees their saved recipes, newest first,
each with its title, a small photo if there is one, servings and prep time.
They can search by title and open a recipe to read it: title, servings, prep
time, ingredients grouped by store category, numbered steps, the source photo,
and which AI model made it.

**Why this priority**: every other story produces recipes; without a list and
detail screen nothing created is visible or usable.

**Independent Test**: with recipes already in the local database, open the tab,
search, open a recipe; all fields are shown and nothing needs the network.

**Acceptance Scenarios**:

1. **Given** no recipes, **When** the tab opens, **Then** it shows "Još nema recepata" and "Dodaj prvi recept iz slike, po nazivu jela ili ručno." with the add action.
2. **Given** several recipes, **When** the tab opens, **Then** they are listed newest first.
3. **Given** recipes "Sarma" and "Pasulj", **When** the user types "sar" (or "šar") in "Pretraži recepte", **Then** only "Sarma" is listed; search ignores case and Serbian diacritics.
4. **Given** a search with no match, **Then** the list shows "Nema recepata za „{upit}“."
5. **Given** a recipe, **When** it is opened, **Then** ingredients appear under category headings in store order (e.g. "voće i povrće" before "začini i sosovi"), quantities use a decimal comma ("0,5 kg"), steps are numbered, and the footer shows "Napravio: {model}" for AI recipes or "Ručno unet" for manual ones.
6. **Given** a recipe without steps, **Then** the steps section shows "Koraci pripreme nisu uneti."
7. **Given** a wide window, **Then** the list and the opened recipe are shown side by side; on a phone the recipe opens as its own screen.

---

### User Story 2 - Add a recipe from a dish name (Priority: P1)

The person chooses "Po nazivu jela", types a dish name, picks the number of
servings (default 2) and optionally writes wishes ("bez luka", "posno"). The
AI creates a recipe, which is shown as a preview with "Sačuvaj", "Pokušaj
ponovo" and "Odbaci". It is saved only on "Sačuvaj".

**Why this priority**: the fastest way to get a useful recipe; needs no camera.

**Independent Test**: with a faked AI answer, create a recipe by name, save it,
and see it at the top of the list.

**Acceptance Scenarios**:

1. **Given** a dish name, **When** the user taps "Napravi recept", **Then** a progress indicator with "Pravim recept…" is shown and then the preview.
2. **Given** a preview, **When** the user taps "Sačuvaj", **Then** the recipe is stored, a "Recept je sačuvan." message is shown and the recipe opens.
3. **Given** a preview, **When** the user taps "Odbaci", **Then** nothing is stored.
4. **Given** a preview, **When** the user taps "Pokušaj ponovo", **Then** a new recipe is requested with the same inputs.
5. **Given** AI fails (limits, no keys, no network), **Then** the Serbian error message is shown with "Pokušaj ponovo", and the inputs are kept.
6. **Given** an empty dish name, **Then** "Napravi recept" is disabled.

---

### User Story 3 - Add a recipe from a photo (Priority: P1)

The person chooses "Iz slike", takes a photo ("Slikaj") or picks one from the
gallery ("Izaberi iz galerije") of a printed, handwritten or screenshot recipe.
The app shows the photo, reads the recipe with AI and shows the preview as in
Story 2. On save, the photo is kept with the recipe.

**Why this priority**: the main reason for the app — digitising family and cookbook recipes.

**Independent Test**: with a faked image picker and faked AI answer, pick an image, get the preview, save; the recipe has the photo.

**Acceptance Scenarios**:

1. **Given** a picked photo, **Then** it is shown while "Čitam recept sa slike…" is displayed.
2. **Given** the AI says the image holds no recipe, **Then** "Na slici nije pronađen recept." is shown with "Izaberi drugu sliku".
3. **Given** a saved photo recipe, **Then** its detail shows the photo and the list shows a thumbnail.
4. **Given** the user discards the preview, **Then** the photo is not kept.
5. **Given** a device without a camera (e.g. a Mac), **Then** only "Izaberi iz galerije" is offered.
6. **Given** the user cancels the picker, **Then** nothing happens and the screen stays as it was.

---

### User Story 4 - Edit a recipe by chatting with the AI, with undo (Priority: P2)

On a recipe the person opens "Izmeni sa AI" and writes a request such as "za 4
osobe", "bez glutena" or "dodaj pečurke". The AI proposes a changed recipe,
shown with "Prihvati" and "Odbaci". Accepted changes update the recipe and keep
the previous version. The chat lists earlier requests. The person can undo the
last change ("Poništi poslednju izmenu") or restore any earlier version from
"Prethodne verzije".

**Why this priority**: adapting recipes is the second most valuable AI use, but it needs saved recipes first.

**Independent Test**: with a faked AI answer, request a change, accept it, see the new recipe, undo, see the original again.

**Acceptance Scenarios**:

1. **Given** a recipe, **When** the user sends a request, **Then** "AI menja recept…" is shown and then the proposed recipe with "Prihvati" and "Odbaci".
2. **Given** a proposal, **When** "Prihvati" is tapped, **Then** the recipe is updated, the previous version is kept, and the request appears in the chat history with the time and the model that answered.
3. **Given** a proposal, **When** "Odbaci" is tapped, **Then** the recipe and version history are unchanged.
4. **Given** at least one earlier version, **When** "Poništi poslednju izmenu" is tapped, **Then** the recipe returns to the state before the last change and that change disappears from history.
5. **Given** several versions, **When** the user restores one from "Prethodne verzije", **Then** the recipe becomes that version and the version that was current is kept too, so the restore can be undone.
6. **Given** AI fails, **Then** a Serbian error is shown, the request text stays in the input, and the recipe is unchanged.

---

### User Story 5 - Add and edit recipes manually; delete (Priority: P2)

The person chooses "Ručno" and fills in "Naziv", "Broj porcija", "Vreme pripreme
(min)", ingredients (each with "Naziv", "Količina", "Jedinica", "Kategorija",
"Napomena") and steps (one per line). The same form edits an existing recipe
("Izmeni"). A recipe can be deleted ("Obriši recept") after confirming.

**Why this priority**: works fully offline and covers fixes the AI cannot make; less frequent than AI paths.

**Independent Test**: create a recipe manually without network, edit a quantity, delete it with confirmation.

**Acceptance Scenarios**:

1. **Given** an empty title or no ingredients, **When** "Sačuvaj" is tapped, **Then** "Unesi naziv recepta." / "Dodaj bar jedan sastojak." is shown and nothing is stored.
2. **Given** a manual edit of an existing recipe is saved, **Then** the previous version is kept and appears in history as "Ručna izmena", undoable like an AI change.
3. **Given** "Obriši recept", **Then** a dialog "Obrisati „{naziv}“?" with "Obriši" and "Otkaži" is shown; on "Obriši" the recipe, its versions and its photo are removed and the list no longer shows it.
4. **Given** the form has unsaved changes, **When** the user leaves, **Then** "Odbaciti izmene?" is asked.

---

### Edge Cases

- AI returns a recipe with a quantity like "1/2" or "0,5" → shown as "0,5"; "po ukusu" ingredients (no quantity) show only the name.
- AI returns an unknown category → ingredient goes under "ostalo".
- A very large photo → reduced before sending and storing so the request stays small and storage does not grow quickly.
- A photo file of a saved recipe is missing on disk (e.g. after restoring a backup) → the recipe shows without the photo, no crash.
- No network → browsing, searching, manual add/edit, undo/restore and delete all work; only AI actions show "Nema veze sa serverom. Proveri internet."
- The user leaves the AI screen while a request is running → the result is ignored, nothing is stored.
- Many AI edits on one recipe → only the 30 most recent previous versions are kept.
- Chat request is empty → send button disabled.
- Deleted recipe still open on a wide layout → detail pane shows "Izaberi recept".

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Recepti tab MUST list all saved recipes newest first, showing title, thumbnail (if any), servings and prep time.
- **FR-002**: Users MUST be able to filter the list by title; matching MUST ignore case and Serbian diacritics (č/ć→c, š→s, ž→z, đ→dj).
- **FR-003**: The recipe detail MUST show title, servings, prep time, the source photo, ingredients grouped by store category in store order, numbered steps, and the origin ("Napravio: {model}" / "Ručno unet").
- **FR-004**: Quantities MUST be displayed with a decimal comma and without trailing zeros.
- **FR-005**: Users MUST be able to create a recipe from a dish name with servings (1–20, default 2) and optional wishes.
- **FR-006**: Users MUST be able to create a recipe from a photo taken with the camera (where available) or picked from the gallery.
- **FR-007**: Photos MUST be reduced in size before being sent to the AI and stored on the device; the recipe keeps a reference to the stored photo.
- **FR-008**: AI-created recipes MUST be shown as a preview and stored only after the user confirms; discarding leaves no recipe or photo behind.
- **FR-009**: Users MUST be able to create and edit recipes manually; title and at least one ingredient are required.
- **FR-010**: Users MUST be able to request AI changes to a saved recipe in a chat; a proposal MUST be accepted before it changes the recipe.
- **FR-011**: Every change to a saved recipe (AI, manual, or restore) MUST keep the previous version with the kind of change, the request text (for AI changes), the model that answered, and the time.
- **FR-012**: Users MUST be able to undo the most recent change and to restore any kept version; restoring MUST itself be undoable.
- **FR-013**: At most 30 previous versions MUST be kept per recipe; older ones are dropped.
- **FR-014**: Users MUST be able to delete a recipe after confirmation; its versions and photo MUST be removed too.
- **FR-015**: All recipe data MUST be stored on the device and every non-AI action MUST work offline.
- **FR-016**: Every AI failure MUST show a Serbian message and keep the user's input so they can retry.
- **FR-017**: On wide windows the list and the selected recipe MUST be shown side by side; on phones the recipe opens full screen.

### Key Entities

- **Recipe**: title, servings, prep time, ingredients, steps, source (photo, AI, manual), photo reference, model that made or last changed it, created and updated time.
- **Ingredient**: name, quantity, unit, store category, note.
- **Recipe version**: a previous state of a recipe, with the kind of change that replaced it (AI, manual, restore), the AI request text if any, and the time.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A person can go from the Recepti tab to a saved AI recipe from a dish name in under 1 minute (excluding AI wait time) and in at most 4 taps plus typing the name.
- **SC-002**: A person can undo an unwanted AI change in one tap.
- **SC-003**: All non-AI recipe actions work with the network switched off.
- **SC-004**: Search results update while typing, for at least 500 saved recipes without noticeable delay.
- **SC-005**: Every screen in this feature is usable at phone width and in a wide window, verified by automated tests at both sizes.
- **SC-006**: A stored photo takes no more than about 1 MB.

## Assumptions

- One person uses the app on one device; no sync between devices in this phase.
- The AI is reached through the existing recipe AI functions and model chains; this feature adds no new AI provider or prompt type.
- Scaling servings without AI (multiplying quantities) is out of scope; the AI chat can do it ("za 4 osobe").
- Ticking ingredients and sending them to a shopping list is the next phase.
- Ratings, comfort food and meal plans that reference recipes come in later phases; deleting a recipe here only has to remove its own versions and photo (and any rows that would otherwise point at a missing recipe).
- Recipe photos stay on the device only; they are not uploaded anywhere except to the AI provider when reading the recipe.
