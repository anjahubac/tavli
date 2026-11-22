import '../../ai/ai_errors.dart';
import '../../ai/recipe_ai.dart';

/// Poruka za korisnika umesto tehničke greške.
String aiErrorText(Object error) => switch (error) {
  AuthError() => 'Ključ nije ispravan ili je opozvan.',
  RateLimitError() => 'Limit je trenutno potrošen. Pokušaj malo kasnije.',
  GatewayAuthError(:final message) => message,
  GatewayQuotaError(:final message) => message,
  GatewayUnavailableError(:final message) => message,
  GatewayRequestRejected(:final message) => message,
  TransientError() => 'Nema veze sa serverom. Proveri internet.',
  ModelNotFoundError() => 'Model nije dostupan za ovaj ključ.',
  InvalidOutputError() => 'AI je vratio neispravan odgovor.',
  BadRequestError(:final message) => 'Zahtev odbijen: $message',
  // Ni popravljen odgovor nije prošao. Vreme samo kad „Pokušaj ponovo“
  // sada nema koji model da pita.
  AllModelsExhausted(repairFailed: true, :final nextAvailableAt) =>
    'AI nije vratio ispravan odgovor ni posle ispravke. '
        '${_retry(nextAvailableAt)}',
  // Modeli koji su nedavno vratili neispravan odgovor su preskočeni.
  AllModelsExhausted(invalidOutput: true, :final nextAvailableAt?) =>
    'AI je nedavno vratio neispravan odgovor. ${_retry(nextAvailableAt)}',
  AllModelsExhausted(emptyOutput: true, nextAvailableAt: null) =>
    'AI nije vratio odgovor. Pokušaj ponovo.',
  AllModelsExhausted(:final nextAvailableAt?) =>
    'Svi besplatni limiti su potrošeni. Pokušaj ponovo posle '
        '${_hhmm(nextAvailableAt.toLocal())}.',
  AllModelsExhausted() => 'Nijedan model nije dostupan. Proveri ključeve.',
  NotARecipeException() => 'Na slici nije pronađen recept.',
  _ => 'Nešto nije u redu: $error',
};

String _retry(DateTime? at) => at == null
    ? 'Pokušaj ponovo.'
    : 'Pokušaj ponovo posle ${_hhmm(at.toLocal())}.';

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
