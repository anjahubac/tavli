import '../../domain/plan_calendar.dart';

const _weekdays = [
  'Ponedeljak',
  'Utorak',
  'Sreda',
  'Četvrtak',
  'Petak',
  'Subota',
  'Nedelja',
];

const _months = [
  'januar',
  'februar',
  'mart',
  'april',
  'maj',
  'jun',
  'jul',
  'avgust',
  'septembar',
  'oktobar',
  'novembar',
  'decembar',
];

String monthName(int month) => _months[month - 1];

/// "Ponedeljak, 2. novembar"
String dayLabel(CivilDate d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day}. ${monthName(d.month)}';

/// "2–8. novembar 2026." ili "28. oktobar – 3. novembar 2026."
String rangeLabel(DateRange r) {
  final s = r.start;
  final e = r.end;
  if (s == e) return '${s.day}. ${monthName(s.month)} ${s.year}.';
  if (s.year == e.year && s.month == e.month) {
    return '${s.day}–${e.day}. ${monthName(e.month)} ${e.year}.';
  }
  final startYear = s.year == e.year ? '' : ' ${s.year}.';
  return '${s.day}. ${monthName(s.month)}$startYear – '
      '${e.day}. ${monthName(e.month)} ${e.year}.';
}

/// "1 obrok", "3 obroka", "21 obrok".
String mealsCount(int n) =>
    '$n ${n % 10 == 1 && n % 100 != 11 ? 'obrok' : 'obroka'}';

const _weekdaysShort = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
const _weekdaysInitial = ['P', 'U', 'S', 'Č', 'P', 'S', 'N'];

/// „Pon“ … „Ned“, od ponedeljka.
List<String> get weekdaysShort => _weekdaysShort;

/// „P“ … „N“, od ponedeljka (zaglavlje meseca na telefonu).
List<String> get weekdaysInitial => _weekdaysInitial;

/// „Pon“
String weekdayShort(CivilDate d) => _weekdaysShort[d.weekday - 1];

/// Nedelja kao na platnu: „9. – 15. novembar“, „28. oktobar – 3. novembar“,
/// a preko nove godine i sa godinom.
String weekLabel(DateRange r) {
  final s = r.start;
  final e = r.end;
  if (s.year != e.year) {
    return '${s.day}. ${monthName(s.month)} ${s.year}. – '
        '${e.day}. ${monthName(e.month)} ${e.year}.';
  }
  if (s.month == e.month) return '${s.day}. – ${e.day}. ${monthName(e.month)}';
  return '${s.day}. ${monthName(s.month)} – ${e.day}. ${monthName(e.month)}';
}

/// „Novembar 2026“
String monthLabel(CivilDate d) {
  final name = monthName(d.month);
  return '${name[0].toUpperCase()}${name.substring(1)} ${d.year}';
}
