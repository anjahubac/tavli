# Main flow in the running app (CAP-02, CAP-04)

Text record of one screen recording and 21 screenshots of the main flow in the
running app: sign-in, recipe by dish name, review, plan, shopping list, pantry.
It was recorded by Aleksa on 2026-11-24 between 15:19 and 15:23. Each claim
below was checked against the screenshots; where the recorder's notes and the
screenshots disagree, the screenshots are followed and the difference is listed
under [Corrections to the recorder's notes](#corrections-to-the-recorders-notes).

**The screenshots and the recording are not in this repository.** They are
binaries and stay outside it (in a pull request comment or the members' own
reports). No link to them is recorded here yet; add it when the comment exists.
Nothing below depends on opening them.

## Setup

- **Build** (recorder's note): Windows debug build of branch
  `feat/fasting-slava-dates` at `8a3e481` (`dev` at `c64d8d7`, after #181, plus
  the slava dates of #183), started with
  `flutter run -d windows -t lib/main.dart --dart-define-from-file=secrets.json`.
  Both commits exist in the repository. The screenshots show a Windows window
  frame, which fits the note; they do not show the commit.
- **Gateway: hosted, not local** (recorder's note). The recorder says the
  backend was the hosted Supabase project named in the local `secrets.json`, so
  sign-in, sync and AI went through the real server and the `ai-gateway`, and
  the app held no provider key. The screenshots do not show which backend it
  was; what they do show is that an AI recipe was produced signed in, with the
  line "Napravio: Groq GPT-OSS 120B", and `openai/gpt-oss-120b` is in the
  gateway's Groq model list (`supabase/functions/ai-gateway/providers.ts`). The
  local-stack gateway run with a synthetic user is
  [gateway-flow.md](../../evals/capstone/gateway-flow.md).
- **Data**: an empty cache at the start (the recipe list is empty in the first
  recipe screenshot), a real email account, no recipes or plan.
- No email address or code is copied here.

This is one recorded run, not a test suite.

## What the screenshots show

### 1. Sign-in

- **Prijava** with an address that has no account: "Ne postoji nalog sa ovom
  adresom. Proveri adresu ili napravi nov nalog." with a **Registruj se** link
  (screenshot 01).
- An invalid address: the field is marked "Unesi ispravnu adresu e-pošte." and
  **Pošalji kod** stays disabled (02).
- **Upiši kod** with a wrong code: "Kod nije ispravan. Proveri poruku i
  pokušaj ponovo." (03).
- The code from the email: all six digits entered, a spinner while it is
  checked, no button pressed (04).
- First sign-in asks once for the name that household members see: "Kako da te
  zovemo?" (05, and a second name screen, 06).

### 2. Recipe from AI, review and confirmation

- **Recepti** is empty ("Još nema recepata") with **Dodaj recept** (07).
- **Recept po nazivu jela** "Sarma": the AI recipe is shown for review with
  labels (**Obrok**: Ručak, Večera; **Težina**: Jak; **Vrsta jela**: Kuvano
  jelo), ingredients by category and numbered steps. The bottom bar has
  **Odbaci**, **Proveri sastojke**, **Pokušaj ponovo** and **Sačuvaj**; nothing
  is saved yet (08).
- **Proveri sastojke**: 4 servings with a stepper, "Označi šta imaš kod kuće",
  one tick box per ingredient, and **Dodaj u nabavku (10)** (09).
- After adding: "Dodato u nabavku: 10" with **Otvori**. The recipe screen is
  still the preview, and the footer reads "Napravio: Groq GPT-OSS 120B" (10).
  According to the recorder this recipe was then left without **Sačuvaj**.
- Review of "Musaka za dvoje" (2 porcije; **Obrok**: Večera; **Težina**: Jak;
  **Vrsta jela**: Pečeno ili prženo) with the same four buttons (12).
- The end of a recipe screen with **Sačuvaj** greyed out while it is saved,
  ingredients grouped by category and the same "Napravio" footer (13).

### 3. Meal plan

- **Plan → Novi plan**: **Nedelja** 24–29 November 2026, only **Doručak**
  selected, 2 servings, **Koristi ostavu** on ("Samo potvrđene namirnice"),
  free-text **Posebni zahtevi**, "6 obroka · 2 porcije po obroku" (14).
- **Predloži plan**: "Pripremam plan… Pripremljeno 1 od 6 obroka" and later
  "4 od 6", with **Prekini**. Meals are marked "Nov recept" or "Iz mojih
  recepata"; unfinished ones read "sastojci još nisu spremni" (15, 16).
- A banner says "Ukusi članova trenutno nisu dostupni, pa ovaj predlog ne
  uzima u obzir šta ko voli." The sheet for one meal offers **Predloži drugo**
  ("AI predlaže novo jelo za ovaj obrok") and **Iz mojih recepata**; the
  proposal has **Sačuvaj plan**, **Promeni izbore** and **Odbaci** (17).
- **Sačuvaj plan** → "Plan je sačuvan." The week view shows one breakfast per
  day from Tuesday 24 to Sunday 29 November (18).

### 4. Shopping list and pantry

- **Nabavka → Po planu**, week 24–29 November: the plan's ingredients by
  category, a manual add field ("npr. deterdžent"), and a side panel for the
  selected item that says which meal it is for ("banana … Grčki jogurt sa
  svežim voćem, Petak 27. novembar · Doručak · 2 porcije"). Ticking an item
  gives "Kupljeno: avokado" with **Poništi**, and **Prebaci u ostavu (1)** (19).
- Bought items sit in a "Kupljeno · 7" group with "U ostavi" next to each one
  (20).
- A toast "Prebačeno u ostavu: 1" and **Ostava → Šta da skuvam?**: saved
  recipes ranked by what is missing ("Fali 2: grčki jogurt, med" to "Fali 8:
  šargarepa, mleveno meso, +6"); "So, biber, ulje i voda se ne računaju" (21).

## Findings

1. **A heavy dinner was planned as breakfast.** The proposal put "Musaka za
   dvoje" (labels in screenshot 12: Večera, Jak) on Thursday's breakfast, from
   "Iz mojih recepata", before any manual change (16, 17, 18). Spec 019's
   meal-placement rules should keep a dinner-only, heavy dish out of breakfast.
   Whether the rule applies to library recipes in this path needs a check; plan
   generation is Aleksa's area.
2. **Members' tastes were not used.** The banner in 17 says so. The recorder
   notes that the tastes and favorites request (`planning-inputs`, #146) did
   not succeed on this backend during the run; the screenshots show only the
   banner, not the cause.
3. **Ingredients of an unsaved recipe reached the shopping list.** "Sarma"
   added 10 items (10) and was, per the recorder, left without **Sačuvaj**.
   Whether adding to the list from an unsaved preview is intended should be
   confirmed.
4. **Two rows for one ingredient.** The plan list has "crni luk 1 glavica" and
   "crni luk 1 kom" as separate rows (19). The units differ, so this may be the
   intended rule, but the list does not show a combined total. It is not the
   "200 g + 0,5 kg = 700 g" case, which this run does not contain.
5. **Short flash after saving the plan** (recorder's note, not visible in a
   still): the "Predlog plana — Nema otvorenog predloga" screen shows for under
   a second before the week view. Cosmetic.

## Corrections to the recorder's notes

The recorder's list of screenshots did not match the files in several places.
This document uses the files.

- The file named `06-home` is a second name screen ("tim tavli", button still
  grey), not **Početna**; no screenshot shows the home screen or the "Post i
  praznici" card.
- The file named `11-recipe-by-name-musaka` is a screenshot of a GitHub pull
  request page, not of the app. There is no screenshot of "Pravim recept…".
  It also shows usernames, so it must not be used as evidence.
- The file named `13-recipe-saved` shows the end of the preview with
  **Sačuvaj** greyed out, not the library with **Kuvaj**, **Dodaj u plan**,
  **Omiljeni** and **Oceni**. The saved recipe is not shown in the library; its
  presence is shown only indirectly, because "Musaka za dvoje" is later offered
  to the plan as "Iz mojih recepata" (16) and in **Šta da skuvam?** (21).
- The progress lines "1 od 6" and "4 od 6" are in files 15 and 16; the banner
  about tastes is in file 17, one number later than the notes say.
- The bought group reads "Kupljeno · 7" (20), not 8.
- **Otvori nabavku** after saving the plan is not visible in 18 (the button
  row is cut off).
- The recorder says the address is covered in screenshots 2 to 4. In `01` an
  address is readable; it looks like a test address, not the real account's.
  The code in `04` is readable and was one-time, per the recorder expired.

## Not proven by this run

- Recipe from a **photo**, the review screen with unconfirmed items marked,
  and the controlled error for an **unreadable photo** in the running app. The
  photo prompt and the controlled error are recorded only through the runner in
  [gateway-flow.md](../../evals/capstone/gateway-flow.md) (GW-01, GW-02, GW-04,
  local stack).
- A **shopping total** that adds quantities from two sources (for example
  200 g and 0,5 kg to 700 g) in the app. The deterministic case is EV-04 in
  `test/evals/capstone_eval_test.dart`.
- The recipe **library after saving**, and the Home screen.
- Recipe by **voice**, from a **cookbook**, and editing a recipe by chat.
- A **second household member**: invitation, joining, and a change on one
  device appearing on the other (Realtime).
- **Allergens** in plan generation: #180 merged after this build.
- Saving a **rating**, marking a **favorite**, cooking mode and "Označi kao
  skuvano".
- **Post i praznici** questions, including slava dates.
- Any platform other than Windows, and a check of the hosted configuration
  itself (the recorder's note is the only source for it).
