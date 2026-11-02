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
