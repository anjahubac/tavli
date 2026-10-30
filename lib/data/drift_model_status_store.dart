import 'package:drift/drift.dart';

import '../ai/ai_models.dart';
import '../ai/key_store.dart';
import '../ai/model_status_store.dart';
import 'database.dart';

/// Pauze modela preživljavaju gašenje aplikacije, posebno za svaki ključ
/// (kolona keyOrigin čuva [keySlot], npr. `user:<id>`).
class DriftModelStatusStore implements ModelStatusStore {
  DriftModelStatusStore(this._db);

  final AppDatabase _db;

  Future<ModelStatusRow?> _row(ModelSpec m, String slot) =>
      (_db.select(_db.modelStatuses)..where(
            (t) =>
                t.provider.equals(m.provider.name) &
                t.model.equals(m.model) &
                t.keyOrigin.equals(slot),
          ))
          .getSingleOrNull();

  @override
  Future<DateTime?> blockedUntil(
    ModelSpec model, {
    KeyOrigin origin = KeyOrigin.user,
    String? keyId,
  }) async => (await _row(model, keySlot(origin, keyId)))?.blockedUntil;

  @override
  Future<void> block(
    ModelSpec model,
    DateTime until,
    String reason, {
    KeyOrigin origin = KeyOrigin.user,
    String? keyId,
  }) => _db
      .into(_db.modelStatuses)
      .insert(
        ModelStatusesCompanion.insert(
          provider: model.provider.name,
          model: model.model,
          keyOrigin: Value(keySlot(origin, keyId)),
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
  Future<void> recordRequest(
    ModelSpec model,
    DateTime at, {
    KeyOrigin origin = KeyOrigin.user,
    String? keyId,
  }) async {
    final day = at.toIso8601String().substring(0, 10);
    final row = await _row(model, keySlot(origin, keyId));
    final count = row?.usageDay == day ? row!.requestsToday + 1 : 1;
    await _db
        .into(_db.modelStatuses)
        .insert(
          ModelStatusesCompanion.insert(
            provider: model.provider.name,
            model: model.model,
            keyOrigin: Value(keySlot(origin, keyId)),
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
