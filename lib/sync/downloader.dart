import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../account/auth_controller.dart';
import '../data/database.dart';
import 'catalog_status.dart';
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
    DateTime Function()? clock,
    this.pageSize = 500,
    this.overlap = const Duration(seconds: 60),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final AppDatabase _db;
  final SyncRemote _remote;
  final AccountScope _scope;
  final int pageSize;
  final Duration overlap;

  static const _deletions = 'deletions';

  /// Baca [SyncError] za greške mreže. Neprimenljivi redovi ostaju ispred
  /// sačuvane pozicije, a nezavisni podaci se ipak preuzimaju. `deferred`
  /// je broj takvih redova (0 = sve je primenjeno). `catalog` je ishod
  /// preuzimanja kataloga namirnica; njegova greška ne zaustavlja ostalo.
  Future<({int deferred, bool adoptedWeek, CatalogStatus catalog})>
  run() async {
    await _rewindIfDue();
    var adoptedWeek = false;
    final deferred = <(String, String)>{};
    var skipped = await _pull(
      key: profileEntity,
      table: 'profiles',
      apply: (row) async {
        await _applyProfile(row);
        return true;
      },
    );
    for (final e in syncEntities) {
      skipped += await _pull(
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
    }
    final catalog = await _pullCatalog(deferred);
    skipped += catalog.skipped;
    skipped += await _pull(
      key: _deletions,
      table: _deletions,
      timeColumn: 'deleted_at',
      apply: (row) async {
        await _applyTombstone(row);
        return true;
      },
    );
    await _refreshRatingSummaries();
    return (
      deferred: skipped,
      adoptedWeek: adoptedWeek,
      catalog: catalog.status,
    );
  }

  // Timestamp ordering can differ from commit ordering. Periodically start a
  // fresh paged pass, including tombstones. Record the rewind atomically so
  // an interrupted pass resumes from its ordinary per-table checkpoints.
  Future<void> _rewindIfDue() => _db.transaction(() async {
    const marker = '_last_full_rewind';
    final now = _clock().toUtc();
    final previous =
        await (_db.select(_db.syncCursors)..where(
              (row) =>
                  row.accountId.equals(_scope.userId) &
                  row.entity.equals(marker),
            ))
            .getSingleOrNull();
    if (previous != null &&
        !now.isBefore(previous.updatedAt) &&
        now.difference(previous.updatedAt) < const Duration(days: 1)) {
      return;
    }
    await (_db.delete(
      _db.syncCursors,
    )..where((row) => row.accountId.equals(_scope.userId))).go();
    await _db
        .into(_db.syncCursors)
        .insert(
          SyncCursorsCompanion.insert(
            accountId: _scope.userId,
            entity: marker,
            updatedAt: now,
            lastId: '',
          ),
        );
  });

  /// Katalog namirnica (018, data-model.md „Rollout“ korak 3): samo čitanje.
  /// Stariji server bez tabela nije greška za korisnika. Kad je pristup
  /// domaćinstvu odbijen, kućni redovi tog domaćinstva i pozicija kataloga
  /// se brišu (sledeće uspešno preuzimanje ih vraća), a deljeni ostaju.
  /// Greške mreže i istekla sesija idu dalje kao i do sada.
  Future<({int skipped, CatalogStatus status})> _pullCatalog(
    Set<(String, String)> deferred,
  ) async {
    var skipped = 0;
    try {
      // RLS pri gubitku članstva samo sakrije redove (bez greške), pa se
      // članstvo proverava odvojeno od rezultata kataloga.
      if (!await _isMember()) {
        return await _catalogAccessDenied();
      }
      for (final e in catalogEntities) {
        skipped += await _pullCatalogEntity(e, deferred);
      }
      if (!await _isMember()) {
        return await _catalogAccessDenied();
      }
    } on PermanentSyncError catch (error) {
      final status = catalogStatusFor(error);
      if (status == CatalogStatus.accessDenied) {
        return await _catalogAccessDenied();
      }
      return (skipped: skipped, status: status);
    }
    return (skipped: skipped, status: CatalogStatus.available);
  }

  /// Domaćinstvo je vidljivo samo članu (RLS na `households`).
  Future<bool> _isMember() async {
    String? since;
    String? afterId;
    while (true) {
      final rows = await _remote.fetchSince(
        'households',
        limit: 50,
        since: since,
        afterId: afterId,
      );
      if (rows.any((r) => r['id'] == _scope.householdId)) return true;
      if (rows.length < 50) return false;
      since = rows.last['updated_at']! as String;
      afterId = rows.last['id']! as String;
    }
  }

  /// Jedan prolaz, pa (ako je nešto odloženo) još jedan: ispravka deljenog
  /// zapisa može da stigne sa zamenom na jednoj strani i povlačenjem na
  /// sledećoj; zamena tada udari u jedinstveni indeks, a drugi prolaz je
  /// primenjuje pošto je povlačenje već upisano.
  Future<int> _pullCatalogEntity(
    SyncEntity<Table, Object?> e,
    Set<(String, String)> deferred,
  ) async {
    var skipped = 0;
    for (var pass = 0; pass < 2; pass++) {
      if (pass == 1) deferred.removeWhere((d) => d.$1 == e.name);
      skipped = await _pull(
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
          await _applyRow(e, row);
          return true;
        },
        onDeferred: (id) => deferred.add((e.name, id)),
        // Ispravka deljenog zapisa: povlačenje starog reda i zamena pod
        // istim ključem mogu da stignu bilo kojim redom (isto vreme izmene
        // u istoj migraciji). Povučeni deljeni redovi strane se primenjuju
        // prvi, pa zamena ne udari u lokalni jedinstveni indeks. Ponovna
        // primena istog reda u nastavku je upis po id-ju (bez štete).
        beforePage: (page) async {
          for (final row in page) {
            if (row['household_id'] == null && row['withdrawn_at'] != null) {
              await _tryApply(e.name, (r) async {
                await _applyRow(e, r);
                return true;
              }, row);
            }
          }
        },
      );
      if (skipped == 0) break;
    }
    return skipped;
  }

  Future<({int skipped, CatalogStatus status})> _catalogAccessDenied() async {
    await _db.transaction(() async {
      final hid = _scope.householdId;
      await (_db.delete(
        _db.foodAliases,
      )..where((t) => t.householdId.equals(hid))).go();
      await (_db.delete(
        _db.foods,
      )..where((t) => t.householdId.equals(hid))).go();
      await (_db.delete(_db.syncCursors)..where(
            (t) =>
                t.accountId.equals(_scope.userId) &
                t.entity.isIn([for (final e in catalogEntities) e.name]),
          ))
          .go();
      await (_db.update(_db.accounts)..where(
            (t) => t.userId.equals(_scope.userId) & t.householdId.equals(hid),
          ))
          .write(
            AccountsCompanion(
              catalogStatus: Value(CatalogStatus.accessDenied.name),
            ),
          );
    });
    return (skipped: 0, status: CatalogStatus.accessDenied);
  }

  Future<void> _refreshRatingSummaries() async {
    final List<Map<String, Object?>> rows;
    try {
      rows = await _remote.fetchHouseholdRecipeRatingSummaries();
    } on SyncError catch (error) {
      if (error is UnauthorizedSyncError) rethrow;
      // The summary is optional; keep the cached values until the next pull.
      return;
    }
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
        final recipe =
            await (_db.select(_db.recipes)..where(
                  (t) =>
                      t.id.equals(row.recipeId.value) &
                      t.householdId.equals(_scope.householdId),
                ))
                .getSingleOrNull();
        if (recipe == null) continue;
        await _db.into(_db.ratingSummaries).insertOnConflictUpdate(row);
      }
    });
  }

  /// Vraća broj odloženih redova.
  Future<int> _pull({
    required String key,
    required String table,
    required Future<bool> Function(Map<String, Object?>) apply,
    void Function(String id)? onDeferred,
    Future<void> Function(List<Map<String, Object?>> page)? beforePage,
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
    var skipped = 0;
    while (true) {
      final rows = await _remote.fetchSince(
        table,
        limit: pageSize,
        since: since,
        afterId: afterId,
        timeColumn: timeColumn,
        idColumn: idColumn,
      );
      if (rows.isEmpty) return skipped;
      final last = rows.last;
      since = _iso(DateTime.parse(last[timeColumn]! as String));
      afterId = last[idColumn]! as String;
      await _db.transaction(() async {
        await beforePage?.call(rows);
        Map<String, Object?>? checkpoint;
        for (final row in rows) {
          if (await _tryApply(key, apply, row)) {
            if (skipped == 0) checkpoint = row;
          } else {
            skipped++;
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
      if (rows.length < pageSize) return skipped;
    }
  }

  Future<bool> _tryApply(
    String entity,
    Future<bool> Function(Map<String, Object?>) apply,
    Map<String, Object?> row,
  ) async {
    try {
      // Savepoint: ako jedan zapis ne prođe, poništi i njegove pomoćne izmene.
      return await _db.transaction(() => apply(row));
    } on FormatException catch (error) {
      _logDeferred(entity, error.runtimeType.toString());
      return false;
    } on InvalidDataException catch (error) {
      _logDeferred(entity, error.runtimeType.toString());
      return false;
    } on Object catch (error) {
      final cause = switch (error) {
        DriftRemoteException(:final remoteCause) => remoteCause,
        DriftWrappedException(:final cause) => cause,
        _ => error,
      };
      if (cause is SqliteException && cause.resultCode == 19) {
        // SQLITE_CONSTRAINT; prošireni kod razlikuje UNIQUE, FK, NOT NULL...
        _logDeferred(entity, 'SQLITE_CONSTRAINT ${cause.extendedResultCode}');
        return false;
      }
      rethrow;
    }
  }

  /// Samo entitet i vrsta greške: poruke mogu da sadrže lične podatke.
  static void _logDeferred(String entity, String reason) {
    if (kDebugMode) debugPrint('Preuzimanje: odložen zapis $entity ($reason)');
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
    if (e is RatingEntity) {
      if (row['user_id'] != _scope.userId) return false;
      final local =
          await (_db.select(_db.ratings)..where(
                (t) =>
                    t.userId.equals(_scope.userId) &
                    t.recipeId.equals(row['recipe_id']! as String),
              ))
              .getSingleOrNull();
      if (local != null && local.id != id) {
        if (await _hasLocalChange(e.name, local.id)) return false;
        await e.deleteLocal(_db, local.id);
      }
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
    if (e is RecipeEntity) await _clearRecipeRatings(id);
    await e.deleteLocal(_db, id);
    await (_db.delete(_db.syncOutbox)..where(
          (t) =>
              t.accountId.equals(_scope.userId) &
              t.entity.equals(e.name) &
              t.recordId.equals(id),
        ))
        .go();
  }

  Future<void> _clearRecipeRatings(String recipeId) async {
    final rating =
        await (_db.select(_db.ratings)..where(
              (t) =>
                  t.userId.equals(_scope.userId) & t.recipeId.equals(recipeId),
            ))
            .getSingleOrNull();
    if (rating != null) {
      const entity = RatingEntity();
      await entity.deleteLocal(_db, rating.id);
      await (_db.delete(_db.syncOutbox)..where(
            (t) =>
                t.accountId.equals(_scope.userId) &
                t.entity.equals(entity.name) &
                t.recordId.equals(rating.id),
          ))
          .go();
    }
    await (_db.delete(_db.ratingSummaries)..where(
          (t) =>
              t.householdId.equals(_scope.householdId) &
              t.recipeId.equals(recipeId),
        ))
        .go();
  }
}
