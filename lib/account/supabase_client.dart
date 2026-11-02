import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import 'supabase_config.dart';

/// Supabase klijent (Auth, PostgREST, Storage, Functions). [httpClient]
/// se menja u testovima. Sesija se ne čuva u klijentu nego u
/// `SessionStore` (Keychain/Keystore).
SupabaseClient createSupabaseClient(
  SupabaseConfig config, {
  http.Client? httpClient,
}) => SupabaseClient(
  config.url,
  config.anonKey,
  httpClient: httpClient,
  authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  // Ponavljanje i pauze vodi red za slanje (SyncEngine), ne klijent.
  postgrestOptions: const PostgrestClientOptions(
    retryEnabled: false,
    requestTimeout: Duration(seconds: 30),
  ),
);

/// Sesija kao JSON (za `SessionStore` i `recoverSession`).
String jsonEncodeSession(Session s) => jsonEncode(s.toJson());
