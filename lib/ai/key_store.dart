import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ai_models.dart';

abstract interface class KeyStore {
  Future<String?> read(AIProvider provider);
  Future<void> write(AIProvider provider, String key);
  Future<void> delete(AIProvider provider);
}

/// Ključevi u Keychain-u (iOS, macOS) i Keystore-u (Android).
class SecureKeyStore implements KeyStore {
  SecureKeyStore()
    : _storage = const FlutterSecureStorage(
        // Klasičan keychain ne traži posebna prava (entitlements)
        // pa radi i u nepotpisanom debug build-u na macOS-u.
        mOptions: MacOsOptions(usesDataProtectionKeychain: false),
      );

  final FlutterSecureStorage _storage;

  static String _name(AIProvider p) => 'api_key_${p.name}';

  @override
  Future<String?> read(AIProvider provider) =>
      _storage.read(key: _name(provider));

  @override
  Future<void> write(AIProvider provider, String key) =>
      _storage.write(key: _name(provider), value: key.trim());

  @override
  Future<void> delete(AIProvider provider) =>
      _storage.delete(key: _name(provider));
}

class InMemoryKeyStore implements KeyStore {
  InMemoryKeyStore([Map<AIProvider, String>? keys]) : _keys = {...?keys};

  final Map<AIProvider, String> _keys;

  @override
  Future<String?> read(AIProvider provider) async => _keys[provider];

  @override
  Future<void> write(AIProvider provider, String key) async =>
      _keys[provider] = key;

  @override
  Future<void> delete(AIProvider provider) async => _keys.remove(provider);
}
