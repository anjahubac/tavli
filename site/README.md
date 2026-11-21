# site

Static pages served from Cloudflare Pages. No build step, no keys, no
third-party requests (fonts and the Tavli badge are local files).

- `potvrda/` — "Uspešna registracija": the confirmation email's "Potvrdi adresu"
  button lands here after Supabase confirms the address. It reads `code` (or
  `error`/`error_code`) from the URL, removes it from the address bar and offers
  "Otvori Tavli" → `tavli://auth-callback?code=…`. Layout follows the design
  canvas boards `WebUspesnaRegistracija` and `WebUspesnaRegistracijaSiroko`.
- `_headers` — CSP (`'self'` only), `no-referrer`, `noindex` and `no-store` for
  `/potvrda/`.

Deploy: Cloudflare Pages project with build output directory `site` (no build
command). The page URL, with the trailing slash (`https://<project>.pages.dev/potvrda/`),
goes into Supabase → Authentication → URL Configuration → Redirect URLs and into
`AUTH_CONFIRM_PAGE_URL` in `secrets.json`.
