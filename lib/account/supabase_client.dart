import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../ai/key_store.dart';
import 'supabase_config.dart';

/// Supabase klijent (Auth, PostgREST, Storage, Functions). [httpClient]
/// se menja u testovima. Sesija se ne čuva u klijentu nego u
/// `SessionStore` (sistemsko bezbedno skladište). PKCE verifikator za link
/// iz mejla za potvrdu čuva se u [secrets] (isto sistemsko skladište), da
/// preživi zatvaranje aplikacije dok osoba otvara mejl.
SupabaseClient createSupabaseClient(
  SupabaseConfig config, {
  required SecretStorage secrets,
  http.Client? httpClient,
}) => SupabaseClient(
  config.url,
  config.anonKey,
  httpClient: httpClient,
  authOptions: AuthClientOptions(pkceAsyncStorage: PkceStorage(secrets)),
  // Ponavljanje i pauze vodi red za slanje (SyncEngine), ne klijent.
  postgrestOptions: const PostgrestClientOptions(
    retryEnabled: false,
    requestTimeout: Duration(seconds: 30),
  ),
);

/// Sesija kao JSON (za `SessionStore` i `recoverSession`).
String jsonEncodeSession(Session s) => jsonEncode(s.toJson());

/// PKCE verifikator (jedan, za poslednji poslat mejl) u sigurnom skladištu,
/// pod ključem `auth_pkce_<ključ klijenta>`.
class PkceStorage extends GotrueAsyncStorage {
  const PkceStorage(this._storage);

  final SecretStorage _storage;

  static const prefix = 'auth_pkce_';

  @override
  Future<String?> getItem({required String key}) =>
      _storage.read('$prefix$key');

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write('$prefix$key', value);

  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete('$prefix$key');
}
