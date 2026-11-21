import 'package:drift/drift.dart';

import '../account/auth_controller.dart';
import '../data/database.dart';
import 'entities.dart';
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

  /// Baca [SyncError] (nastavlja se sledeći put od sačuvane pozicije).
  Future<void> run() async {
    await _pull(key: profileEntity, table: 'profiles', apply: _applyProfile);
    for (final e in syncEntities) {
      await _pull(
        key: e.name,
        table: e.remoteTable,
        idColumn: e.remoteId,
        apply: (row) => _applyRow(e, row),
      );
    }
    await _pull(
      key: _deletions,
      table: _deletions,
      timeColumn: 'deleted_at',
      apply: _applyTombstone,
    );
    await _refreshRatingSummaries();
  }

  Future<void> _refreshRatingSummaries() async {
    final rows = await _remote.fetchHouseholdRecipeRatingSummaries();
    final valid = <RatingSummariesCompanion>[];
    for (final row in rows) {
      final householdId = row['household_id'] as String?;
      final recipeId = row['recipe_id'] as String?;
      final rawAverage = row['average_stars'];
      final average = rawAverage is num
          ? rawAverage.toDouble()
          : double.tryParse(rawAverage is String ? rawAverage : '');
      final count = (row['rating_count'] as num?)?.toInt();
      if (householdId != _scope.householdId ||
          recipeId == null ||
          average == null ||
          !average.isFinite ||
          average < 1 ||
          average > 5 ||
          count == null ||
          count < 1) {
        continue;
      }
      final recipe =
          await (_db.select(_db.recipes)..where(
                (t) =>
                    t.id.equals(recipeId) &
                    t.householdId.equals(_scope.householdId),
              ))
              .getSingleOrNull();
      if (recipe == null) continue;
      valid.add(
        RatingSummariesCompanion.insert(
          householdId: householdId!,
          recipeId: recipeId,
          averageStars: average,
          ratingCount: count,
        ),
      );
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.ratingSummaries,
      )..where((t) => t.householdId.equals(_scope.householdId))).go();
      for (final row in valid) {
        await _db.into(_db.ratingSummaries).insertOnConflictUpdate(row);
      }
    });
  }

  Future<void> _pull({
    required String key,
    required String table,
    required Future<void> Function(Map<String, Object?>) apply,
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
    while (true) {
      final rows = await _remote.fetchSince(
        table,
        limit: pageSize,
        since: since,
        afterId: afterId,
        timeColumn: timeColumn,
        idColumn: idColumn,
      );
      if (rows.isEmpty) return;
      final last = rows.last;
      since = _iso(DateTime.parse(last[timeColumn]! as String));
      afterId = last[idColumn]! as String;
      await _db.transaction(() async {
        for (final r in rows) {
          await apply(r);
        }
        await _db
            .into(_db.syncCursors)
            .insertOnConflictUpdate(
              SyncCursorsCompanion.insert(
                accountId: _scope.userId,
                entity: key,
                updatedAt: DateTime.parse(since!),
                lastId: afterId!,
              ),
            );
      });
      if (rows.length < pageSize) return;
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

  Future<void> _applyRow(
    SyncEntity<Table, Object?> e,
    Map<String, Object?> row,
  ) async {
    final id = row[e.remoteId]! as String;
    if (await _hasLocalChange(e.name, id)) return;
    if (e is RatingEntity) {
      if (row['user_id'] != _scope.userId) return;
      final local =
          await (_db.select(_db.ratings)..where(
                (t) =>
                    t.userId.equals(_scope.userId) &
                    t.recipeId.equals(row['recipe_id']! as String),
              ))
              .getSingleOrNull();
      if (local != null && local.id != id) {
        if (await _hasLocalChange(e.name, local.id)) return;
        await e.deleteLocal(_db, local.id);
      }
    }
    await e.write(_db, row);
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
