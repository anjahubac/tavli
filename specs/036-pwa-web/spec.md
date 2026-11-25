# Feature Specification: Installable web app (PWA) for iOS and macOS

**Spec ID**: 036-pwa-web | **Status**: Draft (decisions D1–D3 recorded; constitution amendment pending)
**Date**: 2026-11-24 | **Baseline**: `origin/main` at `5b37b9a` (tree identical to `origin/dev` at `5634500`)
**Owner**: Anja (Dev 4, platform integration) | **Reviewer**: Matija (Dev 3), proposed
**Branch**: `036-pwa-web`, created from `origin/main` at the owner's request; PR targets `dev`
(the `branch-name` check accepts only `dev` or `hotfix/…` into `main`)
**Source**: owner decision 2026-11-24 — the team has no Apple Developer Program, so
signed iOS and macOS bundles cannot be distributed.

Write English engineering prose; quote exact new Serbian Latin UI copy.
Read the current constitution, architecture, product plan and relevant contracts.

## Problem and scope

Tavli builds native iOS and macOS bundles (`ios/`, `macos/`), but without an Apple
Developer Program membership nobody outside a developer's own machine can install
them: iOS needs a provisioning profile, and macOS needs a Developer ID signature and
notarization to open without Gatekeeper warnings. People on iPhone, iPad and Mac
need another way to use Tavli.

**Outcome**: the same Tavli app, built from the existing shared code, is served from
a web address and can be installed to the iPhone/iPad home screen and to the Mac dock.
It behaves like the native app for the supported journeys: sign-in, offline cache
with later sync, recipes with photos, AI recipe creation through shared access,
planning, shopping, pantry and household.

**Existing evidence** (source review on the baseline):

- No web target exists; there is no `web/` folder.
- Eleven files under `lib/` import a desktop/mobile-only system library, mostly for
  network-failure detection; the recipe photo store and the voice recorder keep data
  as files on disk.
- None of the server functions under `supabase/functions/` answers browser
  cross-origin preflight requests, so a browser would refuse to call them.
- The sign-in callback is the custom scheme `tavli://auth-callback`
  (`lib/account/auth_gateway.dart`, `supabase/config.toml`), which a browser cannot open.
- The session and own AI keys use the OS secure store (constitution IV), which
  browsers do not have.

**In scope**: a web target with install metadata (name, icons, theme colour, start
page, standalone display), offline start after the first load, web-safe photo and
voice handling, cross-origin access to the server functions, a web sign-in callback,
web session storage under a recorded constitution exception, hosting on the team's
existing static hosting, and validation in Safari on iPhone and Safari/Chrome on macOS.

**Additive only** (owner, 2026-11-24): the web target is added next to the existing setup.
The native `ios/` and `macos/` folders, their settings and native behaviour are not changed.

**Out of scope**: changes to the native `ios/` and `macos/` folders (they stay buildable
for developers), Android or Windows as web targets (native builds remain the supported
path there), App Store/TestFlight distribution, web push notifications, a separate
web-specific UI layout, and public promotion of the address (spec 032 handles the website).

## User Scenarios & Testing

### User Story 1 — Install and sign in on iPhone (Priority: P1)

As an iPhone user without an App Store build, I open the Tavli address in Safari,
add it to the home screen, open it from the icon and sign in with the email code,
so I can use my household's recipes, plans and shopping list.
**Independent test**: on a physical iPhone, the installed icon opens Tavli full screen,
without the browser address bar, and a synthetic account can sign in and see its data.

1. **Given** a first visit in Safari, **When** the user chooses “Dodaj na početni ekran”
   and opens the new icon, **Then** Tavli opens standalone with the Tavli name and icon
   and shows the intro and sign-in.
2. **Given** the sign-in screen, **When** the user enters the email code from the mail,
   **Then** the account opens and synced data downloads, as on the native app.
3. **Given** the user taps the confirmation link in the email instead, **When** the link
   opens, **Then** it returns to the Tavli web address and completes sign-in, or the
   user can still enter the code manually.
4. **Given** a wrong or expired code, **When** it is submitted, **Then** the same Serbian
   error text as on native platforms is shown.

### User Story 2 — Offline use and sync (Priority: P1)

As a signed-in user in a shop with poor signal, I open the installed Tavli, tick items
on the shopping list and see today's meals; my changes upload when I am back online.
**Independent test**: with the device in airplane mode, the installed app starts,
shows cached data and records changes that later appear on a second device.

1. **Given** the app was opened online at least once, **When** it is started offline,
   **Then** it starts and shows the signed-in account's cached data.
2. **Given** offline changes, **When** connectivity returns, **Then** they upload through
   the existing outbox and appear on another signed-in device of the same household.
3. **Given** a new app version is deployed, **When** the user next opens the app online,
   **Then** the new version is used no later than the following start, without losing
   unsent changes.

### User Story 3 — Recipes with photos and AI (Priority: P1)

As a user on Mac or iPhone, I photograph a dish or type its name, let AI create the
recipe, and keep the recipe photo.
**Independent test**: create a recipe from a camera photo on iPhone and from a chosen
image file on Mac; both show the photo after a restart and on another device.

1. **Given** the recipe creation screen, **When** the user takes or chooses a photo,
   **Then** AI creates the recipe through shared access and the photo is stored with it.
2. **Given** the app is restarted (online or offline), **When** the recipe opens,
   **Then** its photo is shown.
3. **Given** shared access is exhausted or fails, **When** AI is used, **Then** the
   existing Serbian AI error text is shown and the app stays usable.

### User Story 4 — Install on Mac (Priority: P2)

As a Mac user, I open the Tavli address in Safari or Chrome and install it, so it opens
from the Dock in its own window.
**Independent test**: Safari “Dodaj u Dock” (“Add to Dock”) and Chrome “Instaliraj”
produce a standalone window that uses the wide (rail) layout and keyboard navigation.

1. **Given** macOS Safari 17+ or current Chrome, **When** the user installs Tavli,
   **Then** it opens in its own window with the Tavli icon.
2. **Given** a wide window, **When** it is resized to phone width, **Then** the layout
   switches between rail and bottom tabs as in the native app.

### User Story 5 — Voice, scanning and sharing (Priority: P3)

As a user, I can dictate a recipe, scan a household invitation QR code and share
a shopping list from the web app where the browser allows it.
**Independent test**: each feature either works in iPhone Safari and macOS Safari/Chrome
or is hidden/replaced with a Serbian explanation; none crashes the app.

1. **Given** microphone permission, **When** the user dictates a recipe, **Then** the
   recording is transcribed through the existing server function.
2. **Given** camera permission is denied, **When** scanning or a photo is attempted,
   **Then** a Serbian message explains it and offers the manual alternative
   (typing the invitation code, choosing an image file).

### Edge Cases

- Sign-out and account switching in the same browser: one account's cached data and
  session must never be visible to the next account (constitution II).
- Safari clears storage of a site that was not installed and not used for about 7 days;
  the app must recover by signing in again and re-downloading, with no lost synced data
  beyond unsent offline changes, and must tell the user when unsent changes were lost.
- Private browsing or storage disabled: the app explains that it needs storage and does
  not appear signed in with nothing saved.
- Two open tabs of the same app: sync must not upload the same outbox entry twice or
  corrupt the cache.
- Storage quota exceeded by photos: show a Serbian message; synced data stays on the server.
- Own AI keys are not available on the web (D2); a user who relies on them sees the
  explanation in AI settings and uses shared access.
- Deep links `tavli://…` (e.g. household invitation links) do not open the web app;
  invitation codes typed manually must keep working.

## Requirements

### Functional Requirements

- **FR-001**: The shared app code MUST build for the web from the same source as the
  native targets, without behaviour changes on Android, iOS, macOS, Windows and Linux.
- **FR-002**: The web app MUST be installable: name “Tavli”, the approved Tavli icons
  (including iOS home-screen and maskable icons), theme/background colours from the
  Tavli palette, standalone display and start page `/` (hash routes, so the app opens on its default tab).
- **FR-003**: After one online visit, the installed app MUST start offline and show the
  signed-in account's cached data; changes MUST be kept and uploaded later through the
  existing outbox.
- **FR-004**: New releases MUST reach users no later than the second start after deployment,
  and an update MUST NOT discard unsent outbox entries or the local cache.
- **FR-005**: Email-code sign-in MUST work on the web; the email confirmation link MUST
  return to the web address of the same environment when the user opened the web app.
  Native apps keep `tavli://auth-callback`.
- **FR-006**: Every server function called by the app MUST accept browser requests from
  the approved web origins of its environment and MUST keep rejecting requests without a
  valid session exactly as today. Other origins MUST NOT be allowed.
- **FR-007**: Recipe photos MUST be stored, displayed, synced and deleted on the web with
  the same rules as the native photo store (account-scoped, root containment, size limits).
- **FR-008**: Voice drafting, QR scanning, sharing and keep-screen-on MUST each either work
  in the supported browsers or be hidden with a Serbian explanation; no feature may crash
  or hang the app.
- **FR-009**: Network failures on the web MUST map to the same Serbian offline/error texts
  as on native platforms.
- **FR-010**: The web session MUST be stored only in encrypted storage of the Tavli origin
  (D1), never in URLs, logs or service-worker caches, and MUST be removed on sign-out and
  account deletion. This is recorded as a constitution IV exception before release.
- **FR-011**: On the web, AI MUST use shared access only (D2); own-key entry is not shown,
  and an own key stored by a native app is never read or sent by the web app.
- **FR-012**: The web app MUST be served over HTTPS from Cloudflare Pages for the
  production environment (D3, revised 2026-11-24); the web app uses the production
  backend and never the dev one.
- **FR-013**: The web build MUST be built in CI on PRs to `dev` and `main`, without real
  credentials, like the Linux and Windows builds.

### Data and privacy

No new business entity or server table. Business data remains account-scoped drift
cache plus outbox, and Supabase is the source of truth. On the web the drift cache lives
in browser storage of the Tavli origin, per account, as on native platforms. Photos are
device cache of synced storage objects. The session is a device-only
secret (constitution II/IV) and MUST NOT enter the outbox, logs, or URLs. Sign-out keeps
the account's cache as on native platforms; browser storage cleared by the OS is
treated like a reinstall.

### UI copy and usability

| Context | Exact Serbian Latin copy | Interaction / accessible alternative |
| --- | --- | --- |
| Browser storage unavailable (private mode) | “Tavli ne može da sačuva podatke u ovom pregledaču. Isključi privatni režim ili dozvoli čuvanje podataka.” | Retry button “Pokušaj ponovo” |
| Feature not supported in browser | “Ova mogućnost ne radi u pregledaču.” | Feature entry hidden or disabled with this text as its semantic label |
| Camera/microphone permission denied | “Pregledač nije dozvolio pristup. Dozvoli ga u podešavanjima pregledača.” | Manual alternative stays available |
| Own keys section on the web | “Sopstveni ključevi rade samo u aplikaciji. U pregledaču Tavli koristi zajednički pristup.” | Replaces the key list in AI settings |
| Unsent changes lost after browser cleared storage | “Pregledač je obrisao podatke koji još nisu bili poslati.” | Single notice after sign-in |

All other copy is reused from the native app. Phone width (iPhone Safari), wide window
(Mac), 2× text, keyboard focus and reduced motion are validated on the web build.
Exact copy is reviewed by the owner before the UI task becomes Ready.

## Success Criteria

- **SC-001**: On a physical iPhone (current iOS, Safari) a synthetic account installs the
  app to the home screen, signs in and completes the critical journeys of spec 013
  (recipe from photo, plan a day, tick shopping items, pantry edit) with no blocking defect.
- **SC-002**: The installed app starts in airplane mode within 5 seconds on that iPhone
  and shows cached data; offline changes appear on a second device within 1 minute of
  reconnecting.
- **SC-003**: macOS Safari and Chrome install the app into its own window; the same journeys
  pass at wide and phone widths.
- **SC-004**: Every server function rejects a browser request from an unapproved origin and
  a request without a session, and accepts the approved origin with a session (negative and
  positive tests).
- **SC-005**: Native builds and the full test suite stay green; the web build job passes in CI.
- **SC-006**: Two synthetic accounts in the same browser never see each other's data or session.

## Dependencies and open decisions

- Constitution amendment: add the web target to “Platform & Technology Constraints”
  and the Q1 exception to principle IV. Owner Anja; independent reviewer required.
- Spec 012 (security baseline) review of web session storage, origins and CSP.
- Spec 013 critical journeys are the acceptance set; spec 033 governs production release.
- Spec 015 gateway and the other server functions gain browser access (FR-006);
  coordinate with Dev 2 (gateway owner) and Dev 3 (household functions).
- Spec 032 may later link the web address on the website; not part of this spec.

Decisions recorded 2026-11-24 by Anja (owner); the constitution amendment still
needs independent review before release:

- **Q1 → D1** (session): the web session is kept in encrypted browser storage of
  the Tavli origin, under a constitution IV exception and a strict Content Security
  Policy. The user stays signed in between starts. The exception covers the session
  only, not own AI keys.
- **Q2 → D2** (own keys): the web app uses shared access only. Key entry is hidden on
  the web and no own AI key is stored or sent from a browser. Own-key provider CORS
  is therefore out of scope.
- **Q3 → D3** (hosting, revised 2026-11-24): the web app is served as a static Cloudflare
  Worker (`web.wrangler.jsonc`) and is built against the **production** backend
  (`secrets.prod.json` values), because there are no real users yet and a separate dev web
  build is not needed. Email links from the web app return to the production web address.
  Release follows the existing production gate: a PR `dev` → `main` and approval in the
  `production` environment. Because production is now the only web target, every change
  here MUST stay additive and compatible with the already released native apps.

## Acceptance evidence

Not started. Each FR maps to tests or manual device evidence in `tasks.md`; physical
iPhone and Mac runs are recorded in the PR description (not on the branch). Reviewer
sign-off and a merged PR into `dev` are required. Nothing is accepted by code presence.

## Security and abuse cases

- **Assets**: session tokens, cached personal data, recipe photos (no own AI keys on the web, D2).
- **Trust boundaries**: the browser origin, the static host, server functions.
- **Cross-origin access**: server functions allow only approved origins per environment;
  wildcard origins are forbidden. Session checks and limits are unchanged (FR-006, SC-004).
- **Script injection**: the web origin holds the session, so a strict Content Security
  Policy is required (scripts only from the Tavli origin; connections only to the
  environment's Supabase project). No third-party scripts or analytics.
- **Storage**: no tokens or keys in URLs, query strings, logs or service-worker caches;
  the service worker caches only the app's static files, never API responses with personal data.
- **Files**: photo names and paths keep the existing validation and account-root containment.
- **Abuse**: no new endpoint; the existing gateway quotas apply to web users equally.
- **Hosting**: deployment only through a reviewed workflow with `production` environment
  approval; no hand deployment. Because the web build talks to production, tests and
  local runs never use the production build or credentials (AGENTS guardrail); they use
  the local stack and fake backends.
- Negative tests: unapproved origin, missing session, other account's photo path, two
  accounts in one browser. Link the 012 controls in `plan.md`.
