import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/church_calendar.dart';

void main() {
  test('Julian computus matches the civil Pascha fixtures', () {
    expect(ChurchCalendar.easter(2026), DateTime.utc(2026, 4, 12));
    expect(ChurchCalendar.easter(2027), DateTime.utc(2027, 5, 2));
    expect(ChurchCalendar.easter(2028), DateTime.utc(2028, 4, 16));
  });

  test('Nativity fast spans two civil years and ends on a water day', () {
    final calendar = ChurchCalendar(DateTime(2026, 11, 12));
    expect(calendar.status, 'Danas mrsno · Božićni post od 28. novembra');
    expect(
      calendar.answer('Kada počinje Božićni post?')?.text,
      'Božićni post traje od 28. novembra 2026. do 6. januara 2027.',
    );
    expect(ChurchCalendar.rule(DateTime.utc(2027, 1, 6)), 'na vodi');
    expect(ChurchCalendar.rule(DateTime.utc(2027, 1, 7)), 'mrsno');
  });

  group('krsne slave', () {
    final calendar = ChurchCalendar(DateTime(2026, 11, 12));
    String? ask(String q) => calendar.answer(q)?.text;

    test('common forms of a question find the slava', () {
      const nikoljdan =
          'Sveti Nikolaj Mirlikijski Čudotvorac (Nikoljdan) je 19. decembra.';
      expect(ask('Kad je slava Sveti Nikola?'), nikoljdan);
      expect(ask('Kada je Nikoljdan?'), nikoljdan);
      expect(ask('Kada slavimo Svetog Nikolu?'), nikoljdan);
      expect(ask('Sveti Nikola datum'), nikoljdan);
      expect(ask('Kada je Đurđevdan'), endsWith('je 6. maja.'));
      expect(ask('Kada je Aranđelovdan?'), endsWith('je 21. novembra.'));
      expect(
        calendar.answer('Kada je Mitrovdan?')?.source,
        ChurchCalendar.slavaSource,
      );
      // Lazareva subota is computed from Pascha, not read from the lists.
      expect(
        calendar.answer('Kada je Lazareva subota?')?.source,
        ChurchCalendar.source,
      );
    });

    test('people and unlisted saints get no slava date', () {
      expect(ask('Kada je rođen Nikola Tesla?'), isNull);
      expect(ask('Kada je Marina rođena?'), isNull);
      expect(ask('Kada je Sveti Jovan Vladimir?'), isNull);
      expect(ask('Kada je Sveti Nikola Tavelić?'), isNull);
      expect(
        ChurchCalendar.isCalendarQuestion('Kada je Sveti Jovan Vladimir?'),
        isTrue,
      );
    });

    test('saints that share a name get their own date', () {
      expect(ask('Kada je Jovanjdan?'), endsWith('je 20. januara.'));
      expect(
        ask('Kada je Sveti Jovan Zlatousti?'),
        endsWith('je 26. novembra.'),
      );
      expect(
        ask('Kada je Usekovanje glave Svetog Jovana?'),
        endsWith('je 11. septembra.'),
      );
      expect(ask('Kada je Ivanjdan?'), endsWith('je 7. jula.'));
      expect(ask('Kada je Letnji Nikola?'), endsWith('je 22. maja.'));
      expect(ask('Kada je Sveta Petka?'), endsWith('je 27. oktobra.'));
      expect(ask('Kada je letnja Sveta Petka?'), endsWith('je 8. avgusta.'));
      expect(
        ask('Kada je Sveti Simeon Mirotočivi?'),
        endsWith('je 26. februara.'),
      );
      expect(ask('Kada je Sveti Simeon i Ana?'), endsWith('je 16. februara.'));
      expect(ask('Kada je Sveti arhangel Gavrilo?'), endsWith('je 26. jula.'));
      expect(ask('Kada su Časne verige?'), endsWith('je 29. januara.'));
      expect(ask('Kada je Mratindan?'), endsWith('je 24. novembra.'));
    });

    test('a fixed slava has no year; Lazareva subota moves with Pascha', () {
      expect(
        ask('Kada je Sveti Sava?'),
        'Sveti Sava (Savindan) je 27. januara.',
      );
      expect(
        ask('Kada je Sveti Sava 2027?'),
        'Sveti Sava (Savindan) je 27. januara.',
      );
      expect(ask('Kada je Lazareva subota?'), contains('24. aprila 2027.'));
      expect(ask('Kada je Lazareva subota 2026?'), contains('4. aprila 2026.'));
    });

    test('food, fasting and other feasts keep their own path', () {
      expect(ask('Recept za slavski kolač za Svetog Nikolu'), isNull);
      expect(
        ask('Kada počinje Božićni post?'),
        'Božićni post traje od 28. novembra 2026. do 6. januara 2027.',
      );
      expect(ask('Kada je Vaskrs 2027?'), 'Vaskrs je 2. maja 2027.');
      expect(ChurchCalendar.isCalendarQuestion('Koja je naša slava?'), isTrue);
      expect(ask('Koja je naša slava?'), isNull);
    });
  });

  test('unknown holidays and unsupported years do not invent a date', () {
    final calendar = ChurchCalendar(DateTime(2026, 11, 12));
    expect(calendar.answer('Kada je nepoznati praznik?'), isNull);
    expect(calendar.answer('Kada je Vaskrs 2150?'), isNull);
    expect(
      calendar.answer('Da li je sutra posno?')?.text,
      contains('13. novembra 2026.'),
    );
  });
}
