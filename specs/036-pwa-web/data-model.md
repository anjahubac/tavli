# Data model: 036 web/PWA target

No new server table, column, RLS policy or storage bucket. No change to synced
business-data formats or the outbox. Native platforms use no new client data.

## Web-only client data

| Item | Classification | Where (web) | Lifetime | Rules |
| --- | --- | --- | --- | --- |
| drift cache + outbox | account business data (cache) | origin storage chosen by drift (OPFS / IndexedDB) | same as native per-account cache | unchanged schema and account scoping |
| Session (access/refresh token) | device-only secret | `flutter_secure_storage` web, Tavli origin only | until sign-out, account deletion or browser clearing | never in URL, log, outbox or service-worker cache (D1) |
| Recipe photo cache | device cache of synced storage objects | web photo store (research R4) | until recipe/account deletion or browser clearing | same relative-path validation and account root as native |
| Own AI keys | — | **not stored on web** | — | web key store returns none and rejects writes (D2) |
| App shell files | public static | service-worker cache | until next version | no personal data |

## Web photo cache

IndexedDB database `tavli_recipe_photos`, object store `photos`, key = validated relative
path (`recipe_photos/<name>`), value = JPEG bytes. Same path rule and downscaling as native.
No drift table and no `schemaVersion` change. Entries are removed with the recipe's photo
delete path; sign-out keeps them like the native files.

## State transitions

- Browser clears storage → app starts signed out → sign-in downloads data again; unsent
  outbox entries are lost and the user sees the notice from spec.md.
- Sign-out → session removed; account cache kept (same as native).
