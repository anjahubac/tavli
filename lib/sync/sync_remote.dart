import 'dart:typed_data';

/// Greška pri slanju ili preuzimanju. [code] je kod greške (HTTP status ili
/// Postgres kod), nikad sadržaj zapisa.
sealed class SyncError implements Exception {
  const SyncError(this.code);

  final String code;

  @override
  String toString() => '$runtimeType($code)';
}

/// Nema mreže, istek vremena, 5xx ili 429: pokušava se ponovo kasnije.
class TransientSyncError extends SyncError {
  const TransientSyncError(super.code);
}

/// 401: sesiju treba obnoviti.
class UnauthorizedSyncError extends SyncError {
  const UnauthorizedSyncError() : super('401');
}

/// Server trajno odbija zapis (neispravni podaci, prava): ne pokušava se
/// ponovo, ali ne blokira ostale izmene.
class PermanentSyncError extends SyncError {
  const PermanentSyncError(super.code);
}

/// Tabele na serveru (PostgREST). Baca [SyncError].
abstract interface class SyncRemote {
  /// Upsert po id-ju ([onConflict]).
  Future<void> upsert(
    String table,
    List<Map<String, Object?>> rows, {
    String onConflict = 'id',
  });

  Future<void> delete(String table, List<String> ids, {String idColumn = 'id'});

  Future<void> updateProfileName(String userId, String name);

  /// Redovi posle (since, afterId), redom po ([timeColumn], [idColumn]).
  Future<List<Map<String, Object?>>> fetchSince(
    String table, {
    required int limit,
    String? since,
    String? afterId,
    String timeColumn = 'updated_at',
    String idColumn = 'id',
  });
}

/// Privatni bucket sa slikama. Baca [SyncError].
abstract interface class PhotoRemote {
  /// Upsert: ponovljeno slanje je bezopasno.
  Future<void> upload(String objectKey, Uint8List jpeg);

  Future<Uint8List> download(String objectKey);

  Future<void> remove(List<String> objectKeys);
}
