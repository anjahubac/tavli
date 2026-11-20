# Quickstart: validating 006a

## Prerequisites

- Docker running, Supabase CLI ≥ 2.116 (`supabase --version`).
- Local stack from the repo root: `supabase start` (API 55321, DB 55322, Studio
  55323, mail catcher 55324). It applies `supabase/migrations/` and serves
  `supabase/functions/`.
- Your own gitignored `secrets.json` with `SUPABASE_URL=http://127.0.0.1:55321`
  and the local anon / publishable key printed by `supabase status`
  (never commit it, never paste it into docs or chat).

## 1. Server rules

```bash
supabase db reset          # re-applies all migrations on a clean DB
supabase test db           # pgTAP: catalog, provisioning, isolation, storage, deletions, delete_account
```

Expected: all tests pass; `01_catalog_test` fails if any `public` table lacks
RLS or grants anything to `anon`.

## 2. App checks (no network)

```bash
scripts/check.sh           # format and analyze
flutter test               # full suite, backend faked
python3 -m unittest discover -s scripts -p test_auth_email_templates.py
flutter build macos --debug
```

## 3. Manual end-to-end against the local stack

Run `flutter run -d macos --dart-define-from-file=secrets.json`; codes arrive in
the mail catcher at http://127.0.0.1:55324.

| # | Steps | Expected |
|---|---|---|
| 1 | Fresh app → "Prijava" → new email → "Pošalji kod" → code from the first email in the mail catcher (no link/button) | name step "Kako da te zovemo?"; no tab reachable (US1, US2) |
| 2 | Enter "Ana Petrović" → "Nastavi" → "Profil" | avatar "AP", email, "Moje domaćinstvo", "Vlasnik", "Sve je sačuvano u nalogu." |
| 3 | Studio: `profiles`, `households`, `household_members` | exactly one row each for the user |
| 4 | Wrong code; wait 10 min and use old code; resend before 30 s | the three Serbian messages; countdown "Pošalji ponovo za {s} s" |
| 5 | Add a recipe with a photo, edit it twice | rows in `recipes`, `recipe_versions` within 10 s; object `{household}/{file}.jpg` in `recipe-photos` |
| 6 | `supabase stop` (offline), edit a recipe, open "Profil" | "Čeka slanje: 1"; app works normally |
| 7 | `supabase start`, wait ≤ 1 min | "Sve je sačuvano u nalogu."; no duplicate rows |
| 8 | Second device/profile (another macOS user or simulator) signs in with the same email | same recipes and photo appear ("Preuzimam tvoje podatke…") (US4) |
| 9 | Delete the recipe on device A; edit it on device B offline, then go online | recipe stays deleted on both (deletion wins) |
| 10 | "Odjavi se" with a waiting change → confirm → sign in as other email | dialog mentions waiting changes; other account sees nothing of the first (US6) |
| 11 | Sign back in as the first email | data shown immediately; the waiting change is sent |
| 12 | "Obriši nalog" → red "Obriši nalog" | "Nalog je obrisan."; Studio: no profile/household/data rows; bucket folder empty; `auth.users` row gone; own AI keys gone; signing in again creates a new empty account (US7) |
| 13 | Upgrade path: run a v3 build with 3 recipes, then this build and sign in | "Tvoji recepti i liste su sačuvani u nalogu."; 3 recipes on the server; sign out/in 3× → still 3 (US5, SC-005) |
| 14 | Build without `secrets.json` | "Prijava trenutno nije dostupna." and no crash |
| 15 | Phone width (400 px) and wide window (1200 px) | sign-in, name step and Profil header lay out correctly |

## 4. Secret hygiene

```bash
git grep -nE "eyJ[A-Za-z0-9_-]{20,}|sb_(secret|publishable)_[A-Za-z0-9]{8,}"
```

Expected: no matches (SC-009).

## 5. First-email OTP correction (2026-11-20)

After changing local auth configuration/templates, restart the local stack for
those files to take effect. Use synthetic addresses only. Test new, still
unconfirmed and existing accounts: the first delivered email must contain a
6-digit code, no auth link/button and no instruction to request a second email.
Read the email on another device and type the code in Tavli. A new account
reaches the name step; an existing one keeps its household and saved name.
Request again after 30 seconds without verifying the first code to cover an
unconfirmed account. Verify wrong, expired and already-used codes cannot create
a session. Do not record real codes, email addresses or session values as evidence.

The reviewed `deploy-supabase.yml` workflow publishes both subjects and HTML
bodies via the Supabase Management API on matching pushes to `dev` and `main`
and on manual deployment from those branches. The existing
`SUPABASE_ACCESS_TOKEN` must authorize reading and updating Auth configuration
for the environment's `SUPABASE_PROJECT_REF`. The workflow checks hosted email
confirmation, OTP length, expiry and resend interval before publishing. If a
setting differs, resolve the reported configuration mismatch through a reviewed
deployment change and rerun the workflow. A successful run verifies the stored
templates and settings. Email delivery and code redemption are exercised with
synthetic accounts on the local stack.
