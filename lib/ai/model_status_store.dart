import 'ai_models.dart';

/// Pamti koji modeli su pauzirani i koliko su zahteva dobili danas.
abstract interface class ModelStatusStore {
  Future<DateTime?> blockedUntil(ModelSpec model);
  Future<void> block(ModelSpec model, DateTime until, String reason);
  Future<void> recordRequest(ModelSpec model, DateTime at);
}

class InMemoryModelStatusStore implements ModelStatusStore {
  final _blockedUntil = <String, DateTime>{};
  final _requests = <String, int>{};
  final lastErrors = <String, String>{};

  int requestsOn(ModelSpec model, DateTime day) =>
      _requests['${model.key}@${_day(day)}'] ?? 0;

  @override
  Future<DateTime?> blockedUntil(ModelSpec model) async =>
      _blockedUntil[model.key];

  @override
  Future<void> block(ModelSpec model, DateTime until, String reason) async {
    _blockedUntil[model.key] = until;
    lastErrors[model.key] = reason;
  }

  @override
  Future<void> recordRequest(ModelSpec model, DateTime at) async {
    final k = '${model.key}@${_day(at)}';
    _requests[k] = (_requests[k] ?? 0) + 1;
  }

  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);
}
