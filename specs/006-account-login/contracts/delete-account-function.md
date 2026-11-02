# Contract: Edge Function `delete-account`

Source: `supabase/functions/delete-account/index.ts` (Deno). Deployed by the
owner with `supabase functions deploy delete-account`; served automatically by
the local stack.

## Request

`POST /functions/v1/delete-account` with `Authorization: Bearer <user access
token>` (sent by `functions.invoke`). No body. `verify_jwt = true`.

## Behaviour

1. Resolve the caller with `auth.getUser(token)`; no user → `401`.
2. With a service-role client (key from the function environment, provided by the
   platform; never in the app or repo):
   1. households where the caller is the only member → list objects under
      `{household_id}/` in `recipe-photos` (paged) and remove them;
   2. `rpc('delete_account_data', { uid })` (schema `public`, executable by `service_role` only);
   3. `auth.admin.deleteUser(uid)`.
3. Every step is idempotent; if a step fails the function returns `500` and a
   retry finishes the job.

## Responses

| Status | Body | App reaction |
|---|---|---|
| 200 | `{"deleted": true}` | wipe device data of the account + own AI keys, clear session, `SignedOut(accountDeleted)` → "Nalog je obrisan." |
| 401 | `{"error": "unauthorized"}` | refresh session once and retry; else "Sesija je istekla. Prijavi se ponovo." |
| 5xx / network | — | "Brisanje nije uspelo. Pokušaj ponovo." / offline: "Nema interneta. Nalog može da se obriše samo uz vezu." — nothing deleted on the device |

The function never logs tokens, emails or object names.
