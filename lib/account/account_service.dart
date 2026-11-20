import 'dart:convert';

import 'package:drift/drift.dart';

import '../ai/key_store.dart';
import '../data/database.dart';
import '../data/recipe_photo_store.dart';
import '../domain/account.dart';
import '../sync/entities.dart';
import '../sync/synced_writer.dart';
import 'account_api.dart';
import 'auth_gateway.dart';

/// Nalog na uređaju: keširan profil i domaćinstvo (za pokretanje bez
/// mreže), ime i brisanje naloga.
class AccountService {
  AccountService(
    this._db,
    this._api, {
    this._photos,
    this._keys,
    DateTime Function()? clock,
    this._onChange,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final AccountApi _api;
  final RecipePhotoStore? _photos;
  final KeyStore? _keys;
  final DateTime Function() _clock;
  final void Function()? _onChange;

  /// Nalog sačuvan na uređaju (bez mreže) ili null.
  Future<Account?> cached(String userId) async {
    final row = await (_db.select(
      _db.accounts,
    )..where((t) => t.userId.equals(userId))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Keširan nalog, a ako ga nema na uređaju — sa servera (prva prijava
  /// na ovom uređaju). Baca `AuthFailure`.
  Future<Account> loadOrFetch(AuthSession session) async {
    final local = await cached(session.userId);
    if (local != null) return local;
    final remote = await _api.fetch();
    await _db
        .into(_db.accounts)
        .insertOnConflictUpdate(
          AccountsCompanion.insert(
            userId: remote.userId,
            email: normalizeEmail(remote.email),
            displayName: Value(remote.displayName),
            householdId: remote.householdId,
            householdName: remote.householdName,
            role: remote.role,
            createdAt: _clock(),
          ),
        );
    return (await cached(remote.userId))!;
  }

  Future<Account> refreshMembership(Account account) async {
    final remote = await _api.fetch();
    if (remote.userId != account.userId) throw const SessionRevoked();
    return _saveMembership(account, remote);
  }

  Future<HouseholdJoinResult> confirmHouseholdJoin({
    required Account account,
    required String token,
    required JoinRecipeChoice recipeChoice,
    required bool acknowledgeSourceDeletion,
    required String operationId,
  }) async {
    final queued =
        await (_db.select(_db.syncOutbox)
              ..where(
                (t) =>
                    t.accountId.equals(account.userId) &
                    (t.lastError.isNull() |
                        t.lastError.equals('household_changed').not()),
              )
              ..limit(1))
            .getSingleOrNull();
    if (queued != null) {
      return const HouseholdJoinResult(status: 'pending_sync');
    }
    final result = await _api.confirmHouseholdJoin(
      token: token,
      expectedSourceHouseholdId: account.householdId,
      recipeChoice: recipeChoice,
      acknowledgeSourceDeletion: acknowledgeSourceDeletion,
      operationId: operationId,
    );
    if (result.account case final remote?) {
      if (remote.userId != account.userId) throw const SessionRevoked();
      await _saveMembership(account, remote);
    }
    return result;
  }

  Future<Account> _saveMembership(Account account, RemoteAccount remote) =>
      _db.transaction(() async {
        final current = await cached(account.userId);
        if (current == null) throw const SessionRevoked();
        if (current.householdId != account.householdId) return current;

        final switched = current.householdId != remote.householdId;
        if (switched) {
          final householdEntities = [
            for (final entity in syncEntities)
              if (entity.scope == EntityScope.household ||
                  entity.name == 'rating')
                entity.name,
          ];
          await (_db.update(_db.syncOutbox)..where(
                (t) =>
                    t.accountId.equals(account.userId) &
                    t.entity.isIn([...householdEntities, 'photo']),
              ))
              .write(
                const SyncOutboxCompanion(
                  state: Value(OutboxState.rejected),
                  lastError: Value('household_changed'),
                ),
              );
          await (_db.delete(
            _db.syncCursors,
          )..where((t) => t.accountId.equals(account.userId))).go();
        }
        await (_db.update(
          _db.accounts,
        )..where((t) => t.userId.equals(account.userId))).write(
          AccountsCompanion(
            householdId: Value(remote.householdId),
            householdName: Value(remote.householdName),
            role: Value(remote.role),
            initialDownloadDone: switched
                ? const Value(false)
                : const Value.absent(),
            lastPullAt: switched ? const Value(null) : const Value.absent(),
          ),
        );
        return current.copyWith(
          householdId: remote.householdId,
          householdName: remote.householdName,
          role: remote.role,
        );
      });

  /// Čuva ime (1–40 znakova posle skidanja razmaka) lokalno i u redu za
  /// slanje. Baca [ArgumentError] za neispravno ime.
  Future<Account> saveName(Account account, String name) async {
    final n = normalizeName(name);
    if (n == null) throw ArgumentError.value(name, 'name');
    await _db.transaction(() async {
      await (_db.update(_db.accounts)
            ..where((t) => t.userId.equals(account.userId)))
          .write(AccountsCompanion(displayName: Value(n)));
      await SyncedWriter(
        _db,
        accountId: account.userId,
        clock: _clock,
        onChange: _onChange,
      ).upsert(profileEntity, account.userId);
    });
    return account.copyWith(displayName: n);
  }

  /// "Obriši nalog": prvo server (Edge Function), pa tek posle uspeha sve
  /// na uređaju: keš naloga, izmene koje čekaju, slike i sopstveni AI
  /// ključevi. Tema i pauze modela ostaju. Baca [DeleteFailure]; tada se na
  /// uređaju ne briše ništa (FR-024).
  Future<void> deleteAccount(Account account) async {
    await _api.deleteAccount();
    await wipeLocal(account.userId);
    await _keys?.clear();
  }

  /// Briše sa uređaja sve što pripada nalogu (i kad je nalog obrisan na
  /// drugom uređaju). Podaci drugih naloga ostaju.
  Future<void> wipeLocal(String userId) async {
    final account = await (_db.select(
      _db.accounts,
    )..where((t) => t.userId.equals(userId))).getSingleOrNull();
    final hid = account?.householdId;
    final photos = <String>{};
    await _db.transaction(() async {
      if (hid != null) {
        for (final r in await (_db.select(
          _db.recipes,
        )..where((t) => t.householdId.equals(hid))).get()) {
          if (r.imagePath case final p?) photos.add(p);
        }
        for (final v in await (_db.select(
          _db.recipeVersions,
        )..where((t) => t.householdId.equals(hid))).get()) {
          if (_imagePath(v.recipeJson) case final p?) photos.add(p);
        }
        // Deca pre roditelja: raspodela, doprinosi, izvori, pa liste i ostava.
        await (_db.delete(
          _db.supplyAllocations,
        )..where((t) => t.householdId.equals(hid))).go();
        await (_db.delete(
          _db.shoppingContributions,
        )..where((t) => t.householdId.equals(hid))).go();
        await (_db.delete(
          _db.shoppingSources,
        )..where((t) => t.householdId.equals(hid))).go();
        await (_db.delete(
          _db.recipeVersions,
        )..where((t) => t.householdId.equals(hid))).go();
        await (_db.delete(
          _db.recipes,
        )..where((t) => t.householdId.equals(hid))).go();
        await (_db.delete(
          _db.shoppingItems,
        )..where((t) => t.householdId.equals(hid))).go();
        await (_db.delete(
          _db.shoppingLists,
        )..where((t) => t.householdId.equals(hid))).go();
        await (_db.delete(
          _db.pantryItems,
        )..where((t) => t.householdId.equals(hid))).go();
        await (_db.delete(
          _db.mealPlanEntries,
        )..where((t) => t.householdId.equals(hid))).go();
        await (_db.delete(
          _db.mealPlans,
        )..where((t) => t.householdId.equals(hid))).go();
      }
      await (_db.delete(
        _db.ratings,
      )..where((t) => t.userId.equals(userId))).go();
      await (_db.delete(
        _db.userProfiles,
      )..where((t) => t.id.equals(userId))).go();
      await (_db.delete(
        _db.syncOutbox,
      )..where((t) => t.accountId.equals(userId))).go();
      await (_db.delete(
        _db.syncCursors,
      )..where((t) => t.accountId.equals(userId))).go();
      await (_db.delete(
        _db.accounts,
      )..where((t) => t.userId.equals(userId))).go();
    });
    for (final p in photos) {
      await _photos?.delete(p);
    }
  }

  static String? _imagePath(String recipeJson) {
    try {
      final json = jsonDecode(recipeJson);
      return json is Map && json['imagePath'] is String
          ? json['imagePath'] as String
          : null;
    } on FormatException {
      return null;
    }
  }

  static Account _fromRow(AccountRow r) => Account(
    userId: r.userId,
    email: r.email,
    displayName: r.displayName,
    householdId: r.householdId,
    householdName: r.householdName,
    role: r.role,
  );
}
