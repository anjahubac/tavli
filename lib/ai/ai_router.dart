import 'dart:convert';

import 'ai_errors.dart';
import 'ai_models.dart';
import 'chain_config.dart';
import 'chat_client.dart';
import 'key_store.dart';
import 'model_status_store.dart';

class AIResult<T> {
  const AIResult(
    this.value,
    this.model,
    this.attempts, {
    this.origin = KeyOrigin.user,
  });

  final T value;

  /// Model koji je dao odgovor (prikazuje se kao "Odgovorio: …").
  final ModelSpec model;
  final List<AttemptLog> attempts;

  /// Ključ koji je dao odgovor (sopstveni ili ugrađeni Tavli AI).
  final KeyOrigin origin;
}

/// Prolazi kroz lanac modela dok neki ne vrati ispravan odgovor.
/// Za svaki model proba ključeve redom iz [KeySource] (sopstveni pa ugrađeni);
/// pauze, odbijeni ključevi i nedostupni modeli važe posebno po ključu.
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
  final KeySource keys;
  final ModelStatusStore status;
  final DateTime Function() _clock;
  final Duration minuteCooldown;
  final Duration unknownDailyCooldown;

  final _invalidKeys = <String>{};
  final _unavailableModels = <String>{};

  static String _keySlot(AIProvider p, KeyOrigin o) => '${p.name}#${o.name}';
  static String _modelSlot(ModelSpec m, KeyOrigin o) => '${m.key}#${o.name}';

  /// Provajderi čiji je *sopstveni* ključ odbijen; UI traži novi ključ.
  /// Odbijen ugrađeni ključ se tiho preskače.
  Set<AIProvider> get invalidProviders => {
    for (final p in AIProvider.values)
      if (_invalidKeys.contains(_keySlot(p, KeyOrigin.user))) p,
  };

  /// Pozvati kad korisnik sačuva novi ključ.
  void resetProvider(AIProvider provider) {
    _invalidKeys.remove(_keySlot(provider, KeyOrigin.user));
    _unavailableModels.removeWhere(
      (k) => k.startsWith('${provider.name}/') && k.endsWith('#user'),
    );
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
      final credentials = await keys.credentialsFor(m.provider);
      if (credentials.isEmpty) {
        attempts.add(AttemptLog(m, 'preskočen: nema ključa'));
        continue;
      }
      for (final c in credentials) {
        void log(String outcome) =>
            attempts.add(AttemptLog(m, outcome, origin: c.origin));

        if (_invalidKeys.contains(_keySlot(m.provider, c.origin))) {
          log('preskočen: ključ ne radi');
          continue;
        }
        if (_unavailableModels.contains(_modelSlot(m, c.origin))) {
          log('preskočen: model nije dostupan');
          continue;
        }
        final blockedUntil = await status.blockedUntil(m, origin: c.origin);
        if (blockedUntil != null && blockedUntil.isAfter(_clock())) {
          log('preskočen: pauziran do $blockedUntil');
          continue;
        }

        try {
          final value = await _attempt(m, request, c, parse);
          log('uspeh');
          return AIResult(value, m, attempts, origin: c.origin);
        } on RateLimitError catch (e) {
          final until = _cooldownUntil(m, e);
          await status.block(m, until, e.message, origin: c.origin);
          log('limit, pauza do $until');
        } on AuthError catch (e) {
          _invalidKeys.add(_keySlot(m.provider, c.origin));
          log('ključ odbijen: ${e.message}');
        } on ModelNotFoundError catch (e) {
          _unavailableModels.add(_modelSlot(m, c.origin));
          log('model ne postoji: ${e.message}');
        } on AIError catch (e) {
          // Mreža ili loš odgovor ne zavise od ključa: odmah sledeći model.
          log(e.toString());
          break;
        }
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
    ApiCredential credential,
    T Function(Map<String, dynamic>) parse,
  ) async {
    for (var i = 0; ; i++) {
      await status.recordRequest(m, _clock(), origin: credential.origin);
      final raw = await client.complete(m, request, apiKey: credential.value);
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
      for (final c in await keys.credentialsFor(m.provider)) {
        if (_invalidKeys.contains(_keySlot(m.provider, c.origin))) continue;
        if (_unavailableModels.contains(_modelSlot(m, c.origin))) continue;
        final until = await status.blockedUntil(m, origin: c.origin);
        if (until != null && until.isAfter(now)) {
          if (earliest == null || until.isBefore(earliest)) earliest = until;
        }
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
