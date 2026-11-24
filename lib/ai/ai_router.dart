import 'dart:async';
import 'dart:convert';

import 'ai_errors.dart';
import 'ai_models.dart';
import 'chain_config.dart';
import 'chat_client.dart';
import 'gateway_chat_client.dart';
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

  /// Pristup koji je dao odgovor (sopstveni ključ ili zajednički Tavli AI).
  final KeyOrigin origin;
}

/// Prolazi kroz lanac modela dok neki ne vrati ispravan odgovor.
/// Prvo korisnikovi ključevi iz [KeySource], plaćeni ili besplatni servisi
/// prvi prema [ownKeyOrder], pa zajednički pristup preko [gateway];
/// pauze, odbijeni ključevi i nedostupni modeli važe posebno po ključu.
class AIRouter {
  AIRouter({
    required this.config,
    required this.client,
    required this.keys,
    required this.status,
    this.gateway,
    this.ownKeyOrder = _paidFirst,
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
  final GatewayChatClient? gateway;

  /// Čeka se pre svakog zahteva: izbor „Prvo besplatni“ mora da važi i za
  /// prvi zahtev po pokretanju, dok se podešavanje još čita iz baze.
  final FutureOr<OwnKeyOrder> Function() ownKeyOrder;
  final _gatewayPauses = <(String, TaskKind?), DateTime>{};
  final DateTime Function() _clock;
  final Duration minuteCooldown;
  final Duration unknownDailyCooldown;

  /// Koliko se preskače model čiji ni popravljen odgovor nije prošao, da
  /// „Pokušaj ponovo“ pita sledeći model umesto istog. Samo u memoriji.
  final Duration invalidOutputCooldown;

  final _invalidKeys = <String>{};
  final _unavailableModels = <String>{};
  final _invalidOutputUntil = <String, DateTime>{};

  static OwnKeyOrder _paidFirst() => OwnKeyOrder.paidFirst;

  /// Plaćeni servisi na početak ili na kraj; redosled unutar grupe ostaje.
  static List<ModelSpec> _ordered(List<ModelSpec> chain, OwnKeyOrder order) {
    final paid = chain.where((m) => m.provider.paid);
    final free = chain.where((m) => !m.provider.paid);
    return switch (order) {
      OwnKeyOrder.paidFirst => [...paid, ...free],
      OwnKeyOrder.freeFirst => [...free, ...paid],
    };
  }

  static String _keySlot(ApiCredential c) => '${c.provider.name}#${c.slot}';
  static String _modelSlot(ModelSpec m, ApiCredential c) =>
      '${m.key}#${c.slot}';

  /// Id-jevi *sopstvenih* ključeva koje je servis odbio; UI ih označava.
  /// Odbijen zajednički pristup se tiho preskače.
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
  ///
  /// Kad je [cancel] prekinut, router baca [AICancelled] pre sledećeg
  /// poziva modela, pa ni popravka ne kreće posle „Prekini“.
  Future<AIResult<T>> run<T>(
    AIRequest request,
    T Function(Map<String, dynamic> json) parse, {
    AICancellation? cancel,
  }) async {
    final configured = config().chainFor(request.kind);
    final gatewayClient = gateway;
    final session = gatewayClient == null
        ? null
        : _GatewayRun(gatewayClient, cancel);
    final directChain = _ordered(configured, await ownKeyOrder());
    final attempts = <AttemptLog>[];
    var invalidOutput = false;
    var emptyOutput = false;
    AIError? gatewayError;
    var sharedChain = <ModelSpec>[];

    for (final shared in [
      false,
      if (session?.accountId != null && request.task != null) true,
    ]) {
      var chain = directChain;
      if (shared) {
        final account = session!.accountId!;
        final pause = _gatewayPause(account, request.kind);
        if (pause != null) throw GatewayQuotaError(pause.difference(_clock()));
        try {
          sharedChain = await session.call(
            () => gatewayClient!.models(request.kind),
          );
        } on AIError catch (error) {
          gatewayError = error;
          break;
        }
        chain = sharedChain;
      }
      for (final m in chain) {
        final credentials = shared
            ? [ApiCredential.gateway(m.provider)]
            : await keys.credentialsFor(m.provider);
        session?.checkActive();
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
            final value = await _attempt(m, request, c, parse, cancel, session);
            log('uspeh');
            return AIResult(value, m, attempts, origin: c.origin);
          } on GatewayQuotaError catch (e) {
            final slot = (session!.accountId!, e.kind);
            final until = _clock().add(e.retryAfter);
            final current = _gatewayPauses[slot];
            if (current == null || until.isAfter(current)) {
              _gatewayPauses[slot] = until;
            }
            rethrow;
          } on GatewayAuthError {
            rethrow;
          } on GatewayUnavailableError {
            rethrow;
          } on GatewayRequestRejected {
            rethrow;
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
              // Vreme samo kad „Pokušaj ponovo“ sada nema koga da pita.
              throw AllModelsExhausted(
                attempts,
                nextAvailableAt: await _nextAvailable(
                  chain,
                  shared: shared,
                  nullIfUsable: true,
                ),
                invalidOutput: true,
                repairFailed: true,
              );
            }
            // Prazan odgovor (bez popravke) ide na sledeći model kao i ranije.
            if (e is InvalidOutputError) emptyOutput = true;
            // Mreža ili loš odgovor ne zavise od ključa: odmah sledeći model.
            log(e.toString());
            break;
          }
        }
      }
    }

    session?.checkActive();
    if (gatewayError != null) throw gatewayError;
    final directAvailable = await _nextAvailable(directChain);
    final sharedAvailable = await _nextAvailable(sharedChain, shared: true);
    session?.checkActive();
    throw AllModelsExhausted(
      attempts,
      nextAvailableAt: switch ((directAvailable, sharedAvailable)) {
        (final a?, final b?) => a.isBefore(b) ? a : b,
        _ => directAvailable ?? sharedAvailable,
      },
      invalidOutput: invalidOutput,
      emptyOutput: emptyOutput,
    );
  }

  DateTime? _gatewayPause(String account, TaskKind kind) {
    final now = _clock();
    _gatewayPauses.removeWhere((_, until) => !until.isAfter(now));
    final all = _gatewayPauses[(account, null)];
    final scoped = _gatewayPauses[(account, kind)];
    if (all == null || (scoped != null && scoped.isAfter(all))) return scoped;
    return all;
  }

  Future<T> _attempt<T>(
    ModelSpec m,
    AIRequest request,
    ApiCredential credential,
    T Function(Map<String, dynamic>) parse,
    AICancellation? cancel,
    _GatewayRun? session,
  ) async {
    Future<String> send(AIRequest r) async {
      if (cancel?.isCancelled ?? false) throw const AICancelled();
      session?.checkActive();
      await status.recordRequest(
        m,
        _clock(),
        origin: credential.origin,
        keyId: credential.keyId,
      );
      session?.checkActive();
      final key = credential.value;
      if (key == null) {
        return session!.call(() => session.gateway.complete(m, r));
      }
      return client.complete(m, r, apiKey: key);
    }

    final raw = await send(request);
    // Odgovor stigao posle „Prekini“: ne čita se i ne popravlja.
    if (cancel?.isCancelled ?? false) throw const AICancelled();
    session?.checkActive();
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
    if (cancel?.isCancelled ?? false) throw const AICancelled();
    session?.checkActive();
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

  /// Najraniji trenutak kada neki pauziran model (limit ili neispravan
  /// odgovor) ponovo može da se pita. Sa [nullIfUsable] vraća null čim
  /// postoji model koji može odmah, jer tada „Pokušaj ponovo“ radi odmah.
  Future<DateTime?> _nextAvailable(
    List<ModelSpec> chain, {
    bool shared = false,
    bool nullIfUsable = false,
  }) async {
    final now = _clock();
    DateTime? earliest;
    for (final m in chain) {
      for (final c
          in shared
              ? [ApiCredential.gateway(m.provider)]
              : await keys.credentialsFor(m.provider)) {
        if (_invalidKeys.contains(_keySlot(c))) continue;
        if (_unavailableModels.contains(_modelSlot(m, c))) continue;
        final blocked = await status.blockedUntil(
          m,
          origin: c.origin,
          keyId: c.keyId,
        );
        final invalid = _invalidOutputUntil[_modelSlot(m, c)];
        DateTime? until;
        for (final t in [blocked, invalid]) {
          if (t != null &&
              t.isAfter(now) &&
              (until == null || t.isAfter(until))) {
            until = t;
          }
        }
        if (until == null) {
          if (nullIfUsable) return null;
          continue;
        }
        if (earliest == null || until.isBefore(earliest)) earliest = until;
      }
    }
    return earliest;
  }
}

class _GatewayRun {
  _GatewayRun(this.gateway, this.cancel) : accountId = gateway.accountId();

  final GatewayChatClient gateway;
  final AICancellation? cancel;
  final String? accountId;
  bool _refreshed = false;

  void checkActive() {
    if ((cancel?.isCancelled ?? false) || gateway.accountId() != accountId) {
      throw const AICancelled();
    }
  }

  Future<T> call<T>(Future<T> Function() send) async {
    checkActive();
    try {
      return await send();
    } on GatewayAuthError {
      checkActive();
      if (_refreshed) rethrow;
      _refreshed = true;
      final renewed = await gateway.refresh();
      checkActive();
      if (!renewed) rethrow;
      return await send();
    } finally {
      checkActive();
    }
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
