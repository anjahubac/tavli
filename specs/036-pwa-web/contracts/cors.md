# Contract: browser access to server functions

**Producer**: `supabase/functions/_shared/cors.ts` (Dev 4) | **Consumers**: the 7 app-called
functions `ai-gateway`, `cookbook-ask`, `cookbook-process`, `planning-inputs` (Dev 2),
`delete-account`, `household-join` (Dev 3), `voice-transcribe` (Dev 4). `household-invite` is a
browser redirect link, not an app call, so it is unchanged.
**Version**: 1 (2026-11-24).

## Configuration

- `TAVLI_WEB_ORIGINS`: comma-separated exact origins (`scheme://host[:port]`, no path,
  no trailing slash). Unset or empty → no browser origin allowed.
- Wildcards, `null` origin and `http://` origins other than `localhost`/`127.0.0.1`
  are rejected at load time.

## Behaviour

| Request | Response |
| --- | --- |
| `OPTIONS` with allowed `Origin` | `204`; `Access-Control-Allow-Origin: <origin>`, `Access-Control-Allow-Methods: <function's methods>, OPTIONS`, `Access-Control-Allow-Headers: authorization, apikey, content-type, x-client-info`, `Access-Control-Max-Age: 600`, `Vary: Origin` |
| `OPTIONS` with other/no `Origin` | `204` without any `Access-Control-Allow-*` header |
| Any other method, allowed `Origin` | Function's existing response unchanged, plus `Access-Control-Allow-Origin: <origin>` and `Vary: Origin` (also on 4xx/5xx) |
| Any other method, other/no `Origin` | Function's existing response unchanged, no CORS headers |

Authentication, input limits, quotas and error bodies are unchanged. `Access-Control-Allow-Credentials`
is not sent (bearer token in header, no cookies).

## Acceptance tests (Deno, per function via a shared helper test)

1. Allowed origin preflight → 204 with headers.
2. Foreign origin preflight and request → no `Access-Control-Allow-Origin`.
3. Allowed origin without bearer → existing 401 body, with CORS header.
4. No `Origin` (native client) → byte-identical response to today.
5. Unset `TAVLI_WEB_ORIGINS` → no origin allowed.
