/// Popravka odgovora koji nije prošao proveru (spec 014 FR-003, TRELLO-42).
///
/// Router jednom šalje istom modelu prvobitni zahtev, njegov odgovor i
/// opis greške, pa model vraća ispravljen JSON. Zahtev ostaje istog oblika
/// (`system`, `prompt`, slike), pa radi i preko budućeg AI servera.
library;

import 'ai_models.dart';

/// Opis pravila iz ugovora 014 za koje validator baca samo oznaku (`R2`…).
const _ruleHints = {
  'R1': '"title" must be a string of 1–120 characters.',
  'R2': '"servings" must be an integer from 1 to 99 and is always present.',
  'R4': '"ingredients" must be a list of 1–60 objects.',
  'R5': 'every ingredient needs a "name" of 1–80 characters.',
  'R6':
      'every "quantity" must be a number from 0.001 to 100000, or null '
      '"po ukusu"; never text such as "1/2" and never 0.',
  'R7': '"unit" must be a string of up to 30 characters, or null.',
  'R9': '"note" must be a string of up to 200 characters, or null.',
  'R10':
      '"steps" must be a list of up to 40 strings of up to 1000 characters; '
      'when the recipe had steps, keep them instead of returning none.',
  'S2': 'every recipe "servings" must be an integer from 1 to 20.',
};

/// Najduži deo poruke parsera (npr. mesto u planu) koji ide u opis.
const _maxDetailLength = 200;

/// Najduži prethodni odgovor koji se vraća modelu. Duži se izostavlja, jer
/// bi odsečen JSON zbunio model; tada ide samo opis greške.
const maxRepairEchoLength = 12000;

/// Opis greške za model: oznaka pravila postaje rečenica, ostale poruke
/// parsera idu kakve jesu, uz kratak detalj (npr. mesto koje fali).
String repairProblem(Object error) {
  if (error is FormatException) {
    final hint = _ruleHints[error.message];
    if (hint != null) return hint;
    final source = error.source;
    final detail = source is String && source.length <= _maxDetailLength
        ? ' ($source)'
        : '';
    return '${error.message}$detail';
  }
  return 'a field has the wrong type.';
}

/// Zahtev za popravku: isti sistemski upit i slike, a upit dobija
/// prethodni odgovor i opis greške.
AIRequest repairRequest(AIRequest original, String previous, String problem) {
  final echo = previous.length <= maxRepairEchoLength
      ? '\nYour previous answer:\n$previous\n'
      : '';
  return AIRequest(
    system: original.system,
    prompt:
        '''
${original.prompt}

Your previous answer was rejected by the app's validator.
Problem: $problem
$echo
Return the complete corrected JSON object only, following the schema exactly.
Keep everything that was already correct.''',
    images: original.images,
    temperature: original.temperature,
  );
}
