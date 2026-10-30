import 'ai_models.dart';
import 'key_store.dart';

/// Oznaka ključa za pauze i brojanje: `builtIn`, `user` ili `user:<id>`
/// kad korisnik ima više ključeva.
String keySlot(KeyOrigin origin, String? keyId) =>
    keyId == null ? origin.name : '${origin.name}:$keyId';

/// Pamti koji modeli su pauzirani i koliko su zahteva dobili danas,
/// posebno za svaki ključ (limiti važe po ključu).
abstract interface class ModelStatusStore {
  Future<DateTime?> blockedUntil(
    ModelSpec model, {
    KeyOrigin origin = KeyOrigin.user,
    String? keyId,
  });
  Future<void> block(
    ModelSpec model,
    DateTime until,
    String reason, {
    KeyOrigin origin = KeyOrigin.user,
    String? keyId,
  });
  Future<void> recordRequest(
    ModelSpec model,
    DateTime at, {
    KeyOrigin origin = KeyOrigin.user,
    String? keyId,
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
    String? keyId,
  }) => _requests['${_slot(model, origin, keyId)}@${_day(day)}'] ?? 0;

  @override
  Future<DateTime?> blockedUntil(
    ModelSpec model, {
    KeyOrigin origin = KeyOrigin.user,
    String? keyId,
  }) async => _blockedUntil[_slot(model, origin, keyId)];

  @override
  Future<void> block(
    ModelSpec model,
    DateTime until,
    String reason, {
    KeyOrigin origin = KeyOrigin.user,
    String? keyId,
  }) async {
    _blockedUntil[_slot(model, origin, keyId)] = until;
    lastErrors[_slot(model, origin, keyId)] = reason;
  }

  @override
  Future<void> recordRequest(
    ModelSpec model,
    DateTime at, {
    KeyOrigin origin = KeyOrigin.user,
    String? keyId,
  }) async {
    final k = '${_slot(model, origin, keyId)}@${_day(at)}';
    _requests[k] = (_requests[k] ?? 0) + 1;
  }

  static String _slot(ModelSpec m, KeyOrigin o, String? keyId) =>
      '${m.key}#${keySlot(o, keyId)}';
  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);
}
