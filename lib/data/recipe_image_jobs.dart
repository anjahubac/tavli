import 'package:drift/drift.dart';

import '../account/auth_controller.dart';
import 'database.dart';

/// Stavlja AI recept u lokalni red za AI sliku (TRELLO-130). Poziva se
/// unutar transakcije koja čuva recept; ponovljen poziv ništa ne menja.
Future<void> queueAiImage(
  AppDatabase db,
  AccountScope scope,
  String recipeId,
  DateTime now,
) => db
    .into(db.recipeImageJobs)
    .insert(
      RecipeImageJobsCompanion.insert(
        accountId: scope.userId,
        recipeId: recipeId,
        createdAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );

/// Recept koji čeka AI sliku, sa najbližim danom u planu (ako ga ima).
class RecipeImageJob {
  const RecipeImageJob({
    required this.recipeId,
    required this.createdAt,
    this.attempts = 0,
    this.retryAt,
    this.nextPlannedDay,
  });

  final String recipeId;
  final DateTime createdAt;
  final int attempts;
  final DateTime? retryAt;

  /// Najbliži dan od danas u planu obroka; null = recept nije u planu.
  final DateTime? nextPlannedDay;
}

/// Redosled obrade: prvo recepti iz plana, najbliži dan prvi; zatim ostali,
/// stariji prvi. Isti dan: stariji recept prvi.
List<RecipeImageJob> orderImageJobs(Iterable<RecipeImageJob> jobs) {
  final sorted = [...jobs];
  sorted.sort((a, b) {
    final da = a.nextPlannedDay;
    final dbDay = b.nextPlannedDay;
    if (da != null && dbDay == null) return -1;
    if (da == null && dbDay != null) return 1;
    if (da != null && dbDay != null) {
      final byDay = da.compareTo(dbDay);
      if (byDay != 0) return byDay;
    }
    final byCreated = a.createdAt.compareTo(b.createdAt);
    return byCreated != 0 ? byCreated : a.recipeId.compareTo(b.recipeId);
  });
  return sorted;
}

/// Lokalni red za AI slike jednog naloga.
class RecipeImageJobStore {
  RecipeImageJobStore(this._db, this._scope);

  final AppDatabase _db;
  final AccountScope _scope;

  SimpleSelectStatement<$RecipeImageJobsTable, RecipeImageJobRow> _mine() =>
      _db.select(_db.recipeImageJobs)
        ..where((t) => t.accountId.equals(_scope.userId));

  /// Menja se kad se red promeni (nov recept, odlaganje).
  Stream<void> watch() => _mine().watch().map((_) {});

  /// Poslove koji su na redu u [now], po [orderImageJobs]. [today] je
  /// početak današnjeg dana za plan.
  Future<List<RecipeImageJob>> due(
    DateTime now, {
    required DateTime today,
  }) async {
    final rows =
        await (_mine()..where(
              (t) => t.retryAt.isNull() | t.retryAt.isSmallerOrEqualValue(now),
            ))
            .get();
    if (rows.isEmpty) return const [];
    final ids = [for (final r in rows) r.recipeId];
    final planned = <String, DateTime>{};
    final entries =
        await (_db.select(_db.mealPlanEntries)..where(
              (t) =>
                  t.recipeId.isIn(ids) &
                  t.householdId.equals(_scope.householdId) &
                  t.isCooked.equals(false) &
                  t.date.isBiggerOrEqualValue(today),
            ))
            .get();
    for (final e in entries) {
      final id = e.recipeId!;
      final known = planned[id];
      if (known == null || e.date.isBefore(known)) planned[id] = e.date;
    }
    return orderImageJobs([
      for (final r in rows)
        RecipeImageJob(
          recipeId: r.recipeId,
          createdAt: r.createdAt,
          attempts: r.attempts,
          retryAt: r.retryAt,
          nextPlannedDay: planned[r.recipeId],
        ),
    ]);
  }

  /// Najranije vreme kad neki odloženi posao ponovo dolazi na red.
  Future<DateTime?> nextRetryAt() async {
    final rows = await (_mine()..where((t) => t.retryAt.isNotNull())).get();
    DateTime? first;
    for (final r in rows) {
      final at = r.retryAt!;
      if (first == null || at.isBefore(first)) first = at;
    }
    return first;
  }

  Future<void> remove(String recipeId) =>
      (_db.delete(_db.recipeImageJobs)..where(
            (t) =>
                t.accountId.equals(_scope.userId) & t.recipeId.equals(recipeId),
          ))
          .go();

  /// Odlaže jedan posao; [failed] povećava broj neuspelih pokušaja.
  Future<void> defer(String recipeId, DateTime until, {bool failed = false}) =>
      _db.transaction(() async {
        final row = await (_mine()..where((t) => t.recipeId.equals(recipeId)))
            .getSingleOrNull();
        if (row == null) return;
        await (_db.update(_db.recipeImageJobs)..where(
              (t) =>
                  t.accountId.equals(_scope.userId) &
                  t.recipeId.equals(recipeId),
            ))
            .write(
              RecipeImageJobsCompanion(
                retryAt: Value(until),
                attempts: Value(row.attempts + (failed ? 1 : 0)),
              ),
            );
      });

  /// Limit važi za sve: svi poslovi čekaju do [until].
  Future<void> deferAll(DateTime until) =>
      (_db.update(_db.recipeImageJobs)..where(
            (t) =>
                t.accountId.equals(_scope.userId) &
                (t.retryAt.isNull() | t.retryAt.isSmallerThanValue(until)),
          ))
          .write(RecipeImageJobsCompanion(retryAt: Value(until)));
}
