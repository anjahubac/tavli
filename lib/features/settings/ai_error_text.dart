import '../../ai/ai_errors.dart';
import '../../ai/recipe_ai.dart';

/// Poruka za korisnika umesto tehničke greške.
String aiErrorText(Object error) => switch (error) {
  AuthError() => 'Ključ nije ispravan ili je opozvan.',
  RateLimitError() => 'Limit je trenutno potrošen. Pokušaj malo kasnije.',
  TransientError() => 'Nema veze sa serverom. Proveri internet.',
  ModelNotFoundError() => 'Model nije dostupan za ovaj ključ.',
  InvalidOutputError() => 'AI je vratio neispravan odgovor.',
  BadRequestError(:final message) => 'Zahtev odbijen: $message',
  AllModelsExhausted(:final nextAvailableAt?) =>
    'Svi besplatni limiti su potrošeni. Pokušaj ponovo posle '
        '${_hhmm(nextAvailableAt.toLocal())}.',
  // Modeli su odgovorili, ali nijedan odgovor nije prošao proveru.
  AllModelsExhausted(invalidOutput: true) => 'AI je vratio neispravan odgovor.',
  AllModelsExhausted() => 'Nijedan model nije dostupan. Proveri ključeve.',
  NotARecipeException() => 'Na slici nije pronađen recept.',
  _ => 'Nešto nije u redu: $error',
};

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
