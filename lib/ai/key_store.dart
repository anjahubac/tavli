import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ai_models.dart';
import 'secret_storage_errors.dart';

/// Počeci ključeva servisa koje Tavli ne podržava, a liče na podržane.
const _foreignPrefixes = ['sk-ant-'];

/// Servis po početku ključa; null kad format nije poznat. Važi najduži
/// početak koji se poklapa (`sk-or-` pre `sk-`).
AIProvider? detectProvider(String key) {
  final k = key.trim();
  if (_foreignPrefixes.any(k.startsWith)) return null;
  AIProvider? found;
  var longest = 0;
  for (final p in AIProvider.values) {
    for (final prefix in p.prefixes) {
      if (prefix.length > longest && k.startsWith(prefix)) {
        found = p;
        longest = prefix.length;
      }
    }
  }
  return found;
}

/// Kojim redom se probaju korisnikovi ključevi. Zajednički pristup preko
/// servera je uvek poslednji.
enum OwnKeyOrder { paidFirst, freeFirst }

/// Ključ koji je korisnik dodao.
class StoredKey {
  const StoredKey({
    required this.id,
    required this.provider,
    required this.value,
    required this.addedAt,
  });

  final String id;
  final AIProvider provider;
  final String value;
  final DateTime addedAt;

  /// Jedino što se prikazuje posle čuvanja.
  String get masked =>
      '••••${value.length <= 4 ? value : value.substring(value.length - 4)}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider.name,
    'value': value,
    'addedAt': addedAt.toUtc().toIso8601String(),
  };

  static StoredKey? fromJson(Object? json) {
    if (json is! Map) return null;
    final provider = AIProvider.values.asNameMap()[json['provider']];
    final id = json['id'];
    final value = json['value'];
    final addedAt = DateTime.tryParse(json['addedAt']?.toString() ?? '');
    if (provider == null || id is! String || value is! String) return null;
    return StoredKey(
      id: id,
      provider: provider,
      value: value,
      addedAt: addedAt ?? DateTime.utc(2026),
    );
  }

  /// Bez vrednosti ključa, da ne završi u logu.
  @override
  String toString() => 'StoredKey($id, ${provider.name})';
}

class DuplicateKeyException implements Exception {
  const DuplicateKeyException();
}

/// Ključevi koje je korisnik dodao, redom dodavanja.
abstract interface class KeyStore {
  Future<List<StoredKey>> list();

  /// Baca [DuplicateKeyException] ako je isti ključ već dodat.
  Future<StoredKey> add(AIProvider provider, String value);
  Future<void> remove(String id);

  /// Briše sve sopstvene ključeve (brisanje naloga, FR-025).
  Future<void> clear();
}

/// Greška sistemskog bezbednog skladišta. [code] je sistemski kod
/// (npr. -25293 kad je pristup odbijen), bez sadržaja zapisa.
class SecretStorageException implements Exception {
  const SecretStorageException(this.code);

  final String code;

  @override
  String toString() => 'SecretStorageException($code)';
}

/// Minimalni interfejs sigurnog skladišta (lakše se zameni u testu).
abstract interface class SecretStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Sistemsko bezbedno skladište: Keychain, Keystore ili Windows implementacija.
class KeychainSecretStorage implements SecretStorage {
  const KeychainSecretStorage();

  static const _storage = FlutterSecureStorage(
    // Klasičan keychain ne traži posebna prava (entitlements)
    // pa radi i u nepotpisanom debug build-u na macOS-u.
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  @override
  Future<String?> read(String key) => guard(() => _storage.read(key: key));

  @override
  Future<void> write(String key, String value) =>
      guard(() => _storage.write(key: key, value: value));

  @override
  Future<void> delete(String key) => guard(() => _storage.delete(key: key));

  /// Sistemske greške pretvara u [SecretStorageException]. Windows
  /// implementacija (FFI, bez kanala) baca WindowsException i
  /// FileSystemException umesto [PlatformException] (vidi
  /// `secret_storage_errors_io.dart`). Poruke (putanje) se ne prenose, samo kod.
  @visibleForTesting
  static Future<T> guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException catch (e) {
      throw SecretStorageException(e.code);
    } catch (e) {
      final code = nativeSecretStorageErrorCode(e);
      if (code == null) rethrow;
      throw SecretStorageException(code);
    }
  }
}

/// Ključevi u sistemskom bezbednom skladištu, kao jedna
/// JSON lista. Stari zapisi `api_key_<servis>` prelaze u listu pri čitanju.
class SecureKeyStore implements KeyStore {
  SecureKeyStore({
    SecretStorage? storage,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _storage = storage ?? const KeychainSecretStorage(),
       _clock = clock ?? DateTime.now,
       _newId = newId ?? _randomId;

  final SecretStorage _storage;
  final DateTime Function() _clock;
  final String Function() _newId;

  static const _listKey = 'api_keys';
  static String _legacyKey(AIProvider p) => 'api_key_${p.name}';

  static String _randomId() {
    final r = Random.secure();
    return List.generate(8, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  /// Ključevi posle prvog uspešnog čitanja. Router listu traži više puta po
  /// zahtevu, a svako čitanje Keychain-a može da traži lozinku na macOS-u.
  List<StoredKey>? _cache;

  @override
  Future<List<StoredKey>> list() async {
    final cached = _cache;
    if (cached != null) return cached;
    final keys = await _read();
    // Upis koji se završio tokom čitanja je noviji od pročitanog.
    return _cache ??= List.unmodifiable(keys);
  }

  Future<List<StoredKey>> _read() async {
    final raw = await _storage.read(_listKey);
    // Kad lista postoji, stari zapisi su već prebačeni: jedno čitanje
    // Keychain-a umesto četiri (svako može da traži lozinku na macOS-u).
    if (raw != null) return _decode(raw);
    final keys = <StoredKey>[];
    for (final p in AIProvider.values.where((p) => p.supportsPersonalKey)) {
      // Stari zapis je napravio prethodni build; macOS može da odbije
      // pristup. Tada ga preskačemo: korisnik ključ može ponovo da doda.
      final String? legacy;
      try {
        legacy = (await _storage.read(_legacyKey(p)))?.trim();
      } on SecretStorageException {
        continue;
      }
      if (legacy == null) continue;
      if (legacy.isNotEmpty && !keys.any((k) => k.value == legacy)) {
        keys.add(
          StoredKey(
            id: _newId(),
            provider: p,
            value: legacy,
            addedAt: _clock(),
          ),
        );
      }
      try {
        await _storage.delete(_legacyKey(p));
      } on SecretStorageException {
        // Ostaje u Keychain-u, ali se više ne čita (lista sada postoji).
      }
    }
    await _write(keys);
    return keys;
  }

  static List<StoredKey> _decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];
    return [for (final k in decoded) ?StoredKey.fromJson(k)];
  }

  @override
  Future<StoredKey> add(AIProvider provider, String value) async {
    final keys = await list();
    final v = value.trim();
    if (keys.any((k) => k.value == v)) throw const DuplicateKeyException();
    final key = StoredKey(
      id: _newId(),
      provider: provider,
      value: v,
      addedAt: _clock(),
    );
    await _save([...keys, key]);
    return key;
  }

  @override
  Future<void> remove(String id) async {
    final keys = await list();
    await _save([
      for (final k in keys)
        if (k.id != id) k,
    ]);
  }

  @override
  Future<void> clear() async {
    _cache = null;
    await _storage.delete(_listKey);
    for (final p in AIProvider.values.where((p) => p.supportsPersonalKey)) {
      await _storage.delete(_legacyKey(p));
    }
    _cache = const [];
  }

  /// Upisuje listu i tek posle uspeha je pamti; posle greške se sledeći put
  /// čita iz skladišta.
  Future<void> _save(List<StoredKey> keys) async {
    _cache = null;
    await _write(keys);
    _cache = List.unmodifiable(keys);
  }

  Future<void> _write(List<StoredKey> keys) =>
      _storage.write(_listKey, jsonEncode([for (final k in keys) k.toJson()]));
}

/// Web: sopstveni ključevi se ne čuvaju u pregledaču (spec 036, D2). Lista je
/// uvek prazna, a pristup ide samo preko servera.
class NoOwnKeyStore implements KeyStore {
  const NoOwnKeyStore();

  @override
  Future<List<StoredKey>> list() async => const [];

  @override
  Future<StoredKey> add(AIProvider provider, String value) =>
      throw UnsupportedError('Sopstveni ključevi ne rade u pregledaču.');

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> clear() async {}
}

/// Za testove. Početni ključevi dobijaju id = naziv servisa.
class InMemoryKeyStore implements KeyStore {
  InMemoryKeyStore([Map<AIProvider, String>? keys])
    : _keys = [
        for (final MapEntry(:key, :value) in {...?keys}.entries)
          StoredKey(
            id: key.name,
            provider: key,
            value: value,
            addedAt: DateTime.utc(2026),
          ),
      ];

  final List<StoredKey> _keys;
  var _n = 0;

  @override
  Future<List<StoredKey>> list() async => List.unmodifiable(_keys);

  @override
  Future<StoredKey> add(AIProvider provider, String value) async {
    final v = value.trim();
    if (_keys.any((k) => k.value == v)) throw const DuplicateKeyException();
    final key = StoredKey(
      id: '${provider.name}-${++_n}',
      provider: provider,
      value: v,
      addedAt: DateTime.utc(2026),
    );
    _keys.add(key);
    return key;
  }

  @override
  Future<void> remove(String id) async => _keys.removeWhere((k) => k.id == id);

  @override
  Future<void> clear() async => _keys.clear();
}

/// Odakle je pristup: korisnikov ključ (bezbedno skladište) ili zajednički
/// pristup koji dolazi uz Tavli (preko servera, bez ključa na uređaju).
enum KeyOrigin { user, builtIn }

class ApiCredential {
  const ApiCredential(
    this.provider,
    String this.value,
    this.origin, {
    this.keyId,
  });

  const ApiCredential.gateway(this.provider)
    : value = null,
      origin = KeyOrigin.builtIn,
      keyId = null;

  final AIProvider provider;
  final String? value;
  final KeyOrigin origin;

  /// Id sačuvanog ključa (samo za sopstvene ključeve).
  final String? keyId;

  /// Oznaka ključa za pauze i odbijene ključeve.
  String get slot => keyId == null ? origin.name : '${origin.name}:$keyId';

  /// Bez vrednosti ključa, da ne završi u logu.
  @override
  String toString() => 'ApiCredential(${provider.name}, ${origin.name})';
}

/// Ključevi koje router proba za provajdera, redom.
abstract interface class KeySource {
  Future<List<ApiCredential>> credentialsFor(AIProvider provider);
}

/// Korisnikovi ključevi, redom dodavanja.
class OwnKeySource implements KeySource {
  OwnKeySource(this._own);

  final KeyStore _own;

  @override
  Future<List<ApiCredential>> credentialsFor(AIProvider provider) async => [
    for (final k in await _own.list())
      if (k.provider == provider && k.value.trim().isNotEmpty)
        ApiCredential(provider, k.value.trim(), KeyOrigin.user, keyId: k.id),
  ];
}
