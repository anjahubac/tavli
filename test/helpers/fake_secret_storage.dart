import 'package:tavli/ai/key_store.dart';

/// Keychain u memoriji.
class MapSecretStorage implements SecretStorage {
  final values = <String, String>{};
  bool unavailable = false;

  @override
  Future<String?> read(String key) async {
    if (unavailable) throw const SecretStorageException('keyring-unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (unavailable) throw const SecretStorageException('keyring-unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (unavailable) throw const SecretStorageException('keyring-unavailable');
    values.remove(key);
  }
}
