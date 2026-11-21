import 'package:tavli/ai/key_store.dart';

/// Keychain u memoriji.
class MapSecretStorage implements SecretStorage {
  final values = <String, String>{};
  final deniedReads = <String>{};
  final deniedWrites = <String>{};
  final deniedDeletes = <String>{};

  @override
  Future<String?> read(String key) async {
    if (deniedReads.contains(key)) {
      throw const SecretStorageException('access_denied');
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (deniedWrites.contains(key)) {
      throw const SecretStorageException('access_denied');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (deniedDeletes.contains(key)) {
      throw const SecretStorageException('access_denied');
    }
    values.remove(key);
  }
}
