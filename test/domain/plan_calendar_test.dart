import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/plan_calendar.dart';

CivilDate d(int y, int m, int day) => CivilDate(y, m, day);

void main() {
  group('CivilDate', () {
    test('odbija nepostojeći datum', () {
      expect(() => CivilDate(2026, 2, 29), throwsArgumentError);
      expect(() => CivilDate(2026, 13, 1), throwsArgumentError);
      expect(CivilDate(2028, 2, 29).day, 29);
    });

    test('poređenje i jednakost po kalendarskim poljima', () {
      expect(d(2026, 11, 2), d(2026, 11, 2));
      expect(d(2026, 11, 2).hashCode, d(2026, 11, 2).hashCode);
      expect(d(2026, 11, 2).compareTo(d(2026, 11, 3)), lessThan(0));
      expect(d(2026, 12, 31).isBefore(d(2027, 1, 1)), isTrue);
      expect(d(2027, 1, 1).isAfter(d(2026, 12, 31)), isTrue);
    });

    test('dodavanje dana prelazi mesec, godinu i prestupni dan', () {
      expect(d(2026, 11, 30).addDays(1), d(2026, 12, 1));
      expect(d(2026, 12, 31).addDays(1), d(2027, 1, 1));
      expect(d(2028, 2, 28).addDays(1), d(2028, 2, 29));
      expect(d(2028, 3, 1).addDays(-1), d(2028, 2, 29));
      expect(d(2026, 3, 1).addDays(-1), d(2026, 2, 28));
    });

    test('prelazak na letnje računanje vremena ne gubi ni ponavlja dan', () {
      // U Srbiji se sat pomera 29.3.2026. i 25.10.2026.
      expect(d(2026, 3, 28).addDays(1), d(2026, 3, 29));
      expect(d(2026, 3, 29).addDays(1), d(2026, 3, 30));
      expect(d(2026, 10, 25).addDays(1), d(2026, 10, 26));
      expect(d(2026, 10, 24).daysUntil(d(2026, 10, 27)), 3);
    });

    test('dan u nedelji: ponedeljak je 1, nedelja 7', () {
      expect(d(2026, 11, 2).weekday, DateTime.monday);
      expect(d(2026, 11, 8).weekday, DateTime.sunday);
    });

    test('iz lokalnog vremena uzima samo kalendarska polja', () {
      expect(
        CivilDate.fromDateTime(DateTime(2026, 11, 2, 23, 59)),
        d(2026, 11, 2),
      );
      expect(
        CivilDate.today(() => DateTime(2026, 11, 2, 0, 1)),
        d(2026, 11, 2),
      );
    });

    test(
      'zapis za bazu je ponoć UTC istog datuma i vraća se bez pomeranja',
      () {
        final wire = d(2026, 11, 2).toWire();
        expect(wire.isUtc, isTrue);
        expect(wire, DateTime.utc(2026, 11, 2));
        expect(CivilDate.fromWire(wire), d(2026, 11, 2));
        // Vrednost pročitana kao lokalna i dalje daje isti datum.
        expect(CivilDate.fromWire(wire.toLocal()), d(2026, 11, 2));
      },
    );

    test('tekst je YYYY-MM-DD', () {
      expect(d(2026, 3, 5).toString(), '2026-03-05');
      expect(CivilDate.parse('2026-03-05'), d(2026, 3, 5));
      expect(() => CivilDate.parse('2026-3-5x'), throwsFormatException);
    });
  });

  group('DateRange', () {
    test('kraj ne sme biti pre početka', () {
      expect(
        () => DateRange(d(2026, 11, 3), d(2026, 11, 2)),
        throwsArgumentError,
      );
    });

    test('dani i pripadnost uključuju oba kraja', () {
      final r = DateRange(d(2026, 11, 30), d(2026, 12, 2));
      expect(r.dayCount, 3);
      expect(r.days, [d(2026, 11, 30), d(2026, 12, 1), d(2026, 12, 2)]);
      expect(r.contains(d(2026, 11, 30)), isTrue);
      expect(r.contains(d(2026, 12, 2)), isTrue);
      expect(r.contains(d(2026, 12, 3)), isFalse);
    });
  });

  group('nedelja i mesec', () {
    test('nedelja traje od ponedeljka do nedelje', () {
      expect(weekOf(d(2026, 11, 5)), DateRange(d(2026, 11, 2), d(2026, 11, 8)));
      expect(weekOf(d(2026, 11, 2)), DateRange(d(2026, 11, 2), d(2026, 11, 8)));
      expect(weekOf(d(2026, 11, 8)), DateRange(d(2026, 11, 2), d(2026, 11, 8)));
      // Preko granice godine.
      expect(weekOf(d(2027, 1, 1)), DateRange(d(2026, 12, 28), d(2027, 1, 3)));
    });

    test('mesec je ceo kalendarski mesec', () {
      expect(
        monthOf(d(2026, 11, 17)),
        DateRange(d(2026, 11, 1), d(2026, 11, 30)),
      );
      expect(monthOf(d(2028, 2, 3)), DateRange(d(2028, 2, 1), d(2028, 2, 29)));
      expect(monthOf(d(2026, 2, 3)).dayCount, 28);
    });
  });

  group('weekPeriods', () {
    test('nedeljni plan je jedan period', () {
      final periods = weekPeriods(weekOf(d(2026, 11, 4)));
      expect(periods, hasLength(1));
      expect(periods.single.number, 1);
      expect(periods.single.range, DateRange(d(2026, 11, 2), d(2026, 11, 8)));
    });

    test('mesec se seče na delove nedelja unutar meseca', () {
      // Novembar 2026 počinje u nedelju, a završava se u ponedeljak.
      final periods = weekPeriods(monthOf(d(2026, 11, 1)));
      expect(periods.map((p) => p.range), [
        DateRange(d(2026, 11, 1), d(2026, 11, 1)),
        DateRange(d(2026, 11, 2), d(2026, 11, 8)),
        DateRange(d(2026, 11, 9), d(2026, 11, 15)),
        DateRange(d(2026, 11, 16), d(2026, 11, 22)),
        DateRange(d(2026, 11, 23), d(2026, 11, 29)),
        DateRange(d(2026, 11, 30), d(2026, 11, 30)),
      ]);
      expect(periods.map((p) => p.number), [1, 2, 3, 4, 5, 6]);
    });

    test('mesec može imati i samo četiri cele nedelje', () {
      // Februar 2027 počinje u ponedeljak i ima 28 dana.
      final periods = weekPeriods(monthOf(d(2027, 2, 1)));
      expect(periods, hasLength(4));
      expect(periods.every((p) => p.range.dayCount == 7), isTrue);
    });

    test('periodi pokrivaju svaki dan tačno jednom', () {
      for (var m = 1; m <= 12; m++) {
        final month = monthOf(d(2026, m, 1));
        final days = [for (final p in weekPeriods(month)) ...p.range.days];
        expect(days, month.days, reason: 'mesec $m');
      }
    });

    test('periodFor nalazi period za dan ili null van plana', () {
      final month = monthOf(d(2026, 11, 1));
      expect(periodFor(month, d(2026, 11, 30))!.number, 6);
      expect(periodFor(month, d(2026, 11, 4))!.number, 2);
      expect(periodFor(month, d(2026, 12, 1)), isNull);
    });
  });
}
