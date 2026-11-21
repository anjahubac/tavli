import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException;

import '../account/auth_controller.dart';
import '../data/database.dart';
import 'entities.dart';
import 'shopping_week_recovery.dart';
import 'sync_remote.dart';

/// Preuzima podatke naloga sa servera (research R9): po entitetu, strane
/// od [pageSize] redova redom po (updated_at, id); pozicija se čuva posle
/// svake strane, pa se prekinuto preuzimanje nastavlja. Svako pokretanje
/// kreće [overlap] pre sačuvane pozicije (izmene koje su kasno potvrđene);
/// upis po id-ju je idempotentan.
class Downloader {
  Downloader({
    required this._db,
    required this._remote,
    required this._scope,
    this.pageSize = 500,
    this.overlap = const Duration(seconds: 60),
  });

  final AppDatabase _db;
  final SyncRemote _remote;
  final AccountScope _scope;
  final int pageSize;
  final Duration overlap;

  static const _deletions = 'deletions';

  /// Baca [SyncError] za greške mreže. Neprimenljivi redovi ostaju ispred
  /// sačuvane pozicije, a nezavisni podaci se ipak preuzimaju.
  Future<({bool complete, bool adoptedWeek})> run() async {
    var adoptedWeek = false;
    final deferred = <(String, String)>{};
    var complete = await _pull(
      key: profileEntity,
      table: 'profiles',
      apply: (row) async {
        await _applyProfile(row);
        return true;
      },
    );
    for (final e in syncEntities) {
      final applied = await _pull(
        key: e.name,
        table: e.remoteTable,
        idColumn: e.remoteId,
        apply: (row) async {
          if (e.parentKeys.any((key) {
            final id = row[key.$2];
            return id is String && deferred.contains((key.$1, id));
          })) {
            return false;
          }
          if (await _applyRow(e, row)) adoptedWeek = true;
          return true;
        },
        onDeferred: (id) => deferred.add((e.name, id)),
      );
      complete = applied && complete;
    }
    final deletionsApplied = await _pull(
      key: _deletions,
      table: _deletions,
      timeColumn: 'deleted_at',
      apply: (row) async {
        await _applyTombstone(row);
        return true;
      },
    );
    return (complete: deletionsApplied && complete, adoptedWeek: adoptedWeek);
  }

  Future<bool> _pull({
    required String key,
    required String table,
    required Future<bool> Function(Map<String, Object?>) apply,
    void Function(String id)? onDeferred,
    String timeColumn = 'updated_at',
    String idColumn = 'id',
  }) async {
    final cursor =
        await (_db.select(_db.syncCursors)..where(
              (t) => t.accountId.equals(_scope.userId) & t.entity.equals(key),
            ))
            .getSingleOrNull();
    String? since = cursor == null
        ? null
        : _iso(cursor.updatedAt.subtract(overlap));
    String? afterId;
    var complete = true;
    while (true) {
      final rows = await _remote.fetchSince(
        table,
        limit: pageSize,
        since: since,
        afterId: afterId,
        timeColumn: timeColumn,
        idColumn: idColumn,
      );
      if (rows.isEmpty) return complete;
      final last = rows.last;
      since = _iso(DateTime.parse(last[timeColumn]! as String));
      afterId = last[idColumn]! as String;
      await _db.transaction(() async {
        Map<String, Object?>? checkpoint;
        for (final row in rows) {
          if (await _tryApply(apply, row)) {
            if (complete) checkpoint = row;
          } else {
            complete = false;
            onDeferred?.call(row[idColumn]! as String);
          }
        }
        // Sačuvana pozicija sme da pređe samo neprekinuti niz upisa.
        if (checkpoint != null) {
          await _db
              .into(_db.syncCursors)
              .insertOnConflictUpdate(
                SyncCursorsCompanion.insert(
                  accountId: _scope.userId,
                  entity: key,
                  updatedAt: DateTime.parse(checkpoint[timeColumn]! as String),
                  lastId: checkpoint[idColumn]! as String,
                ),
              );
        }
      });
      if (rows.length < pageSize) return complete;
    }
  }

  Future<bool> _tryApply(
    Future<bool> Function(Map<String, Object?>) apply,
    Map<String, Object?> row,
  ) async {
    try {
      // Savepoint: ako jedan zapis ne prođe, poništi i njegove pomoćne izmene.
      return await _db.transaction(() => apply(row));
    } on FormatException {
      return false;
    } on InvalidDataException {
      return false;
    } on Object catch (error) {
      final cause = switch (error) {
        DriftRemoteException(:final remoteCause) => remoteCause,
        DriftWrappedException(:final cause) => cause,
        _ => error,
      };
      if (cause is SqliteException && cause.resultCode == 19) {
        return false; // SQLITE_CONSTRAINT
      }
      rethrow;
    }
  }

  static String _iso(DateTime d) => d.toUtc().toIso8601String();

  /// Ima li zapis lokalnu izmenu koja još nije na serveru (čeka, šalje
  /// se ili je odbijena): ona se ne prepisuje (FR-014).
  Future<bool> _hasLocalChange(String entity, String id) async =>
      await (_db.select(_db.syncOutbox)
            ..where(
              (t) =>
                  t.accountId.equals(_scope.userId) &
                  t.entity.equals(entity) &
                  t.recordId.equals(id),
            )
            ..limit(1))
          .getSingleOrNull() !=
      null;

  Future<bool> _applyRow(
    SyncEntity<Table, Object?> e,
    Map<String, Object?> row,
  ) async {
    final id = row[e.remoteId]! as String;
    if (await _hasLocalChange(e.name, id)) return false;
    if (e is ShoppingListEntity &&
        await adoptShoppingWeek(_db, _scope, e, row)) {
      return true;
    }
    await e.write(_db, row);
    return false;
  }

  Future<void> _applyProfile(Map<String, Object?> row) async {
    final id = row['id'] as String?;
    if (id != _scope.userId || await _hasLocalChange(profileEntity, id!)) {
      return;
    }
    await (_db.update(_db.accounts)..where((t) => t.userId.equals(id))).write(
      AccountsCompanion(displayName: Value(row['display_name'] as String?)),
    );
  }

  /// Brisanje sa drugog uređaja: briše se i lokalno, a izmene tog zapisa
  /// koje čekaju se odbacuju (brisanje pobeđuje).
  Future<void> _applyTombstone(Map<String, Object?> row) async {
    final e = entityByName(row['entity']! as String);
    final id = row['record_id']! as String;
    if (e == null) return;
    await e.deleteLocal(_db, id);
    await (_db.delete(_db.syncOutbox)..where(
          (t) =>
              t.accountId.equals(_scope.userId) &
              t.entity.equals(e.name) &
              t.recordId.equals(id),
        ))
        .go();
  }
}
