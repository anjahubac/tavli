# Quickstart: validate the web/PWA target

Synthetic accounts and the local stack only. Never run the web build or tests against
production, even though the released web app talks to it.

## Prerequisites

- Flutter 3.50.0, Chrome, Docker for `supabase start`.
- Own `secrets.json` for the local stack (see `secrets.example.json`).
- An iPhone and a Mac on the same network for install checks.

## Local run

```bash
supabase start
flutter run -d chrome --dart-define-from-file=secrets.json
```

Expected: intro, sign-in with the email code from Mailpit (:55324), Home with data.

## Production-like build

```bash
flutter build web --wasm --release --dart-define-from-file=secrets.json
```

Serve `build/web` over HTTPS on the LAN (service workers, camera and microphone need a
secure context), then:

1. iPhone Safari → Share → “Dodaj na početni ekran” → open the icon: standalone, Tavli icon.
2. Sign in, open every tab, create a recipe from a photo (slice 3), tick shopping items.
3. Airplane mode → reopen from the icon: starts within 5 s with cached data; tick items;
   reconnect → changes appear on a second signed-in device within 1 minute.
4. macOS Safari “Add to Dock” and Chrome “Install”: own window, rail layout; resize to phone
   width; 2× text; reduced motion on.
5. Sign out, sign in with a second synthetic account in the same browser: no data or
   session from the first account.

## Server functions

```bash
cd supabase/functions && deno test --allow-env
```

Expected: CORS contract tests in [contracts/cors.md](contracts/cors.md) pass.

## Native unchanged

```bash
flutter test
```

```bash
flutter build macos --debug
```

Expected: green and identical behaviour; `git diff origin/dev -- ios macos` is empty.
