import 'recipe_format.dart';

/// Civil dates for the Julian calendar used by the Serbian Orthodox Church.
class ChurchCalendar {
  ChurchCalendar(DateTime date)
    : today = DateTime.utc(date.year, date.month, date.day);

  final DateTime today;

  static const source = 'Crkveni kalendar SPC';
  static const fastingGuide = 'Manastir Visoki Dečani, vodič „Post“';

  static DateTime easter(int year) {
    final offset = (19 * (year % 19) + 15) % 30;
    final correction = (2 * (year % 4) + 4 * (year % 7) - offset + 34) % 7;
    final date = offset + correction + 114;
    return DateTime.utc(year, date ~/ 31, date % 31 + 1 + 13);
  }

  static const _months = [
    'januara',
    'februara',
    'marta',
    'aprila',
    'maja',
    'juna',
    'jula',
    'avgusta',
    'septembra',
    'oktobra',
    'novembra',
    'decembra',
  ];

  static String format(DateTime date) =>
      '${date.day}. ${_months[date.month - 1]} ${date.year}.';

  static DateTime _days(DateTime date, int days) =>
      date.add(Duration(days: days));

  static List<({String name, DateTime start, DateTime end})> _fasts(int year) {
    final pascha = easter(year);
    final apostles = _days(pascha, 57);
    final peterEve = DateTime.utc(year, 7, 11);
    return [
      (name: 'Veliki post', start: _days(pascha, -48), end: _days(pascha, -1)),
      if (!apostles.isAfter(peterEve))
        (name: 'Petrovski post', start: apostles, end: peterEve),
      (
        name: 'Gospojinski post',
        start: DateTime.utc(year, 8, 14),
        end: DateTime.utc(year, 8, 27),
      ),
      (
        name: 'Božićni post',
        start: DateTime.utc(year, 11, 28),
        end: DateTime.utc(year + 1, 1, 6),
      ),
    ];
  }

  static ({String name, DateTime start, DateTime end})? _current(
    DateTime day,
  ) => [..._fasts(day.year - 1), ..._fasts(day.year)]
      .where((fast) => !day.isBefore(fast.start) && !day.isAfter(fast.end))
      .firstOrNull;

  // General daily rule from the Dečani guide. Individual saints' feast
  // dispensations are outside this calendar's reference data.
  static String rule(DateTime day) {
    final pascha = easter(day.year);
    final relative = day.difference(pascha).inDays;
    final weekly =
        day.weekday == DateTime.wednesday || day.weekday == DateTime.friday;
    final weekend = day.weekday >= DateTime.saturday;
    bool isDate(int month, int date) => day.month == month && day.day == date;

    if (relative == -2) {
      return 'uzdržavanje do iznošenja plaštanice, zatim na vodi';
    }
    if (isDate(1, 6)) return 'na vodi';
    if (isDate(1, 18) || isDate(9, 11) || isDate(9, 27)) return 'na ulju';

    switch (_current(day)?.name) {
      case 'Veliki post':
        if (relative == -7 || (isDate(4, 7) && relative < -7)) return 'riba';
        if (relative == -3) return 'na ulju';
        return relative < -7 && (weekend || isDate(3, 22))
            ? 'na ulju'
            : 'na vodi';
      case 'Petrovski post':
        return weekly ? 'na vodi' : 'riba';
      case 'Gospojinski post':
        if (isDate(8, 19)) return 'riba';
        return weekend ? 'na ulju' : 'na vodi';
      case 'Božićni post':
        if (isDate(12, 4) ||
            (weekend && day.month == 12 && day.day < 31) ||
            (weekend && day.month == 11)) {
          return 'riba';
        }
        return weekly ? 'na vodi' : 'na ulju';
    }

    if (relative >= -55 && relative <= -49) return 'bez mesa';
    final freeWeek =
        (day.month == 1 && day.day >= 7 && day.day <= 17) ||
        (relative >= -69 && relative <= -63) ||
        (relative >= 0 && relative <= 6) ||
        (relative >= 49 && relative <= 55);
    return weekly && !freeWeek ? 'na vodi' : 'mrsno';
  }

  ({String name, DateTime start, DateTime end}) get _next => [
    ..._fasts(today.year),
    ..._fasts(today.year + 1),
  ].firstWhere((fast) => fast.start.isAfter(today));

  String get status {
    final current = _current(today);
    final next = _next;
    final daily = rule(today);
    final label = daily == 'mrsno' ? 'mrsno' : 'posno, $daily';
    return current == null
        ? 'Danas $label · ${next.name} od ${next.start.day}. ${_months[next.start.month - 1]}'
        : 'Danas $label · ${current.name}';
  }

  /// Renders selected facts directly so the model cannot invent dates.
  ({String text, String source})? answer(String question) {
    final q = normalizeForSearch(question);
    final explicit = RegExp(r'\b\d{4}\b').firstMatch(q)?.group(0);
    final year = explicit == null ? today.year : int.parse(explicit);
    if (year < 1900 || year > 2099) return null;
    final pascha = easter(year);
    final named = <String, (String, DateTime)>{
      'vaskrs': ('Vaskrs', pascha),
      'uskrs': ('Vaskrs', pascha),
      'cveti': ('Cveti', _days(pascha, -7)),
      'veliki petak': ('Veliki petak', _days(pascha, -2)),
      'spasovdan': ('Spasovdan', _days(pascha, 39)),
      'duhov': ('Duhovi', _days(pascha, 49)),
      'badnji': ('Badnji dan', DateTime.utc(year, 1, 6)),
      'bozic': ('Božić', DateTime.utc(year, 1, 7)),
      'blagovest': ('Blagovesti', DateTime.utc(year, 4, 7)),
      'vavedenj': ('Vavedenje', DateTime.utc(year, 12, 4)),
      'preobrazenj': ('Preobraženje', DateTime.utc(year, 8, 19)),
      'petrovdan': ('Petrovdan', DateTime.utc(year, 7, 12)),
      'velika gospojina': ('Velika Gospojina', DateTime.utc(year, 8, 28)),
    };
    final ending =
        q.contains('zavrs') || q.contains('kraj') || q.contains('do kada');
    final nativityEnding =
        ending &&
        q.contains('bozicn') &&
        (explicit != null || today.month == 1);
    final fasts = _fasts(nativityEnding ? year - 1 : year);
    final fast = fasts.where((item) {
      final stem = switch (item.name) {
        'Božićni post' => 'bozicn',
        'Gospojinski post' => 'gospojinsk',
        'Petrovski post' => 'petrovsk',
        _ => 'velik',
      };
      return q.contains(stem) && q.contains('post');
    }).firstOrNull;
    if (fast != null && !isFoodQuestion(q)) {
      if (RegExp(r'\brib|ulj|na vodi').hasMatch(q)) {
        final description = switch (fast.name) {
          'Božićni post' => 'Sredom i petkom je na vodi. Riba je dozvoljena vikendom i na Vavedenje, osim tokom završne sedmice. Badnji dan je na vodi.',
          'Veliki post' => 'Uglavnom se posti na vodi. Ulje je dozvoljeno vikendom uz izuzetke, a riba na Cveti i na Blagovesti kada praznik ne pada u Strasnu sedmicu.',
          'Petrovski post' => 'Sredom i petkom posti se na vodi, a ostalim danima uobičajeno je razrešenje na ribu.',
          _ => 'Radnim danima posti se na vodi, vikendom na ulju. Na Preobraženje je dozvoljena riba.',
        };
        return (text: description, source: fastingGuide);
      }

      return (
        text:
            '${fast.name} traje od ${format(fast.start)} do '
            '${format(fast.end)}',
        source: source,
      );
    }

    if (q.contains('sledec') && q.contains('post') && !isFoodQuestion(q)) {
      final next = _next;
      return (
        text: '${next.name} počinje ${format(next.start)}',
        source: source,
      );
    }

    if (q.contains('kada') || q.contains('datum') || q.contains('kad ')) {
      for (final MapEntry(key: key, value: (name, date)) in named.entries) {
        if (q.contains(key) && !q.contains('post')) {
          return (text: '$name je ${format(date)}', source: source);
        }
      }
    }

    if (!isFoodQuestion(q) && (q.contains('posn') || q.contains('post'))) {
      final day = q.contains('sutra')
          ? _days(today, 1)
          : q.contains('danas')
          ? today
          : _parseDay(q, year);
      if (day != null) {
        final daily = rule(day);
        return (
          text:
              '${format(day)} ${daily == 'mrsno' ? 'nije dan posta' : 'posti se: $daily'}.',
          source: '$source · $fastingGuide',
        );
      }
    }

    if (q.contains('sta se jede') && q.contains('na ulju')) {
      return (
        text:
            'Na ulju se jede posna hrana pripremljena sa biljnim uljem. '
            'Meso, mlečni proizvodi i jaja su izostavljeni. Riba je za dane sa razrešenjem na ribu.',
        source: fastingGuide,
      );
    }
    return null;
  }

  static DateTime? _parseDay(String question, int year) {
    final match = RegExp(
      r'\b(\d{1,2})\.?\s+(\p{L}+)',
      unicode: true,
    ).firstMatch(question);
    if (match == null) return null;
    final month = _months.map(normalizeForSearch).toList().indexOf(match[2]!);
    if (month < 0) return null;
    final date = int.parse(match[1]!);
    final day = DateTime.utc(year, month + 1, date);
    return day.day == date ? day : null;
  }

  static bool isCalendarQuestion(String question) {
    if (isFoodQuestion(question)) return false;
    final q = normalizeForSearch(question);
    return RegExp(
      r'\b(kad|kada|datum|kalendar\w*|praznik\w*|posti|posta|postu|post)\b',
    ).hasMatch(q);
  }

  static bool isFoodQuestion(String question) {
    final q = normalizeForSearch(question);
    return RegExp(
      r'recept|jel[oa]|kuva|sprema|spremi|skuv|predlog|predloz|obrok|rucak|vecer|doruc|sastoj|naprav|sta ima od|pretrazi',
    ).hasMatch(q);
  }
}
