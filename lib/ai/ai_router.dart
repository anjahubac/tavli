import 'dart:convert';

import 'ai_errors.dart';
import 'ai_models.dart';
import 'chain_config.dart';
import 'chat_client.dart';
import 'key_store.dart';
import 'model_status_store.dart';
import 'repair_prompt.dart';

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
    this.invalidOutputCooldown = const Duration(minutes: 10),
  }) : _clock = clock ?? DateTime.now;

  /// Funkcija, ne vrednost: korisnik može da promeni lanac dok app radi.
  final ChainConfig Function() config;
  final ChatClient client;
  final KeySource keys;
  final ModelStatusStore status;
  final DateTime Function() _clock;
  final Duration minuteCooldown;
  final Duration unknownDailyCooldown;

  /// Koliko se preskače model čiji ni popravljen odgovor nije prošao, da
  /// „Pokušaj ponovo“ pita sledeći model umesto istog. Samo u memoriji.
  final Duration invalidOutputCooldown;

  final _invalidKeys = <String>{};
  final _unavailableModels = <String>{};
  final _invalidOutputUntil = <String, DateTime>{};

  static String _keySlot(ApiCredential c) => '${c.provider.name}#${c.slot}';
  static String _modelSlot(ModelSpec m, ApiCredential c) =>
      '${m.key}#${c.slot}';

  /// Id-jevi *sopstvenih* ključeva koje je servis odbio; UI ih označava.
  /// Odbijen ugrađeni ključ se tiho preskače.
  Set<String> get invalidKeyIds => Set.unmodifiable(_invalidOwnKeyIds);
  final _invalidOwnKeyIds = <String>{};

  /// Pozvati kad provera pokaže da ključ opet radi.
  void resetKey(String keyId) {
    _invalidOwnKeyIds.remove(keyId);
    _invalidKeys.removeWhere((k) => k.endsWith('#user:$keyId'));
    _unavailableModels.removeWhere((k) => k.endsWith('#user:$keyId'));
  }

  /// [parse] baca [FormatException] kada JSON ne odgovara šemi; tada isti
  /// model jednom dobija svoj odgovor i opis greške da ga popravi. Ako ni
  /// popravka ne prođe, lanac staje (korisnik vidi poruku i „Pokušaj
  /// ponovo“), a taj model se kratko preskače. Ostale greške iz [parse]
  /// (npr. "slika nije recept") prekidaju lanac i stižu do UI-a.
  Future<AIResult<T>> run<T>(
    AIRequest request,
    T Function(Map<String, dynamic> json) parse,
  ) async {
    final chain = config().chainFor(request.kind);
    final attempts = <AttemptLog>[];
    var invalidOutput = false;

    for (final m in chain) {
      final credentials = await keys.credentialsFor(m.provider);
      if (credentials.isEmpty) {
        attempts.add(AttemptLog(m, 'preskočen: nema ključa'));
        continue;
      }
      for (final c in credentials) {
        void log(String outcome) =>
            attempts.add(AttemptLog(m, outcome, origin: c.origin));

        if (_invalidKeys.contains(_keySlot(c))) {
          log('preskočen: ključ ne radi');
          continue;
        }
        if (_unavailableModels.contains(_modelSlot(m, c))) {
          log('preskočen: model nije dostupan');
          continue;
        }
        final blockedUntil = await status.blockedUntil(
          m,
          origin: c.origin,
          keyId: c.keyId,
        );
        if (blockedUntil != null && blockedUntil.isAfter(_clock())) {
          log('preskočen: pauziran do $blockedUntil');
          continue;
        }
        final invalidUntil = _invalidOutputUntil[_modelSlot(m, c)];
        if (invalidUntil != null && invalidUntil.isAfter(_clock())) {
          invalidOutput = true;
          log('preskočen: neispravan odgovor, pauza do $invalidUntil');
          continue;
        }

        try {
          final value = await _attempt(m, request, c, parse);
          log('uspeh');
          return AIResult(value, m, attempts, origin: c.origin);
        } on RateLimitError catch (e) {
          final until = _cooldownUntil(m, e);
          await status.block(
            m,
            until,
            e.message,
            origin: c.origin,
            keyId: c.keyId,
          );
          log('limit, pauza do $until');
        } on AuthError catch (e) {
          _invalidKeys.add(_keySlot(c));
          if (c.origin == KeyOrigin.user && c.keyId != null) {
            _invalidOwnKeyIds.add(c.keyId!);
          }
          log('ključ odbijen: ${e.message}');
        } on ModelNotFoundError catch (e) {
          _unavailableModels.add(_modelSlot(m, c));
          log('model ne postoji: ${e.message}');
        } on AIError catch (e) {
          if (e is InvalidOutputError && e.repairFailed) {
            final until = _clock().add(invalidOutputCooldown);
            _invalidOutputUntil[_modelSlot(m, c)] = until;
            log('neispravan odgovor i posle popravke: ${e.message}');
            // Drugi neuspeh: poruka korisniku, bez prolaska kroz ceo lanac.
            throw AllModelsExhausted(attempts, invalidOutput: true);
          }
          // Prazan odgovor (bez popravke) ide na sledeći model kao i ranije.
          if (e is InvalidOutputError) invalidOutput = true;
          // Mreža ili loš odgovor ne zavise od ključa: odmah sledeći model.
          log(e.toString());
          break;
        }
      }
    }

    throw AllModelsExhausted(
      attempts,
      nextAvailableAt: await _earliestUnblock(chain),
      invalidOutput: invalidOutput,
    );
  }

  Future<T> _attempt<T>(
    ModelSpec m,
    AIRequest request,
    ApiCredential credential,
    T Function(Map<String, dynamic>) parse,
  ) async {
    Future<String> send(AIRequest r) async {
      await status.recordRequest(
        m,
        _clock(),
        origin: credential.origin,
        keyId: credential.keyId,
      );
      return client.complete(m, r, apiKey: credential.value);
    }

    final raw = await send(request);
    final Object problem;
    try {
      return parse(decodeJsonObject(raw));
    } on FormatException catch (e) {
      problem = e;
      // JSON sa pogrešnim tipovima pada na cast-u u parse funkciji.
      // ignore: avoid_catching_errors
    } on TypeError catch (e) {
      problem = e;
    }

    // Jedna popravka: isti model dobija svoj odgovor i opis greške.
    final fixed = await send(
      repairRequest(request, raw, repairProblem(problem)),
    );
    try {
      return parse(decodeJsonObject(fixed));
    } on FormatException catch (e) {
      throw InvalidOutputError(e.message, repairFailed: true);
      // Isto kao gore: pogrešan tip polja posle popravke.
      // ignore: avoid_catching_errors
    } on TypeError catch (e) {
      throw InvalidOutputError(e.toString(), repairFailed: true);
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
        if (_invalidKeys.contains(_keySlot(c))) continue;
        if (_unavailableModels.contains(_modelSlot(m, c))) continue;
        final until = await status.blockedUntil(
          m,
          origin: c.origin,
          keyId: c.keyId,
        );
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
