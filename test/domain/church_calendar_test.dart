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
