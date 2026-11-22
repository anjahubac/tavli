import 'ai_models.dart';
import 'key_store.dart';

/// Greške koje AI klijent baca. Router na osnovu tipa odlučuje
/// da li model pauzira, preskače provajdera ili ide dalje niz lanac.
sealed class AIError implements Exception {
  const AIError(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// HTTP 429: potrošen minutni ili dnevni limit.
class RateLimitError extends AIError {
  const RateLimitError(super.message, {this.retryAfter, this.isDaily = false});

  final Duration? retryAfter;
  final bool isDaily;
}

/// Ključ ne postoji ili nije važeći (401/403, Gemini vraća i 400).
class AuthError extends AIError {
  const AuthError(super.message);
}

/// Model više ne postoji ili nije dostupan na ovom nalogu (404).
class ModelNotFoundError extends AIError {
  const ModelNotFoundError(super.message);
}

/// Mreža, timeout ili 5xx.
class TransientError extends AIError {
  const TransientError(super.message, {this.isTimeout = false});

  /// Model nije odgovorio na vreme; ponovni pokušaj bi opet čekao isto.
  final bool isTimeout;
}

/// Odgovor ne odgovara očekivanoj JSON šemi.
class InvalidOutputError extends AIError {
  const InvalidOutputError(super.message, {this.repairFailed = false});

  /// Ni odgovor posle popravke nije prošao proveru; router tada staje
  /// umesto da ide kroz ceo lanac (FR-003).
  final bool repairFailed;
}

/// Ostale 4xx greške (npr. model ne podržava neki parametar).
class BadRequestError extends AIError {
  const BadRequestError(super.message);
}

class GatewayAuthError extends AIError {
  const GatewayAuthError() : super('Sesija je istekla. Prijavi se ponovo.');
}

class GatewayQuotaError extends AIError {
  const GatewayQuotaError(this.retryAfter, {this.kind})
    : super('Limit je trenutno potrošen. Pokušaj malo kasnije.');

  final Duration retryAfter;
  final TaskKind? kind;
}

class GatewayUnavailableError extends AIError {
  const GatewayUnavailableError() : super('AI trenutno nije dostupan.');
}

class GatewayRequestRejected extends AIError {
  const GatewayRequestRejected() : super('Zahtev nije uspeo. Pokušaj ponovo.');
}

class AttemptLog {
  const AttemptLog(this.model, this.outcome, {this.origin = KeyOrigin.user});

  final ModelSpec model;
  final String outcome;

  /// Kojim ključem je pokušano.
  final KeyOrigin origin;

  @override
  String toString() => '$model (${origin.name}): $outcome';
}

class AllModelsExhausted implements Exception {
  const AllModelsExhausted(
    this.attempts, {
    this.nextAvailableAt,
    this.invalidOutput = false,
    this.repairFailed = false,
    this.emptyOutput = false,
  });

  final List<AttemptLog> attempts;

  /// Najraniji trenutak kada neki pauziran model ponovo postaje dostupan.
  final DateTime? nextAvailableAt;

  /// Bar jedan model je odgovorio, ali odgovor nije prošao proveru
  /// (ili je model preskočen jer je nedavno tako odgovorio).
  final bool invalidOutput;

  /// Ni odgovor posle popravke nije prošao; lanac je tu stao. Tada je
  /// [nextAvailableAt] null ako „Pokušaj ponovo“ odmah ima koga da pita.
  final bool repairFailed;

  /// Bar jedan model je vratio prazan odgovor (bez popravke).
  final bool emptyOutput;

  @override
  String toString() =>
      'AllModelsExhausted(next: $nextAvailableAt, attempts: $attempts)';
}
