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
  const TransientError(super.message);
}

/// Odgovor ne odgovara očekivanoj JSON šemi.
class InvalidOutputError extends AIError {
  const InvalidOutputError(super.message);
}

/// Ostale 4xx greške (npr. model ne podržava neki parametar).
class BadRequestError extends AIError {
  const BadRequestError(super.message);
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
  const AllModelsExhausted(this.attempts, {this.nextAvailableAt});

  final List<AttemptLog> attempts;

  /// Najraniji trenutak kada neki pauziran model ponovo postaje dostupan.
  final DateTime? nextAvailableAt;

  @override
  String toString() =>
      'AllModelsExhausted(next: $nextAvailableAt, attempts: $attempts)';
}
