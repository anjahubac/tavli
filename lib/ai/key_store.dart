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

/// Odakle je ključ: korisnikov (Keychain/Keystore) ili ugrađen u Tavli.
enum KeyOrigin { user, builtIn }

class ApiCredential {
  const ApiCredential(this.provider, this.value, this.origin);

  final AIProvider provider;
  final String value;
  final KeyOrigin origin;

  /// Bez vrednosti ključa, da ne završi u logu.
  @override
  String toString() => 'ApiCredential(${provider.name}, ${origin.name})';
}

/// Ključevi koje router proba za provajdera, redom. Kasnije ga može
/// zameniti Cloudflare proxy bez izmena u routeru.
abstract interface class KeySource {
  Future<List<ApiCredential>> credentialsFor(AIProvider provider);
}

/// Ugrađeni ključevi iz `secrets.json` preko `--dart-define-from-file`.
class BuiltInKeys {
  const BuiltInKeys([this._keys = const {}]);

  factory BuiltInKeys.fromEnvironment() => const BuiltInKeys({
    AIProvider.gemini: String.fromEnvironment('GEMINI_API_KEY'),
    AIProvider.groq: String.fromEnvironment('GROQ_API_KEY'),
    AIProvider.openRouter: String.fromEnvironment('OPENROUTER_API_KEY'),
  });

  final Map<AIProvider, String> _keys;

  String? operator [](AIProvider provider) {
    final key = _keys[provider]?.trim();
    return key == null || key.isEmpty ? null : key;
  }

  bool has(AIProvider provider) => this[provider] != null;
}

/// Prvo korisnikov ključ, pa ugrađeni.
class LayeredKeySource implements KeySource {
  LayeredKeySource(this._own, this._builtIn);

  final KeyStore _own;
  final BuiltInKeys _builtIn;

  @override
  Future<List<ApiCredential>> credentialsFor(AIProvider provider) async {
    final own = (await _own.read(provider))?.trim();
    final builtIn = _builtIn[provider];
    return [
      if (own != null && own.isNotEmpty)
        ApiCredential(provider, own, KeyOrigin.user),
      if (builtIn != null) ApiCredential(provider, builtIn, KeyOrigin.builtIn),
    ];
  }
}
