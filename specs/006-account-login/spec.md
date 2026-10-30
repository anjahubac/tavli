# Feature Specification: Account, sign-in and server storage (Nalog i prijava, 006a)

**Feature Branch**: `006-account-login` (created from latest `main`)

**Created**: 2026-10-30

**Status**: Planned (plan, tasks, analyze done; ready for `/speckit-implement`)

**Input**: User description: "Account is required from first launch, because all data is saved to the account. Backend: Supabase (EU region), decided. Scope 006a: sign-in screen right after the intro; passwordless email sign-in with a 6-digit one-time code (resend after 30 s); session stored in Keychain/Keystore and refreshed automatically; at sign-up a personal household is created automatically and the user is its owner (Vlasnik); existing local recipes, shopping list and other local data are moved into that household once, on first sign-in, without duplicates on later sign-ins; profile with name and initials avatar; sign out; delete account in the app. Out of scope: Sign in with Apple and Google (006b, after the Apple Developer account), invites and roles (008), data export, AI proxy. Supabase keys must never be committed; use the existing secrets.json / --dart-define-from-file pattern for the Supabase URL and anon key. Row Level Security on every table."

> All UI text is Serbian (Latin script). Quoted strings are the exact UI copy.
> This is part "a" of the account phase; 006b adds Sign in with Apple and Google.

## Clarifications

### Session 2026-10-30

- Q: In 006a, is the user's data uploaded to the server now, or only marked locally and uploaded by a later sync feature? → A: "Da bi koristio app treba da se uloguješ, tako da će svi podaci uvek biti slani u bazu; podaci se čuvaju pri odjavi, brišu samo ako ih korisnik obriše ili obriše nalog." The app cannot be used without an account, and **all** of the user's data (recipes with versions and photos, shopping lists, pantry, meal plans, ratings, preferences, profile) is always saved on the server. The local database stays as the offline cache: every change is written locally first, queued, and uploaded when the device is online. On sign-in on any device the account's data is downloaded. Sign-out does **not** delete data; data is deleted only when the user deletes it (an item) or deletes the account. Realtime sharing between household members and handling of simultaneous edits by several people or devices stay for 009.
- Q: Are the person's own AI keys removed on sign-out / account deletion? → A: Kept on sign-out; deleted on account deletion.
- Q: Is the name step "Kako da te zovemo?" mandatory? → A: Yes, once, right after the first sign-in; the app cannot be used before a name is saved.
- Q: Is an account mandatory to use the app at all (constitution principle II said "no backend account")? → A: Yes. The constitution is amended on this branch (2.0.0): offline-first with a mandatory account and the server as the durable store; no secrets in the repo; Row Level Security on every table; tables are not exposed automatically, access is granted explicitly.
- Q: How is account deletion confirmed? → A: A simple confirmation dialog with a red "Obriši nalog" button; no typing of a confirmation word.
- Q: Are the assumptions added during clarification confirmed? → A: Yes, the user confirmed all five: (1) other devices' changes are fetched on app start and on return to the foreground after at least 15 minutes (FR-015, US4-3); (2) sign-out warns about unsent changes and keeps them on the device for the same account (FR-023, US6-4); (3) the save state is shown in "Profil" (FR-018); (4) account deletion deletes the person's solo household with all its data and photos (FR-024, US7-2); (5) the last write to reach the server wins per record and a deletion wins over an edit (FR-017).

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

**Why this priority**: the app cannot be used without an account; every other part of the app needs it.

**Independent Test**: on a fresh install, enter an email, enter the code received, enter a name and land on the "Recepti" tab; restart the app and stay signed in.

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

### User Story 2 - Personal household and mandatory name at sign-up (Priority: P1)

On the very first sign-in with a new email, an account is created together with
a personal household ("Moje domaćinstvo") whose only member is this person, with
the role "Vlasnik". The person must then answer "Kako da te zovemo?" (field
"Ime", button "Nastavi"); the app is not usable until a name is saved. In
"Profil" they see their initials avatar, name, email and household name with
the role "Vlasnik"; they can change the name ("Izmeni ime").

**Why this priority**: the household is the container all data is saved to; later features (invites 008, sharing 009) build on it.

**Independent Test**: sign in with a new email, enter a name, open "Profil" and see the initials, name, email, "Moje domaćinstvo" and "Vlasnik".

**Acceptance Scenarios**:

1. **Given** a new email, **When** the code is confirmed, **Then** exactly one profile, one household and one membership (role owner) exist for that person on the server.
2. **Given** the name step, **When** "Ana Petrović" is entered, **Then** the avatar shows "AP"; for a single word "Ana" it shows "A".
3. **Given** an empty name, **Then** "Nastavi" is disabled; names are trimmed and limited to 40 characters. The step has no "skip" or back action.
4. **Given** an existing account with a saved name signs in again (same or another device), **Then** no new household or membership is created and the name step is skipped.
5. **Given** the name step is interrupted (app closed), **When** the app is opened again, **Then** the name step is shown again before the app.
6. **Given** "Izmeni ime" in "Profil", **When** a new name is saved, **Then** the name and initials update everywhere in the app and on the server.

---

### User Story 3 - All data is saved to the account, also offline (Priority: P1)

Everything the person creates or changes (recipes and their versions and
photos, shopping lists and items, pantry items, meal plans, ratings, taste
preferences, profile) is saved on the device immediately and then sent to the
account. Without network the app keeps working; changes wait on the device and
are sent automatically when the network returns. "Profil" shows whether
everything is saved ("Sve je sačuvano u nalogu.") or how many changes are
waiting ("Čeka slanje: {n}").

**Why this priority**: the account exists so the data is never lost with the device; the user decided all data is always saved to the server.

**Independent Test**: sign in, go offline, add a recipe with a photo and edit it twice; "Čeka slanje" is shown; go online; within a minute "Sve je sačuvano u nalogu." is shown and the recipe, its versions and the photo exist on the server.

**Acceptance Scenarios**:

1. **Given** a signed-in person online, **When** they add, edit or delete a recipe, list item, pantry item, plan entry, rating or preference, **Then** the change is visible on the device at once and is on the server within 10 seconds.
2. **Given** no network, **When** they make changes, **Then** the app behaves exactly as online, the changes are kept on the device in order, and "Čeka slanje: {n}" is shown in "Profil".
3. **Given** waiting changes, **When** the network returns or the app is started online, **Then** the changes are sent in the order they were made, each exactly once, and nothing is duplicated on the server even if sending was interrupted.
4. **Given** a recipe photo, **Then** the (already downscaled) photo is uploaded to the account's private storage; only members of the household can read it.
5. **Given** a change the server rejects permanently (e.g. invalid data), **Then** it does not block the other waiting changes; it is kept on the device and reported in "Profil" as "Neke izmene nisu sačuvane u nalogu." (no crash, no data loss on the device).
6. **Given** the person deletes an item, **Then** it is deleted on the server too; nothing is deleted on the server for any other reason except account deletion.

---

### User Story 4 - Data is downloaded on sign-in on any device (Priority: P1)

When an existing account signs in on a new or reinstalled device, its data is
downloaded from the server ("Preuzimam tvoje podatke…") and the person sees
their recipes, lists, pantry, plans, ratings, preferences and photos. When the
app starts online, it also fetches changes made on the account's other devices
since the last time.

**Why this priority**: saving to the server is only useful if the data comes back.

**Independent Test**: on device A sign in and add 3 recipes (one with a photo) and 2 shopping items; on device B sign in with the same email: exactly 3 recipes (with the photo) and 2 items appear.

**Acceptance Scenarios**:

1. **Given** an account with data on the server and a device without it, **When** the person signs in, **Then** all of the account's data is downloaded and shown; photos may finish loading after the list is shown.
2. **Given** the download is interrupted (app killed, network lost), **When** the app starts again online, **Then** the download continues and the end result is complete with no duplicates.
3. **Given** changes made on device A, **When** device B starts online (or is brought back to the foreground after at least 15 minutes), **Then** device B fetches and shows them (not instantly; realtime is 009).
4. **Given** a device that already has the account's data cached, **When** the same account signs in again, **Then** only changes since the last fetch are downloaded.

---

### User Story 5 - Existing local data moves into the account once (Priority: P1)

A person who used the app before this version has recipes (with versions and
photos) and possibly other data on the device that belongs to no account. On
the first sign-in on that device, all of it is moved into their account's
household and sent to the server. A short message says
"Tvoji recepti i liste su sačuvani u nalogu." Later sign-ins never move or
copy it again.

**Why this priority**: an existing user must never lose or duplicate data because sign-in became mandatory.

**Independent Test**: install the previous version, add 3 recipes and 2 shopping items, update, sign in: exactly 3 recipes and 2 items belong to the household on the device and on the server; sign out and in again: still 3 and 2.

**Acceptance Scenarios**:

1. **Given** 3 local recipes and a shopping list without an account, **When** the person signs in for the first time on this device, **Then** all of them belong to the person's household, are queued for upload and none is duplicated.
2. **Given** the move has finished, **When** anyone signs in again later on this device, **Then** nothing is moved again and no duplicates appear.
3. **Given** the move is interrupted (app killed, network lost), **When** the app starts again, **Then** the move resumes and the result is the same as an uninterrupted move (no missing and no doubled items).
4. **Given** a fresh install with no local data, **Then** no message is shown and nothing is moved.
5. **Given** local data and an account that already has data on the server (used on another device), **Then** the local data is added to that account's household next to the downloaded data (nothing is overwritten).

---

### User Story 6 - Sign out keeps the data (Priority: P2)

In "Profil" the person taps "Odjavi se" and confirms in the dialog
"Odjaviti se? Tvoji podaci ostaju sačuvani u nalogu." (buttons "Odustani" /
"Odjavi se"). The session is removed and "Prijava" is shown. The data stays on
the server and in the device cache, hidden; it is shown again only when the same
account signs in on this device. Another account signing in on the device sees
only its own data.

**Why this priority**: needed for switching accounts and shared devices, but not for daily use.

**Independent Test**: sign in as A, add a recipe, sign out; "Prijava" is shown; sign in as B: none of A's data is visible; sign out, sign in as A: the recipe is there at once, without downloading it again.

**Acceptance Scenarios**:

1. **Given** a signed-in person, **When** "Odjavi se" is confirmed, **Then** the session is removed from secure storage and "Prijava" is shown; no data is deleted on the server.
2. **Given** "Odustani", **Then** nothing changes.
3. **Given** sign-out and then sign-in with a different email, **Then** none of the first account's recipes, lists, profile or photos are visible.
4. **Given** sign-out with changes still waiting to be sent, **Then** the dialog adds "Neke izmene još nisu poslate. Poslaćemo ih kada se ponovo prijaviš na ovom uređaju." and, after confirmation, the waiting changes are kept on the device and sent the next time this account signs in here.
5. **Given** sign-out, **Then** the person's own AI keys, the theme choice and AI model cooldowns stay on the device.

---

### User Story 7 - Delete account in the app (Priority: P2)

In "Profil" → "Obriši nalog" a confirmation dialog explains what will be deleted
and has a red "Obriši nalog" button and "Odustani". After deletion "Prijava" is
shown with "Nalog je obrisan."

**Why this priority**: required by App Store / Google Play rules and by privacy law (EU), but used rarely.

**Independent Test**: create an account with a recipe and a photo, delete it in the app; the server has no profile, membership, household, recipe or photo for it, the device has none of its data and no own AI keys, and signing in with the same email creates a brand-new empty account.

**Acceptance Scenarios**:

1. **Given** the dialog, **When** "Odustani" is tapped, **Then** nothing changes.
2. **Given** confirmation, **Then** on the server the profile, the membership, the person's household (they are its only member in 006a) with all of its data and photos, the person's personal data (ratings, preferences) and the sign-in identity are deleted; on the device the account's cached data, its waiting changes, its photos and the person's own AI keys are deleted; theme and model cooldowns stay.
3. **Given** no network, **Then** "Nema interneta. Nalog može da se obriše samo uz vezu." is shown and nothing is deleted.
4. **Given** a server error, **Then** "Brisanje nije uspelo. Pokušaj ponovo." is shown, the person stays signed in and nothing on the device is deleted.
5. **Given** a deleted account, **When** the same email signs in again, **Then** a new empty account and household are created and the name step is shown.

---

### User Story 8 - Session stays valid and is protected (Priority: P2)

The session is kept in the platform secure storage (Keychain / Keystore) and
renewed automatically in the background. If it can no longer be renewed (revoked
or account deleted elsewhere), the person is sent back to "Prijava" with
"Sesija je istekla. Prijavi se ponovo." Local data and waiting changes are kept,
so signing in again with the same account continues where they left off.

**Independent Test**: sign in, simulate an expired access token; the next server call renews it without any visible change. Simulate a revoked session; "Prijava" appears with the message.

**Acceptance Scenarios**:

1. **Given** an expired short-lived token and a valid renewal, **Then** the renewal happens silently.
2. **Given** an invalid renewal, **Then** "Prijava" is shown with "Sesija je istekla. Prijavi se ponovo."; the account's cache and waiting changes stay on the device.
3. **Given** sign-in again with the same email after an expired session, **Then** the cached data is shown and the waiting changes are sent.
4. **Given** no network, **Then** the app stays usable with the stored session; renewal and sending are retried when the network returns.

### Edge Cases

- Email typed with spaces or capital letters → trimmed and compared case-insensitively ("Ana@Mail.com" and "ana@mail.com" are the same account).
- Code pasted from the clipboard with spaces or as "123 456" → only digits are taken.
- A code requested twice → only the newest code is valid; the older one gives "Kod nije ispravan…".
- App closed on the code step → on reopening, the email step is shown again (no stored half-state).
- Account deleted on another device while this one is signed in → next renewal fails, "Sesija je istekla…" is shown; the deleted account's cache on this device is removed when the server reports the account no longer exists; signing in creates a new account.
- Very large local data (hundreds of recipes with photos) during the first move or the first download → progress "Čuvam tvoje podatke…" / "Preuzimam tvoje podatke…" is shown; recipes become usable before all photos are transferred.
- The same item edited on two devices of the same account before either has sent its change → the change that reaches the server last wins for that item (no merge in 006a; proper conflict handling is 009). Different items never overwrite each other.
- An item deleted on one device and edited on another → the deletion wins.
- Supabase URL or anon key missing from the build → "Prijava trenutno nije dostupna." on the sign-in screen and no crash (developer build without `secrets.json`).
- The person tries to open a deep link to a tab while signed out → sent to "Prijava"; after sign-in they land on the requested tab.
- Name with only spaces → treated as empty. Initials from names with diacritics ("Đorđe Šćepanović" → "ĐŠ") keep the diacritics.
- Photo upload failure → the recipe is saved without waiting for the photo; the photo upload is retried with the other waiting changes.

## Requirements *(mandatory)*

### Functional Requirements

**Access**

- **FR-001**: The app MUST require a signed-in account with a saved name before any tab or screen other than the intro, the sign-in flow and the name step can be opened.
- **FR-002**: The sign-in screen MUST be shown right after the intro whenever there is no valid stored session.

**Email code sign-in**

- **FR-003**: The only sign-in method in 006a MUST be passwordless email with a 6-digit one-time code; the same flow MUST create a new account or sign into an existing one.
- **FR-004**: The code entry MUST accept exactly 6 digits, ignore spaces, and check the code automatically when the 6th digit is entered.
- **FR-005**: Resending a code MUST be possible only 30 s after the previous send, with a visible countdown.
- **FR-006**: Sign-in failures (wrong code, expired code, too many requests, no network, service unavailable) MUST each show the Serbian message listed in this spec and never crash.

**Session**

- **FR-007**: The session MUST be stored only in the platform secure storage (Keychain / Keystore), never in the local database, logs or plain files.
- **FR-008**: The session MUST be renewed automatically; when renewal is impossible the person MUST be returned to sign-in with "Sesija je istekla. Prijavi se ponovo." without deleting cached data or waiting changes.
- **FR-009**: A signed-in person MUST be able to use the app offline, including after a restart, for all actions that do not need the network (everything except sign-in, account deletion and AI).

**Account, household, profile**

- **FR-010**: On the first sign-in of a new account the system MUST create, exactly once, a profile, a personal household named "Moje domaćinstvo" and a membership with the role owner ("Vlasnik").
- **FR-011**: The profile MUST hold a display name (1–40 characters after trimming), asked once right after the first sign-in ("Kako da te zovemo?") as a mandatory step that cannot be skipped, and editable in "Profil"; the avatar MUST show the initials (first letter of the first and the last word, uppercase, max 2 letters) on a colour derived from the theme.

**Server storage of all user data**

- **FR-012**: All user data MUST be stored on the server under the account: household data (recipes, recipe versions, recipe photos, shopping lists and items, pantry items, meal plans and entries) under the person's household, and personal data (profile, ratings, taste preferences) under the person. The local database MUST remain the offline cache that the UI reads from.
- **FR-013**: Every local change (create, edit, delete) MUST be written to the local database and to a durable queue of waiting changes in the same step, and the queue MUST be sent to the server in order when online, each change exactly once (retries MUST NOT create duplicates; records get identifiers created on the device).
- **FR-014**: A change the server rejects permanently MUST NOT block later changes; it MUST stay on the device and be reported in "Profil" ("Neke izmene nisu sačuvane u nalogu.").
- **FR-015**: On sign-in the account's data MUST be downloaded to the device; on app start online (and on return to the foreground after ≥ 15 min) changes since the last download MUST be fetched. Downloads MUST be resumable and MUST NOT duplicate records.
- **FR-016**: Deletions MUST be recorded so they reach the server and the account's other devices; data on the server MUST be deleted only when the person deletes it or deletes the account.
- **FR-017**: Until 009, when the same record is changed on two devices, the change that reaches the server last MUST win for that record; a deletion MUST win over an edit.
- **FR-018**: "Profil" MUST show the save state: "Sve je sačuvano u nalogu.", "Čuvam izmene…" while sending, "Čeka slanje: {n}" when offline with waiting changes, and "Neke izmene nisu sačuvane u nalogu." for rejected changes.

**Moving data that predates the account**

- **FR-019**: On the first sign-in on a device, all existing local user data that belongs to no account (recipes with versions and photos, shopping lists and items, pantry items, meal plans and entries, ratings, taste profile) MUST be assigned to the person's household / person exactly once and queued for upload, resumable after interruption, without duplicates on later sign-ins and without overwriting data already in the account.

**Server security**

- **FR-020**: The server MUST be in the EU region. Every server table MUST have row-level access rules: a person can read and change only their own profile and personal data, and only the data of households they are a member of. No table MAY be readable or writable without such a rule; access for the app MUST be granted explicitly per table (no automatic exposure of new tables). Photo storage MUST be private with the same household rule.
- **FR-021**: The server connection details (project URL and public anon key) MUST come from the gitignored build-time secrets file (same pattern as the built-in AI keys) and MUST never be committed, logged or shown; no server admin key may ever be in the app or the repository.

**Local cache per account**

- **FR-022**: The device cache MUST be kept per account: a signed-in person MUST see only their own account's data, even if other accounts signed in on the device before.

**Sign out and delete**

- **FR-023**: "Odjavi se" (with confirmation) MUST remove the stored session and show "Prijava"; it MUST NOT delete data on the server or the account's cache and waiting changes on the device. If changes are waiting, the dialog MUST say so; they are sent the next time this account signs in on this device.
- **FR-024**: "Obriši nalog" MUST show a confirmation dialog (no typed confirmation) with a red "Obriši nalog" button; on confirmation it MUST, online only, delete on the server the profile, personal data, the membership, the person's household with all of its data and photos (they are its only member in 006a), and the sign-in identity; then delete the account's cache, waiting changes and photos on the device and the person's own AI keys. It MUST NOT delete anything on the device if the server deletion fails.
- **FR-025**: The person's own AI keys MUST stay on the device on sign-out and MUST be deleted on account deletion. The theme choice and AI model cooldowns MUST stay on the device in both cases.

**Profile screen**

- **FR-026**: "Profil" MUST show, above the existing entries, the avatar, name, email, household name with the role "Vlasnik", the save state (FR-018), and the actions "Izmeni ime", "Odjavi se" and "Obriši nalog".
- **FR-027**: All new screens MUST work at phone width and on wide windows (rail layout), and all new UI text MUST be the Serbian (Latin) copy listed below.

### Out of scope (006a)

- Sign in with Apple and Google (006b, after the Apple Developer account).
- Invites, joining another household, roles other than owner, leaving or transferring a household, member management UI (008).
- Realtime sharing between household members (live updates without restart) and conflict handling for simultaneous edits by several people or devices beyond FR-017 (009).
- Data export, the AI key proxy, push notifications.
- New screens for shopping list, pantry, meal plan, preferences and ratings (their own features); 006a only makes sure their existing tables are stored on the server.

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
| Download progress | "Preuzimam tvoje podatke…" |
| Save state: all saved | "Sve je sačuvano u nalogu." |
| Save state: sending | "Čuvam izmene…" |
| Save state: waiting | "Čeka slanje: {n}" |
| Save state: rejected | "Neke izmene nisu sačuvane u nalogu." |
| Edit name | "Izmeni ime" / button "Sačuvaj" |
| Sign out | "Odjavi se" |
| Sign-out dialog | "Odjaviti se? Tvoji podaci ostaju sačuvani u nalogu." / "Odustani" / "Odjavi se" |
| Sign-out with waiting changes | "Neke izmene još nisu poslate. Poslaćemo ih kada se ponovo prijaviš na ovom uređaju." |
| Session expired | "Sesija je istekla. Prijavi se ponovo." |
| Delete account (entry and red dialog button) | "Obriši nalog" |
| Delete dialog title | "Obrisati nalog?" |
| Delete dialog text | "Trajno se brišu tvoj profil, domaćinstvo i svi podaci u njemu (recepti, liste, ostava, planovi, ocene, fotografije), na serveru i na ovom uređaju, kao i tvoji AI ključevi na ovom uređaju. Ovo ne može da se poništi." |
| Delete dialog cancel | "Odustani" |
| Delete offline | "Nema interneta. Nalog može da se obriše samo uz vezu." |
| Delete failed | "Brisanje nije uspelo. Pokušaj ponovo." |
| Deleted | "Nalog je obrisan." |

### Key Entities

- **Account (sign-in identity)**: one per email address; created on the first confirmed code; owned by the sign-in service.
- **Profile**: one per account; display name, email (read-only), created date. Initials are derived, not stored.
- **Household**: name (default "Moje domaćinstvo"), created by, created date. In 006a every account has exactly one.
- **Household membership**: account + household + role (only "owner" in 006a) + joined date; one per account in 006a, the model allows more later.
- **Household data** (server and device cache): recipes and versions, recipe photos (private file storage), shopping lists and items, pantry items, meal plans and entries; each record belongs to one household and has an identifier created on the device, a last-changed time and a deleted flag.
- **Personal data** (server and device cache): ratings and taste preferences; each record belongs to one person.
- **Waiting change (outbox entry)**: per account on the device; what changed (record, kind of change), in order, with send attempts and a permanent-rejection state.
- **Download position**: per account on the device; how far the account's data has been downloaded, for resuming and fetching only newer changes.
- **Local data move record**: per device — whether the one-time move of data that predates the account has finished (and how far it got, for resuming), and to which account it went.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new person gets from the end of the intro to the "Recepti" tab in under 2 minutes, including reading the email code and entering a name.
- **SC-002**: After the first sign-in, opening the app (online or offline) never asks for sign-in again for at least 30 days of regular use, unless the person signs out or the account is deleted.
- **SC-003**: A change made online is on the server within 10 seconds in 95% of cases; changes made offline are all on the server within 1 minute after the network returns, with none missing and none duplicated (automated test with an interrupted send).
- **SC-004**: Signing in with an existing account on a new device shows 100% of the account's recipes, versions, list items, pantry items, plans, ratings and preferences, and all photos within 2 minutes for an account with 200 recipes on a normal home connection.
- **SC-005**: For an existing user, 100% of local recipes, versions, photos, list items, pantry items, plans and ratings are present on the device and on the server after the first sign-in, and the counts are unchanged after 3 more sign-out/sign-in cycles on the same device (automated test).
- **SC-006**: A person can never read or change another account's profile, personal data, household, household data or photos (verified by automated access-rule tests against the server rules with two test accounts, covering every table and the photo storage).
- **SC-007**: After sign-out, no recipe, list, profile or photo of the previous account is visible to the next person who signs in on the device; after the previous account signs in again, all its data (including changes made offline before sign-out) is there.
- **SC-008**: After "Obriši nalog", no profile, membership, household, household data, personal data or photo of that account remains on the server or on the device.
- **SC-009**: No server key, session token or email code appears in the repository, logs or test fixtures (checked in review and by searching the repository).

## Assumptions

- "Intro" is the themed intro from spec 005 (≈1,8 s, skippable); if 005 is not merged yet, the sign-in screen follows the app start directly.
- The 6-digit code is valid for a limited time set on the server (assumed 10 minutes) and can be used once; the sign-in email itself is sent by the backend in Serbian (template in `supabase/templates/`).
- Email delivery uses a proper sending setup on the backend; the free default mailer's hourly limit is too low for real use, so a custom sender (needs the app domain) is a prerequisite for release, not for development. Local development uses the local Supabase stack (`supabase start`, ports 5532x) and its mail catcher.
- One household per account in 006a; the data model allows more later (008).
- The account email cannot be changed in 006a.
- The household name cannot be changed in 006a (it is not shown to anyone else until invites exist).
- Photos are uploaded after downscaling (≤ 1600 px JPEG, as today); the device keeps a cached copy.
- Fetching other devices' changes happens on app start and on return to the foreground, not live; live updates are 009.
- AI key, theme and model cooldown storage stays per device (not on the server).

## Dependencies

- Supabase project in the EU region, with email one-time-code sign-in enabled, the 6-digit code email template, and a private photo storage bucket (owner action for the hosted project; the local stack is configured in `supabase/config.toml`).
- Supabase URL and anon key in the local gitignored `secrets.json` (owner action; `secrets.example.json` has empty placeholders).
- **Constitution 2.0.0** (amended on this branch): principle II is now offline-first with a mandatory account and the server as the durable store; Row Level Security on every table; explicit grants.
- Spec 005 (intro) for the intro → sign-in order; not a hard dependency.
