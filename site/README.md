# site

Static pages served by the Cloudflare Worker `welcome` (static assets only,
configured in `wrangler.jsonc` at the repo root). No build step, no keys, no
third-party requests (fonts and the Tavli badge are local files).

- `potvrda/` — "Uspešna registracija": the confirmation email's "Potvrdi adresu"
  button lands here after Supabase confirms the address. It reads `code` (or
  `error`/`error_code`) from the URL, removes it from the address bar and offers
  "Otvori Tavli" → `tavli://auth-callback?code=…`. Layout follows the design
  canvas boards `WebUspesnaRegistracija` and `WebUspesnaRegistracijaSiroko`.
- `preuzmi/` — "Preuzmi Tavli": download buttons for Android, iOS (unsigned IPA
  for sideloading), macOS (ad-hoc signed DMG), Windows and Linux. Every button points at
  `https://github.com/anjahubac/tavli/releases/latest/download/<file>`; the files
  are built and attached by `.github/workflows/release.yml` when a `v*` tag is
  pushed. The Android QR code (and `qr-stranica.svg`, the page's own address for
  slides and posters) are static SVGs made by
  `dart run scripts/generate_download_qr.dart`; the QR always encodes the same
  URL as its button. Reuses `potvrda/style.css`, fonts and badge.
- `_headers` — CSP (`'self'` only), `no-referrer`, `noindex` and `no-store` for
  `/potvrda/`.

Deploy: Cloudflare Workers Builds deploys `site/` on every push to `dev`
(`npx wrangler deploy`, no build command); there is no manual upload.
`.assetsignore` keeps this README from being served. The page URL, with the
trailing slash (`https://welcome.tavli.workers.dev/potvrda/`), goes into
Supabase → Authentication → URL Configuration → Redirect URLs and into
`AUTH_CONFIRM_PAGE_URL` in `secrets.json`.
