import 'package:drift/drift.dart';

import '../data/database.dart';
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
    DateTime Function()? clock,
    this._onChange,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final AccountApi _api;
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

  static Account _fromRow(AccountRow r) => Account(
    userId: r.userId,
    email: r.email,
    displayName: r.displayName,
    householdId: r.householdId,
    householdName: r.householdName,
    role: r.role,
  );
}
