# Contract: app-side interfaces (Dart)

Boundaries the Flutter code depends on. Real implementations wrap the `supabase`
client; tests use the in-memory fakes in `test/helpers/fake_backend.dart`.

## Configuration — `lib/account/supabase_config.dart`

```dart
class SupabaseConfig {
  factory SupabaseConfig.fromEnvironment(); // SUPABASE_URL, SUPABASE_ANON_KEY
  bool get isConfigured;                    // both non-empty
  @override String toString();              // never contains the key
}
```

## Auth — `lib/account/auth_gateway.dart`

```dart
abstract interface class AuthGateway {
  Future<void> sendCode(String email);                       // throws AuthFailure
  Future<AuthSession> verifyCode(String email, String code); // throws AuthFailure
  Future<AuthSession> restore(String sessionJson);           // refresh; throws AuthFailure
  Stream<AuthSession?> get sessionChanges;                   // refreshed / null
  Future<void> signOutLocal();
  String? get accessToken;
}

class AuthSession { String userId; String email; String json; }

sealed class AuthFailure implements Exception {}
// WrongCode, CodeExpired, RateLimited, Offline, Unavailable,
// SessionRevoked, AccountGone
```

`authErrorText(AuthFailure)` (`lib/features/account/auth_error_text.dart`) maps
each to the spec copy: WrongCode → "Kod nije ispravan. Proveri poruku i pokušaj
ponovo.", CodeExpired → "Kod je istekao. Pošalji novi kod.", RateLimited →
"Previše pokušaja. Sačekaj malo pa pokušaj ponovo.", Offline → "Nema interneta.
Za prijavu je potrebna veza.", Unavailable → "Prijava trenutno nije dostupna.",
SessionRevoked/AccountGone → "Sesija je istekla. Prijavi se ponovo.".

## Session storage — `lib/account/session_store.dart`

```dart
class SessionStore {           // over existing SecretStorage (Keychain/Keystore)
  Future<String?> read();      // key 'auth_session'
  Future<void> write(String json);
  Future<void> clear();
}
```

## Account — `lib/account/account_service.dart`

```dart
class AccountService {
  Future<Account> loadOrFetch(AuthSession s); // Accounts row or profiles + membership
  Future<void> saveName(String name);         // trims, 1–40, Accounts + outbox 'profile'
  Future<void> deleteAccount();               // AccountApi then local wipe; throws DeleteFailure
}

abstract interface class AccountApi {
  Future<RemoteAccount> fetch();              // profile + household + role
  Future<void> deleteAccount();               // functions.invoke('delete-account')
}
```

`Account` (`lib/domain/account.dart`): `userId, email, displayName?,
householdId, householdName, role`; `initials(String name)` pure function
(first letter of first and last word, uppercase, keeps diacritics, max 2).

## Auth state — `lib/account/auth_controller.dart`

`AuthController extends Notifier<AuthState>`; `AuthState` sealed:
`Starting`, `SignedOut(reason: SignOutReason?)`, `CodeSent(email, sentAt)`,
`NeedsName(Account)`, `SignedIn(Account)`. Methods: `start()`,
`sendCode(email)`, `verify(code)`, `changeEmail()`, `saveName(name)`,
`signOut()`, `deleteAccount()`. `accountScopeProvider` derives
`AccountScope(userId, householdId)` from `SignedIn`.

## Router

`createRouter(...)` gets `redirect` + `refreshListenable` on auth state:
`SignedOut|CodeSent → /sign-in?from=<loc>`; `NeedsName → /sign-in/name`;
`SignedIn` on `/sign-in*` → `from` or `/recipes`. `Starting` keeps the current
splash (no flicker).

## Sync — `lib/sync/`

```dart
abstract interface class SyncRemote {
  Future<void> upsert(String table, List<Map<String, Object?>> rows); // onConflict id
  Future<void> delete(String table, List<String> ids);
  Future<void> updateProfileName(String userId, String name);
  Future<List<Map<String, Object?>>> fetchSince(
      String table, DateTime? since, String? afterId, int limit); // ordered (updated_at, id)
}
abstract interface class PhotoRemote {
  Future<void> upload(String objectKey, Uint8List jpeg);  // upsert
  Future<Uint8List> download(String objectKey);
  Future<void> remove(List<String> objectKeys);
}

sealed class SyncError implements Exception {}
// Transient (offline, timeout, 5xx, 429), Unauthorized (401), Permanent(code)

class SyncedWriter {   // used by repositories inside their drift transaction
  Future<void> upsert(String entity, String id);
  Future<void> delete(String entity, String id);
  Future<void> photoUpload(String localPath);
  Future<void> photoDelete(String localPath);
}

class Uploader   { Future<UploadResult> run(); }      // outbox → server
class Downloader { Future<void> run({required bool full}); } // cursors, tombstones
class PhotoSync  { Future<void> fetchMissing(); }
class LegacyMover { Future<int> moveIfNeeded(Account a); } // rows moved
class SyncEngine {
  Stream<SyncStatus> get status;      // AllSaved | Sending | Waiting(n) | Rejected(n)
  Stream<SyncPhase?> get phase;       // moving | downloading | null
  void kick();                        // after local writes (debounced 1 s)
  Future<void> onStart(); Future<void> onResume(); void stop();
}
```

Ordering, coalescing, error classification and cursor rules: [research.md](../research.md) R7–R10.

## Repositories

`RecipeRepository(db, photos, writer, scope)` — every read filters by
`scope.householdId`; every write calls `SyncedWriter` inside the same
`_db.transaction`. Entities without UI yet (shopping, pantry, plans, ratings,
taste) get only the registry mappers in 006a; their future repositories MUST use
`SyncedWriter` the same way.
