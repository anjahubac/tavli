import 'package:drift/drift.dart';

import '../ai/ai_models.dart';
import '../ai/model_status_store.dart';
import 'database.dart';

/// Pauze modela preživljavaju gašenje aplikacije.
class DriftModelStatusStore implements ModelStatusStore {
  DriftModelStatusStore(this._db);

  final AppDatabase _db;

  Future<ModelStatusRow?> _row(ModelSpec m) =>
      (_db.select(_db.modelStatuses)..where(
            (t) => t.provider.equals(m.provider.name) & t.model.equals(m.model),
          ))
          .getSingleOrNull();

  @override
  Future<DateTime?> blockedUntil(ModelSpec model) async =>
      (await _row(model))?.blockedUntil;

  @override
  Future<void> block(ModelSpec model, DateTime until, String reason) => _db
      .into(_db.modelStatuses)
      .insert(
        ModelStatusesCompanion.insert(
          provider: model.provider.name,
          model: model.model,
          blockedUntil: Value(until),
          lastError: Value(reason),
        ),
        onConflict: DoUpdate(
          (_) => ModelStatusesCompanion(
            blockedUntil: Value(until),
            lastError: Value(reason),
          ),
        ),
      );

  @override
  Future<void> recordRequest(ModelSpec model, DateTime at) async {
    final day = at.toIso8601String().substring(0, 10);
    final row = await _row(model);
    final count = row?.usageDay == day ? row!.requestsToday + 1 : 1;
    await _db
        .into(_db.modelStatuses)
        .insert(
          ModelStatusesCompanion.insert(
            provider: model.provider.name,
            model: model.model,
            requestsToday: Value(count),
            usageDay: Value(day),
          ),
          onConflict: DoUpdate(
            (_) => ModelStatusesCompanion(
              requestsToday: Value(count),
              usageDay: Value(day),
            ),
          ),
        );
  }
}
