# Feature Specification: Account and sign-in (Nalog i prijava, 006a)

**Feature Branch**: `006-account-login` (created from latest `main`)

**Created**: 2026-10-30

**Status**: Draft

**Input**: User description: "Account is required from first launch, because all data is saved to the account. Backend: Supabase (EU region), decided. Scope 006a: sign-in screen right after the intro; passwordless email sign-in with a 6-digit one-time code (resend after 30 s); session stored in Keychain/Keystore and refreshed automatically; at sign-up a personal household is created automatically (tables profiles, households, household_members only; no invites yet) and the user is its owner (Vlasnik); existing local recipes, shopping list and other local data are moved into that household once, on first sign-in, without duplicates on later sign-ins; profile with name and initials avatar; sign out clears the local copy on the device; delete account in the app (confirmation, deletes personal data and membership on the server). Out of scope: Sign in with Apple and Google (006b, after the Apple Developer account), invites and roles (008), sync between devices (009), data export, AI proxy. Supabase keys must never be committed; use the existing secrets.json / --dart-define-from-file pattern for the Supabase URL and anon key. Row Level Security on every table."

> All UI text is Serbian (Latin script). Quoted strings are the exact UI copy.
> This is part "a" of the account phase; 006b adds Sign in with Apple and Google.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Sign in with an email code (Priority: P1)

After the intro, a person who is not signed in sees the sign-in screen
"Prijava" and nothing else of the app. They type their email
("E-pošta") and tap "Pošalji kod". The app says "Poslali smo kod na
{email}." and shows a field for the 6-digit code ("Kod iz poruke"). They type
the code from the email and are signed in. If no code arrives, "Pošalji ponovo"
becomes available after 30 seconds (counter "Pošalji ponovo za {s} s").
"Promeni e-poštu" goes back to the email step. The same flow is used for a new
and an existing account; there is no password.

**Why this priority**: every other part of the app (and every later feature) needs a signed-in account.

**Independent Test**: on a fresh install, enter an email, enter the code received, and land on the "Recepti" tab; restart the app and stay signed in.

**Acceptance Scenarios**:

1. **Given** a fresh install, **When** the intro ends, **Then** "Prijava" is shown and no tab of the app can be opened.
2. **Given** a valid email, **When** "Pošalji kod" is tapped, **Then** a 6-digit code is sent and the code step is shown with "Poslali smo kod na {email}.".
3. **Given** an invalid email format, **Then** "Pošalji kod" stays disabled and "Unesi ispravnu adresu e-pošte." is shown after the field loses focus.
4. **Given** the code step, **When** 6 digits are entered, **Then** the code is checked automatically (no extra tap needed); a correct code signs the person in.
5. **Given** a wrong code, **Then** "Kod nije ispravan. Proveri poruku i pokušaj ponovo." is shown and the field is cleared.
6. **Given** an expired code, **Then** "Kod je istekao. Pošalji novi kod." is shown.
7. **Given** less than 30 s since the last code, **Then** "Pošalji ponovo" is disabled and shows the remaining seconds; after 30 s it is enabled.
8. **Given** too many requests for one address, **Then** "Previše pokušaja. Sačekaj malo pa pokušaj ponovo." is shown.
9. **Given** no network, **Then** "Nema interneta. Za prijavu je potrebna veza." is shown and nothing else changes.
10. **Given** a signed-in person, **When** the app is restarted (also days later, also offline), **Then** they go straight from the intro to the app without signing in again.

---

### User Story 2 - Personal household and profile at sign-up (Priority: P1)

On the very first sign-in with a new email, an account is created together with
a personal household ("Moje domaćinstvo") whose only member is this person, with
the role "Vlasnik". The person is then asked "Kako da te zovemo?" (field "Ime",
button "Nastavi"). In "Profil" they see their initials avatar, name, email and
household name with the role "Vlasnik"; they can change the name ("Izmeni ime").

**Why this priority**: the household is the container all data is saved to; later features (invites 008, sync 009) build on it.

**Independent Test**: sign in with a new email, enter a name, open "Profil" and see the initials, name, email, "Moje domaćinstvo" and "Vlasnik".

**Acceptance Scenarios**:

1. **Given** a new email, **When** the code is confirmed, **Then** exactly one profile, one household and one membership (role owner) exist for that person on the server.
2. **Given** the name step, **When** "Ana Petrović" is entered, **Then** the avatar shows "AP"; for a single word "Ana" it shows "A".
3. **Given** an empty name, **Then** "Nastavi" is disabled; names are trimmed and limited to 40 characters.
4. **Given** an existing account signs in again (same or another device), **Then** no new household or membership is created and the name step is skipped.
5. **Given** the name step is interrupted (app closed), **When** the app is opened again, **Then** the name step is shown again before the app.
6. **Given** "Izmeni ime" in "Profil", **When** a new name is saved, **Then** the name and initials update everywhere in the app.

---

### User Story 3 - Existing local data moves into the household once (Priority: P1)

A person who already used the app before this version has recipes (with
versions and photos), a shopping list, pantry items, meal plans, ratings and a
taste profile on the device. On the first sign-in on that device, all of it is
moved into their household. A short message says
"Tvoji recepti i liste su sačuvani u nalogu." Later sign-ins never move or copy
it again.

**Why this priority**: an existing user must never lose or duplicate data because sign-in became mandatory.

**Independent Test**: install the previous version, add 3 recipes and 2 shopping items, update, sign in: exactly 3 recipes and 2 items belong to the household; sign out and in again: still 3 and 2.

**Acceptance Scenarios**:

1. **Given** 3 local recipes and a shopping list, **When** the person signs in for the first time on this device, **Then** all of them belong to the person's household and none is duplicated.
2. **Given** the move has finished, **When** the person signs in again later, **Then** nothing is moved again and no duplicates appear.
3. **Given** the move is interrupted (app killed, network lost), **When** the app starts again, **Then** the move resumes and the result is the same as an uninterrupted move (no missing and no doubled items).
4. **Given** a fresh install with no local data, **Then** no message is shown and nothing is moved.
5. **Given** local data and an account that already has a household (signed in before on another device), **Then** the local data is moved into that existing household (where it lives in 006a: see FR-012).

---

### User Story 4 - Sign out (Priority: P2)

In "Profil" the person taps "Odjavi se" and confirms in the dialog
"Odjaviti se? Podaci sa ovog uređaja biće uklonjeni. Ostaju sačuvani u nalogu."
(buttons "Odustani" / "Odjavi se"). The local copy of household and personal data
is removed from the device and the sign-in screen is shown.

**Why this priority**: needed for shared or handed-over devices and for switching accounts, but not for daily use.

**Independent Test**: sign in, add a recipe, sign out; the recipe list is gone from the device and "Prijava" is shown; signing in with another email shows none of the first person's data.

**Acceptance Scenarios**:

1. **Given** a signed-in person, **When** "Odjavi se" is confirmed, **Then** the session is removed from secure storage, the local copy of account data is cleared and "Prijava" is shown.
2. **Given** "Odustani", **Then** nothing changes.
3. **Given** sign-out and then sign-in with a different email, **Then** none of the first account's recipes, lists, profile or photos are visible.
4. **Given** sign-out while offline, **Then** the device is still cleared and signed out locally.
5. **Given** sign-out, **Then** device data that is not account data stays as decided in FR-018 (see FR-018).

---

### User Story 5 - Delete account in the app (Priority: P2)

In "Profil" → "Obriši nalog" the person sees what will be deleted
("Brisanjem naloga trajno se brišu tvoj profil, članstvo u domaćinstvu i
domaćinstvo sa svim podacima. Ovo ne može da se poništi.") and must type
"OBRIŠI" to enable the button "Trajno obriši nalog". After deletion the device
is cleared as on sign-out and "Prijava" is shown with "Nalog je obrisan."

**Why this priority**: required by App Store / Google Play rules and by privacy law (EU), but used rarely.

**Independent Test**: create an account, delete it in the app; the server has no profile, membership or household for it, and signing in with the same email creates a brand-new empty account.

**Acceptance Scenarios**:

1. **Given** the delete screen, **When** "OBRIŠI" is not typed exactly, **Then** "Trajno obriši nalog" stays disabled.
2. **Given** confirmation, **Then** the profile, the membership, the personal household (the person is its only member) and the sign-in identity are deleted on the server, and the device is cleared.
3. **Given** no network, **Then** "Nema interneta. Nalog može da se obriše samo uz vezu." is shown and nothing is deleted or cleared.
4. **Given** a server error, **Then** "Brisanje nije uspelo. Pokušaj ponovo." is shown and the person stays signed in.
5. **Given** a deleted account, **When** the same email signs in again, **Then** a new empty account and household are created.

---

### User Story 6 - Session stays valid and is protected (Priority: P2)

The session is kept in the platform secure storage (Keychain / Keystore) and
renewed automatically in the background. If it can no longer be renewed (revoked
or account deleted elsewhere), the person is sent back to "Prijava" with
"Sesija je istekla. Prijavi se ponovo." The local data is not cleared in that
case, so signing in again with the same account continues where they left off.

**Independent Test**: sign in, simulate an expired access token; the next server call renews it without any visible change. Simulate a revoked session; "Prijava" appears with the message.

**Acceptance Scenarios**:

1. **Given** an expired short-lived token and a valid renewal, **Then** the renewal happens silently.
2. **Given** an invalid renewal, **Then** "Prijava" is shown with "Sesija je istekla. Prijavi se ponovo."
3. **Given** sign-in again with the same email after an expired session, **Then** the local data is still there; with a different email the device is cleared first.
4. **Given** no network, **Then** the app stays usable with the stored session; renewal is retried when the network returns.

### Edge Cases

- Email typed with spaces or capital letters → trimmed and compared case-insensitively ("Ana@Mail.com" and "ana@mail.com" are the same account).
- Code pasted from the clipboard with spaces or as "123 456" → only digits are taken.
- A code requested twice → only the newest code is valid; the older one gives "Kod nije ispravan…".
- App closed on the code step → on reopening, the email step is shown again (no stored half-state).
- Account deleted on another device while this one is signed in → next renewal fails, "Sesija je istekla…" is shown, and signing in creates a new account.
- Very large local data (hundreds of recipes with photos) during the first move → a progress indicator "Čuvam tvoje podatke…" is shown and the app is not blocked longer than needed.
- Supabase URL or anon key missing from the build → "Prijava trenutno nije dostupna." on the sign-in screen and no crash (developer build without `secrets.json`).
- The person tries to open a deep link to a tab while signed out → sent to "Prijava"; after sign-in they land on the requested tab.
- Name with only spaces → treated as empty. Initials from names with diacritics ("Đorđe Šćepanović" → "ĐŠ") keep the diacritics.

## Requirements *(mandatory)*

### Functional Requirements

**Access**

- **FR-001**: The app MUST require a signed-in account before any tab or screen other than the intro and the sign-in flow can be opened.
- **FR-002**: The sign-in screen MUST be shown right after the intro whenever there is no valid stored session.

**Email code sign-in**

- **FR-003**: The only sign-in method in 006a MUST be passwordless email with a 6-digit one-time code; the same flow MUST create a new account or sign into an existing one.
- **FR-004**: The code entry MUST accept exactly 6 digits, ignore spaces, and check the code automatically when the 6th digit is entered.
- **FR-005**: Resending a code MUST be possible only 30 s after the previous send, with a visible countdown.
- **FR-006**: Sign-in failures (wrong code, expired code, too many requests, no network, service unavailable) MUST each show the Serbian message listed in this spec and never crash.

**Session**

- **FR-007**: The session MUST be stored only in the platform secure storage (Keychain / Keystore), never in the local database, logs or plain files.
- **FR-008**: The session MUST be renewed automatically; when renewal is impossible the person MUST be returned to sign-in with "Sesija je istekla. Prijavi se ponovo." without clearing local data.
- **FR-009**: A signed-in person MUST be able to use the app offline, including after a restart, for all actions that do not need the network.

**Account, household, profile**

- **FR-010**: On the first sign-in of a new account the system MUST create, exactly once, a profile, a personal household named "Moje domaćinstvo" and a membership with the role owner ("Vlasnik").
- **FR-011**: The profile MUST hold a display name (1–40 characters after trimming), asked once after the first sign-in ("Kako da te zovemo?") and editable in "Profil"; the avatar MUST show the initials (first letter of the first and the last word, uppercase, max 2 letters) on a colour derived from the theme.

**Moving local data**

- **FR-012**: On the first sign-in on a device, all existing local user data (recipes with versions and photos, shopping lists and items, pantry items, meal plans and entries, ratings, taste profile) MUST be moved into the person's household exactly once, resumable after interruption, without duplicates on later sign-ins. [NEEDS CLARIFICATION: In 006a (sync is 009), is the moved data uploaded to the server now, or only marked locally as belonging to the household and uploaded by 009? This decides whether sign-out (FR-016) can safely clear the device.]
- **FR-013**: The move MUST be recorded per device and per account, so a later sign-in by the same account on the same device never repeats it.

**Server data and security**

- **FR-014**: The server MUST hold only profiles, households and household memberships in 006a, in the EU region; every table MUST enforce row-level access rules so a person can read and change only their own profile and only households they are a member of.
- **FR-015**: The server connection details (project URL and public anon key) MUST come from the gitignored build-time secrets file (same pattern as the built-in AI keys) and MUST never be committed, logged or shown; no server admin key may ever be in the app.

**Sign out and delete**

- **FR-016**: "Odjavi se" (with confirmation) MUST remove the stored session and clear the local copy of all account and household data (including recipe photos) from the device, then show "Prijava".
- **FR-017**: "Obriši nalog" MUST require typing "OBRIŠI", then delete on the server the profile, the membership, the person's household when they are its only member, and the sign-in identity; then clear the device as on sign-out. It MUST only run online and MUST NOT clear anything if the server deletion fails.
- **FR-018**: Device-level data MUST be handled on sign-out and account deletion as follows: theme choice and AI model cooldowns stay on the device; [NEEDS CLARIFICATION: Are the person's own AI keys (Keychain) removed on sign-out/delete, or kept on the device for the next person who signs in?]

**Profile screen**

- **FR-019**: "Profil" MUST show, above the existing entries, the avatar, name, email, household name with the role "Vlasnik", and the actions "Izmeni ime", "Odjavi se" and "Obriši nalog".
- **FR-020**: All new screens MUST work at phone width and on wide windows (rail layout), and all new UI text MUST be the Serbian (Latin) copy listed below.

### Out of scope (006a)

- Sign in with Apple and Google (006b, after the Apple Developer account).
- Invites, joining another household, roles other than owner, leaving or transferring a household (008).
- Sync between devices and server tables for recipes, lists, pantry, plans (009), unless FR-012 is answered "upload now".
- Data export, the AI key proxy, push notifications.

### UI copy (Serbian, Latin)

| Where | Text |
|-------|------|
| Sign-in title | "Prijava" |
| Sign-in subtitle | "Prijavi se e-poštom. Poslaćemo ti kod, lozinka nije potrebna." |
| Email field | "E-pošta" |
| Send button | "Pošalji kod" |
| Invalid email | "Unesi ispravnu adresu e-pošte." |
| Code sent | "Poslali smo kod na {email}." |
| Code field | "Kod iz poruke" |
| Resend | "Pošalji ponovo" / "Pošalji ponovo za {s} s" |
| Change email | "Promeni e-poštu" |
| Wrong code | "Kod nije ispravan. Proveri poruku i pokušaj ponovo." |
| Expired code | "Kod je istekao. Pošalji novi kod." |
| Rate limit | "Previše pokušaja. Sačekaj malo pa pokušaj ponovo." |
| Offline sign-in | "Nema interneta. Za prijavu je potrebna veza." |
| Service unavailable | "Prijava trenutno nije dostupna." |
| Name step | "Kako da te zovemo?" / field "Ime" / button "Nastavi" |
| Household default name | "Moje domaćinstvo" |
| Role | "Vlasnik" |
| Data moved | "Tvoji recepti i liste su sačuvani u nalogu." |
| Move progress | "Čuvam tvoje podatke…" |
| Edit name | "Izmeni ime" / button "Sačuvaj" |
| Sign out | "Odjavi se" |
| Sign-out dialog | "Odjaviti se? Podaci sa ovog uređaja biće uklonjeni. Ostaju sačuvani u nalogu." / "Odustani" / "Odjavi se" |
| Session expired | "Sesija je istekla. Prijavi se ponovo." |
| Delete account | "Obriši nalog" |
| Delete text | "Brisanjem naloga trajno se brišu tvoj profil, članstvo u domaćinstvu i domaćinstvo sa svim podacima. Ovo ne može da se poništi." |
| Delete confirm hint | "Upiši OBRIŠI da potvrdiš." |
| Delete button | "Trajno obriši nalog" |
| Delete offline | "Nema interneta. Nalog može da se obriše samo uz vezu." |
| Delete failed | "Brisanje nije uspelo. Pokušaj ponovo." |
| Deleted | "Nalog je obrisan." |

### Key Entities

- **Account (sign-in identity)**: one per email address; created on the first confirmed code; owned by the sign-in service.
- **Profile**: one per account; display name, email (read-only), created date. Initials are derived, not stored.
- **Household**: name (default "Moje domaćinstvo"), created by, created date. In 006a every account has exactly one.
- **Household membership**: account + household + role (only "owner" in 006a) + joined date; one per account in 006a, the model allows more later.
- **Local data move record**: per device and account — whether the one-time move of local data has finished (and how far it got, for resuming).
- **Local user data** (existing): recipes and versions, recipe photos, shopping lists and items, pantry items, meal plans and entries, ratings, taste profile; gains a link to the household it belongs to.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new person gets from the end of the intro to the "Recepti" tab in under 2 minutes, including reading the email code.
- **SC-002**: After the first sign-in, opening the app (online or offline) never asks for sign-in again for at least 30 days of regular use, unless the person signs out or the account is deleted.
- **SC-003**: For an existing user, 100% of local recipes, versions, photos, list items, pantry items, plans and ratings are present after the first sign-in, and the counts are unchanged after 3 more sign-out/sign-in cycles on the same device (automated test).
- **SC-004**: A person can never read or change another account's profile, household or membership (verified by automated access-rule tests against the server rules with two test accounts).
- **SC-005**: After sign-out, no recipe, list, profile or photo of the previous account is visible to the next person who signs in on the device.
- **SC-006**: After "Obriši nalog", no profile, membership or household of that account remains on the server.
- **SC-007**: No server key, session token or email code appears in the repository, logs or test fixtures (checked in review and by searching the repository).

## Assumptions

- "Intro" is the themed intro from spec 005 (≈1,8 s, skippable); if 005 is not merged yet, the sign-in screen follows the app start directly.
- The 6-digit code is valid for a limited time set on the server (assumed 10 minutes) and can be used once; the sign-in email itself is sent by the backend in Serbian.
- Email delivery uses a proper sending setup on the backend; the free default mailer's hourly limit is too low for real use, so a custom sender (needs the app domain) is a prerequisite for release, not for development.
- One household per account in 006a; the data model allows more later (008).
- The account email cannot be changed in 006a.
- The household name cannot be changed in 006a (it is not shown to anyone else until invites exist).
- Recipe photos stay files on the device in 006a; they are part of the local data that is moved and cleared.
- Existing AI key, theme and model cooldown storage stays per device.

## Dependencies

- Supabase project in the EU region, with email one-time-code sign-in enabled and the email template set to send a 6-digit code (owner action).
- Supabase URL and anon key in the local gitignored `secrets.json` (owner action; `secrets.example.json` gets empty placeholders).
- **Constitution amendment**: principle II ("No backend account or cloud sync is assumed") contradicts a required account; it must be amended (with a Sync Impact Report) before or together with `/speckit-plan`. Offline-first stays: drift remains the local source of truth.
- Spec 005 (intro) for the intro → sign-in order; not a hard dependency.
