import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/step_duration.dart';

void main() {
  const cases = <String, Duration?>{
    'Kuvaj testeninu 8 minuta.': Duration(minutes: 8),
    'Peci 20 min na 180 stepeni.': Duration(minutes: 20),
    'Kuvaj 1 minut.': Duration(minutes: 1),
    'Ostavi da odstoji 1 sat i 30 minuta.': Duration(minutes: 90),
    'Krčkaj 1,5 sata.': Duration(minutes: 90),
    'Peci 10-15 minuta.': Duration(minutes: 15),
    'Prži 30 sekundi sa svake strane.': Duration(seconds: 30),
    'Ogulite krompir.': null,
    'Dodaj 2 kašike ulja i 500 g mesa.': null,
    'Dodaj 2 minute soli.': Duration(minutes: 2),
    'Peci 3 minutarno': null,
    'Ostavi 99 sati.': null,
  };
  for (final MapEntry(key: text, value: expected) in cases.entries) {
    test('"$text" → $expected', () {
      expect(stepDuration(text), expected);
    });
  }
}
