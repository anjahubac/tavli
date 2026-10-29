import 'dart:convert';

import 'ai_errors.dart';
import 'ai_models.dart';
import 'chain_config.dart';
import 'chat_client.dart';
import 'key_store.dart';
import 'model_status_store.dart';

class AIResult<T> {
  const AIResult(this.value, this.model, this.attempts);

  final T value;

  /// Model koji je dao odgovor (prikazuje se kao "Odgovorio: …").
  final ModelSpec model;
  final List<AttemptLog> attempts;
}

/// Prolazi kroz lanac modela dok neki ne vrati ispravan odgovor.
class AIRouter {
  AIRouter({
    required this.config,
    required this.client,
    required this.keys,
    required this.status,
    DateTime Function()? clock,
    this.minuteCooldown = const Duration(seconds: 60),
    this.unknownDailyCooldown = const Duration(hours: 1),
  }) : _clock = clock ?? DateTime.now;

  /// Funkcija, ne vrednost: korisnik može da promeni lanac dok app radi.
  final ChainConfig Function() config;
  final ChatClient client;
  final KeyStore keys;
  final ModelStatusStore status;
  final DateTime Function() _clock;
  final Duration minuteCooldown;
  final Duration unknownDailyCooldown;

  final _invalidProviders = <AIProvider>{};
  final _unavailableModels = <String>{};

  /// Provajderi čiji ključ je odbijen; UI traži od korisnika novi ključ.
  Set<AIProvider> get invalidProviders => Set.unmodifiable(_invalidProviders);

  /// Pozvati kad korisnik sačuva novi ključ.
  void resetProvider(AIProvider provider) {
    _invalidProviders.remove(provider);
    _unavailableModels.removeWhere((k) => k.startsWith('${provider.name}/'));
  }

  /// [parse] baca [FormatException] kada JSON ne odgovara šemi; tada se
  /// isti model pita još jednom, pa se ide dalje. Ostale greške iz
  /// [parse] (npr. "slika nije recept") prekidaju lanac i stižu do UI-a.
  Future<AIResult<T>> run<T>(
    AIRequest request,
    T Function(Map<String, dynamic> json) parse,
  ) async {
    final chain = config().chainFor(request.kind);
    final attempts = <AttemptLog>[];

    for (final m in chain) {
      if (_invalidProviders.contains(m.provider)) {
        attempts.add(AttemptLog(m, 'preskočen: ključ ne radi'));
        continue;
      }
      if (_unavailableModels.contains(m.key)) {
        attempts.add(AttemptLog(m, 'preskočen: model nije dostupan'));
        continue;
      }
      final key = await keys.read(m.provider);
      if (key == null || key.isEmpty) {
        attempts.add(AttemptLog(m, 'preskočen: nema ključa'));
        continue;
      }
      final blockedUntil = await status.blockedUntil(m);
      if (blockedUntil != null && blockedUntil.isAfter(_clock())) {
        attempts.add(AttemptLog(m, 'preskočen: pauziran do $blockedUntil'));
        continue;
      }

      try {
        final value = await _attempt(m, request, key, parse);
        attempts.add(AttemptLog(m, 'uspeh'));
        return AIResult(value, m, attempts);
      } on RateLimitError catch (e) {
        final until = _cooldownUntil(m, e);
        await status.block(m, until, e.message);
        attempts.add(AttemptLog(m, 'limit, pauza do $until'));
      } on AuthError catch (e) {
        _invalidProviders.add(m.provider);
        attempts.add(AttemptLog(m, 'ključ odbijen: ${e.message}'));
      } on ModelNotFoundError catch (e) {
        _unavailableModels.add(m.key);
        attempts.add(AttemptLog(m, 'model ne postoji: ${e.message}'));
      } on AIError catch (e) {
        attempts.add(AttemptLog(m, e.toString()));
      }
    }

    throw AllModelsExhausted(
      attempts,
      nextAvailableAt: await _earliestUnblock(chain),
    );
  }

  Future<T> _attempt<T>(
    ModelSpec m,
    AIRequest request,
    String key,
    T Function(Map<String, dynamic>) parse,
  ) async {
    for (var i = 0; ; i++) {
      await status.recordRequest(m, _clock());
      final raw = await client.complete(m, request, apiKey: key);
      try {
        return parse(decodeJsonObject(raw));
      } on FormatException catch (e) {
        if (i >= 1) throw InvalidOutputError(e.message);
        // JSON sa pogrešnim tipovima pada na cast-u u parse funkciji.
        // ignore: avoid_catching_errors
      } on TypeError catch (e) {
        if (i >= 1) throw InvalidOutputError(e.toString());
      }
    }
  }

  DateTime _cooldownUntil(ModelSpec m, RateLimitError e) {
    final now = _clock();
    if (e.retryAfter != null) return now.add(e.retryAfter!);
    if (!e.isDaily) return now.add(minuteCooldown);
    final hour = m.dailyResetUtcHour;
    if (hour == null) return now.add(unknownDailyCooldown);
    final utc = now.toUtc();
    var reset = DateTime.utc(utc.year, utc.month, utc.day, hour);
    if (!reset.isAfter(utc)) reset = reset.add(const Duration(days: 1));
    return reset.toLocal();
  }

  Future<DateTime?> _earliestUnblock(List<ModelSpec> chain) async {
    final now = _clock();
    DateTime? earliest;
    for (final m in chain) {
      if (_invalidProviders.contains(m.provider)) continue;
      if (_unavailableModels.contains(m.key)) continue;
      final until = await status.blockedUntil(m);
      if (until != null && until.isAfter(now)) {
        if (earliest == null || until.isBefore(earliest)) earliest = until;
      }
    }
    return earliest;
  }
}

/// Izvlači JSON objekat iz odgovora, i kad je umotan u ```json blok
/// ili okružen tekstom.
Map<String, dynamic> decodeJsonObject(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('Odgovor ne sadrži JSON objekat');
  }
  final decoded = jsonDecode(raw.substring(start, end + 1));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('JSON nije objekat');
  }
  return decoded;
}
