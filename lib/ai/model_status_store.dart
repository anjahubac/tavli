import 'ai_models.dart';
import 'key_store.dart';

/// Pamti koji modeli su pauzirani i koliko su zahteva dobili danas,
/// posebno za svaki ključ (limiti važe po ključu).
abstract interface class ModelStatusStore {
  Future<DateTime?> blockedUntil(
    ModelSpec model, {
    KeyOrigin origin = KeyOrigin.user,
  });
  Future<void> block(
    ModelSpec model,
    DateTime until,
    String reason, {
    KeyOrigin origin = KeyOrigin.user,
  });
  Future<void> recordRequest(
    ModelSpec model,
    DateTime at, {
    KeyOrigin origin = KeyOrigin.user,
  });
}

class InMemoryModelStatusStore implements ModelStatusStore {
  final _blockedUntil = <String, DateTime>{};
  final _requests = <String, int>{};
  final lastErrors = <String, String>{};

  int requestsOn(
    ModelSpec model,
    DateTime day, {
    KeyOrigin origin = KeyOrigin.user,
  }) => _requests['${_slot(model, origin)}@${_day(day)}'] ?? 0;

  @override
  Future<DateTime?> blockedUntil(
    ModelSpec model, {
    KeyOrigin origin = KeyOrigin.user,
  }) async => _blockedUntil[_slot(model, origin)];

  @override
  Future<void> block(
    ModelSpec model,
    DateTime until,
    String reason, {
    KeyOrigin origin = KeyOrigin.user,
  }) async {
    _blockedUntil[_slot(model, origin)] = until;
    lastErrors[_slot(model, origin)] = reason;
  }

  @override
  Future<void> recordRequest(
    ModelSpec model,
    DateTime at, {
    KeyOrigin origin = KeyOrigin.user,
  }) async {
    final k = '${_slot(model, origin)}@${_day(at)}';
    _requests[k] = (_requests[k] ?? 0) + 1;
  }

  static String _slot(ModelSpec m, KeyOrigin o) => '${m.key}#${o.name}';
  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);
}
