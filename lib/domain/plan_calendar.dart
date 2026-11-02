/// Kalendar plana obroka: datumi bez vremena i vremenske zone, nedelje od
/// ponedeljka do nedelje i nedeljni delovi kalendarskog meseca.
library;

/// Kalendarski datum (godina, mesec, dan). Ne zavisi od vremenske zone ni
/// od letnjeg računanja vremena, pa putovanje ne pomera obrok na drugi dan.
class CivilDate implements Comparable<CivilDate> {
  CivilDate(this.year, this.month, this.day) {
    if (!_exists(year, month, day)) {
      throw ArgumentError('Nepostojeći datum: $year-$month-$day');
    }
  }

  /// Kalendarska polja lokalnog (ili bilo kog) vremena, bez konverzije.
  factory CivilDate.fromDateTime(DateTime t) =>
      CivilDate(t.year, t.month, t.day);

  /// Današnji datum po satu uređaja.
  factory CivilDate.today(DateTime Function() clock) =>
      CivilDate.fromDateTime(clock());

  /// Čita vrednost iz kolone vremena: datum je zapisan kao ponoć UTC.
  factory CivilDate.fromWire(DateTime t) =>
      CivilDate.fromDateTime(t.isUtc ? t : t.toUtc());

  /// Čita `YYYY-MM-DD`.
  factory CivilDate.parse(String text) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (m == null) throw FormatException('Neispravan datum', text);
    final (y, mo, d) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (!_exists(y, mo, d)) throw FormatException('Nepostojeći datum', text);
    return CivilDate(y, mo, d);
  }

  static bool _exists(int year, int month, int day) {
    final t = DateTime.utc(year, month, day);
    return t.year == year && t.month == month && t.day == day;
  }

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// Zapis za bazu i server: ponoć UTC istog datuma.
  DateTime toWire() => _utc;

  /// 1 = ponedeljak … 7 = nedelja.
  int get weekday => _utc.weekday;

  // Računa se u UTC-u, gde svaki dan ima tačno 24 sata.
  CivilDate addDays(int days) =>
      CivilDate.fromDateTime(_utc.add(Duration(days: days)));

  /// Broj dana do [other] (negativan ako je [other] ranije).
  int daysUntil(CivilDate other) => other._utc.difference(_utc).inDays;

  bool isBefore(CivilDate other) => compareTo(other) < 0;
  bool isAfter(CivilDate other) => compareTo(other) > 0;

  @override
  int compareTo(CivilDate other) => year != other.year
      ? year - other.year
      : month != other.month
      ? month - other.month
      : day - other.day;

  @override
  bool operator ==(Object other) =>
      other is CivilDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// Raspon datuma, oba kraja uključena.
class DateRange {
  DateRange(this.start, this.end) {
    if (end.isBefore(start)) {
      throw ArgumentError('Kraj $end je pre početka $start');
    }
  }

  final CivilDate start;
  final CivilDate end;

  int get dayCount => start.daysUntil(end) + 1;

  List<CivilDate> get days => [
    for (var i = 0; i < dayCount; i++) start.addDays(i),
  ];

  bool contains(CivilDate date) => !date.isBefore(start) && !date.isAfter(end);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start..$end';
}

/// Nedelja (ponedeljak–nedelja) u kojoj je [date].
DateRange weekOf(CivilDate date) {
  final monday = date.addDays(1 - date.weekday);
  return DateRange(monday, monday.addDays(6));
}

/// Ceo kalendarski mesec u kome je [date].
DateRange monthOf(CivilDate date) {
  final first = CivilDate(date.year, date.month, 1);
  final nextFirst = date.month == 12
      ? CivilDate(date.year + 1, 1, 1)
      : CivilDate(date.year, date.month + 1, 1);
  return DateRange(first, nextFirst.addDays(-1));
}

/// Nedeljni deo plana: presek plana i jedne nedelje pon–ned. Za nabavku
/// po nedeljama; mesec ih može imati do šest.
class WeekPeriod {
  const WeekPeriod(this.number, this.range);

  /// Redni broj u planu, od 1.
  final int number;
  final DateRange range;

  @override
  bool operator ==(Object other) =>
      other is WeekPeriod && other.number == number && other.range == range;

  @override
  int get hashCode => Object.hash(number, range);

  @override
  String toString() => 'WeekPeriod($number, $range)';
}

/// Deli [plan] na preseke sa nedeljama pon–ned, redom.
List<WeekPeriod> weekPeriods(DateRange plan) {
  final periods = <WeekPeriod>[];
  var start = plan.start;
  while (!start.isAfter(plan.end)) {
    final sunday = weekOf(start).end;
    final end = sunday.isAfter(plan.end) ? plan.end : sunday;
    periods.add(WeekPeriod(periods.length + 1, DateRange(start, end)));
    start = end.addDays(1);
  }
  return periods;
}

/// Nedeljni deo [plan]a koji sadrži [date], ili null ako je van plana.
WeekPeriod? periodFor(DateRange plan, CivilDate date) {
  for (final p in weekPeriods(plan)) {
    if (p.range.contains(date)) return p;
  }
  return null;
}
