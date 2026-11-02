import '../ai/key_store.dart';

/// Sesija (tokeni) samo u Keychain-u/Keystore-u, pod ključem `auth_session`
/// (FR-007). Nikad u bazi, logu ili običnom fajlu.
class SessionStore {
  const SessionStore(this._storage);

  final SecretStorage _storage;

  static const key = 'auth_session';

  Future<String?> read() => _storage.read(key);

  Future<void> write(String json) => _storage.write(key, json);

  Future<void> clear() => _storage.delete(key);
}
