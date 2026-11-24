# Research: 036 web/PWA target

Date 2026-11-24. Source evidence is the baseline tree; browser behaviour must be
re-confirmed on devices during slice validation (quickstart.md).

## R1 Renderer and build mode

- **Decision**: `flutter build web --wasm --release`. Flutter serves the skwasm (WasmGC)
  renderer where the browser supports it and falls back to CanvasKit (JS) otherwise.
- **Rationale**: one build covers current Chrome and Safari versions with WasmGC and older
  Safari through the fallback; no code difference.
- **Alternatives**: CanvasKit only (larger startup, no gain); HTML renderer (removed from Flutter).

## R2 Conditional compilation without touching native paths

- **Decision**: split platform-specific code with
  `import 'x_io.dart' if (dart.library.js_interop) 'x_web.dart';`. The `_io` file holds the
  existing native code moved unchanged; the web file holds the new behaviour.
  `kIsWeb` guards only for small checks (window channels, app links).
- **Rationale**: `dart:io` and `package:win32` (FFI) cannot be compiled for the web at all,
  so a runtime `kIsWeb` check is not enough there. Moving code unchanged keeps native
  behaviour identical (owner instruction: additive only).
- **Alternatives**: `universal_io` package (new dependency, changes native imports).

## R3 drift on the web

- **Decision**: keep `driftDatabase(name: 'tavli')`; add `web:` options pointing to
  `sqlite3.wasm` and `drift_worker.js` served from `web/`. Versions of both files must match
  the locked `sqlite3`/`drift` packages and are taken from their releases at implementation.
- **Rationale**: drift picks the best storage per browser: OPFS where available, IndexedDB
  otherwise. Full shared mode needs COOP/COEP headers; those would also block cross-origin
  images, so they are **not** set. Multiple tabs are then handled by drift's shared/dedicated
  worker selection; the outbox must be tested with two tabs (edge case in spec).
- **Alternatives**: a separate web-only store (rewrites the data layer; rejected).

## R4 Recipe photos on the web

- **Decision**: a web `RecipePhotoStore` that keeps downscaled JPEG bytes in browser
  storage keyed by the same relative path and validated the same way. Home: IndexedDB. Display uses `Image.memory`.
- **Rationale**: the existing interface returns `File?`; the web variant needs a bytes-based
  accessor. `read()` already exists, so web uses it with `Image.memory`; `file()` moves from the
  interface to the native class and native keeps `Image.file` as today.
- **Decided in slice 3**: raw IndexedDB through `package:web`, so no drift schema bump
  (a bump would collide with other in-flight migrations and touch every native database).

## R5 Network-error detection

- **Decision**: `isOfflineError(Object e)`: io variant matches `SocketException` exactly as
  today; web variant matches `http.ClientException` and dio `connectionError`.
- **Rationale**: preserves every existing native mapping to Serbian texts.

## R6 Session storage on the web (D1)

- **Decision**: `flutter_secure_storage` web implementation for the session only.
- **Finding to record honestly**: it encrypts values with WebCrypto, but the key lives in
  the same origin's storage. Protection therefore rests on origin isolation and the CSP,
  not on encryption at rest. The constitution IV exception must say this explicitly.
- **Alternatives**: in-memory session (rejected by owner, D1).

## R7 Hosting

- **Decision**: serve `build/web` as static assets on Cloudflare, with a separate Wrangler
  config next to the existing `wrangler.jsonc` (`welcome` site stays unchanged). Headers come
  from `web/_headers`, which Flutter copies into `build/web`.
- **Rationale**: the team already deploys static sites this way; no new service.
- **Decision (D3 revised)**: one web deployment, built against production. The Worker is
  `tavli-web` (`web.wrangler.jsonc`), deployed by `deploy-web.yml` after `production` approval.
- **Note**: account-side setup is not documented in the repository (owner rule).

## R8 Server functions and browsers

- **Decision**: shared `supabase/functions/_shared/cors.ts`; exact-match allowlist from the
  `TAVLI_WEB_ORIGINS` environment value (comma-separated); empty/unset means no browser
  origin is allowed. Preflight answers `204` with allowed methods and headers
  `authorization, apikey, content-type, x-client-info`.
- **Rationale**: native clients send no `Origin` and are unaffected; foreign sites cannot
  read responses. Wildcards are forbidden (spec security section).
- Functions not called by the app (`household-photo-cleanup`, `recipe-vector-index`) are
  left unchanged.

## R9 Service worker and updates

- **Decision**: use Flutter's generated service worker for the static app shell only; serve
  `index.html`, `flutter_service_worker.js` and `manifest.json` with `Cache-Control: no-cache`
  so a new version is picked up on the next start (FR-004).
- **Risk**: Flutter has been deprecating its default service worker; if the pinned version
  no longer generates one, add a minimal static-only worker in `web/`. Decide in slice 1.

## R10 Unsupported features in browsers

| Feature | Web expectation | Fallback |
| --- | --- | --- |
| `image_picker` camera | iPhone Safari opens camera via file input | choose image |
| `mobile_scanner` QR | needs camera permission, HTTPS | type invitation code |
| `record` voice | MediaRecorder; Safari format differs | hide voice with notice if transcription rejects the format |
| `share_plus` | Web Share API on Safari; Chrome desktop limited | copy to clipboard |
| `wakelock_plus` | Screen Wake Lock API (Safari 16.4+) | silently unavailable |
| `app_links` | not used on web | manual code entry |
