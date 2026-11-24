import 'recipe_format.dart';

/// Civil dates for the Julian calendar used by the Serbian Orthodox Church.
class ChurchCalendar {
  ChurchCalendar(DateTime date)
    : today = DateTime.utc(date.year, date.month, date.day);

  final DateTime today;

  static const source = 'Crkveni kalendar SPC';

  /// Where the fixed slava dates come from (see [_slave]).
  static const slavaSource = 'Kalendari krsnih slava (Danas, Religija.rs)';
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

  /// Krsne slave with their civil date (Julian date + 13 days, valid for the
  /// supported years 1900–2099). Sources: the slava calendars of Danas
  /// ("Veliki kalendar srpskih krsnih slava") and Religija.rs ("Veliki
  /// kalendar krsnih slava"), which agree on every shared date, plus a few
  /// feasts of the SPC calendar missing from both lists. Feasts already in
  /// `named` (Blagovesti, Petrovdan, Preobraženje, Velika Gospojina,
  /// Vavedenje) are answered there. Keys are normalized search stems; more
  /// specific entries come first, so "Jovan Zlatousti" or "Letnji Nikola" is
  /// not answered as Jovanjdan or Nikoljdan.
  static const _slave = <(List<String>, String, int, int)>[
    // Several saints share a name: the specific ones first.
    (
      ['letnji nikol', 'nikola letnji', 'prenos mostiju svetog nikol'],
      'Prenos moštiju Svetog Nikole (Letnji Nikola)',
      5,
      22,
    ),
    (['zlatoust'], 'Sveti Jovan Zlatousti', 11, 26),
    (['bogoslov'], 'Sveti apostol i jevanđelist Jovan Bogoslov', 5, 21),
    (['milostiv'], 'Sveti Jovan Milostivi', 11, 25),
    (
      ['usekovanj', 'glavosek', 'glavosjek'],
      'Usekovanje glave Svetog Jovana Krstitelja',
      9,
      11,
    ),
    (['zacec'], 'Začeće Svetog Jovana Preteče i Krstitelja', 10, 6),
    (
      ['ivanjdan', 'rodjenje svetog jovan', 'rodjenje jovan', 'jovana pretec'],
      'Rođenje Svetog Jovana Preteče (Ivanjdan)',
      7,
      7,
    ),
    (
      ['prohor', 'pcinjsk', 'joil', 'rilsk'],
      'Prepodobni Prohor Pčinjski, Sveti prorok Joil i Prepodobni Jovan Rilski',
      11,
      1,
    ),
    (
      ['jovanjdan', 'jovandan', 'sveti jovan', 'svetog jovan', 'krstitelj'],
      'Sabor Svetog Jovana Krstitelja (Jovanjdan)',
      1,
      20,
    ),
    (['ostrosk'], 'Sveti Vasilije Ostroški Čudotvorac', 5, 12),
    (['vasilij', 'vasiljevdan', 'mali bozic'], 'Sveti Vasilije Veliki', 1, 14),
    (
      ['mrat', 'decansk'],
      'Sveti Mrata i Sveti Stefan Dečanski (Mratindan)',
      11,
      24,
    ),
    (
      [
        'stevanjdan',
        'stevandan',
        'sveti stefan',
        'svetog stefan',
        'arhidjakon',
      ],
      'Sveti prvomučenik i arhiđakon Stefan (Stevanjdan)',
      1,
      9,
    ),
    (
      ['vidovdan', 'knez lazar', 'kneza lazar', 'car lazar', 'cara lazar'],
      'Sveti mučenik knez Lazar i svi srpski mučenici (Vidovdan)',
      6,
      28,
    ),
    (
      ['djurdjic', 'obnovljenje hrama'],
      'Obnovljenje hrama Svetog Georgija (Đurđic)',
      11,
      16,
    ),
    (
      ['djurdjevdan', 'sveti djordj', 'svetog djordj', 'djuradj', 'georgij'],
      'Sveti velikomučenik Georgije (Đurđevdan)',
      5,
      6,
    ),
    (
      ['gavril', 'letnji arandjel', 'arandjelovdan letnji'],
      'Sabor Svetog Arhangela Gavrila',
      7,
      26,
    ),
    (
      ['arandjel', 'arhangel', 'arhandjel', 'sveti mihail', 'svetog mihail'],
      'Sabor Svetog Arhangela Mihaila (Aranđelovdan)',
      11,
      21,
    ),
    (['verig'], 'Časne verige Svetog apostola Petra', 1, 29),
    (
      ['petar i pavl', 'petra i pavl', 'sveti petar', 'svetog petr'],
      'Sveti apostoli Petar i Pavle (Petrovdan)',
      7,
      12,
    ),
    (
      [
        'letnja petk',
        'letnju petk',
        'letnja sveta petk',
        'letnju svetu petk',
        'prepodobnomucenic',
      ],
      'Sveta prepodobnomučenica Paraskeva (letnja Sveta Petka)',
      8,
      8,
    ),
    (
      ['sveta petk', 'svete petk', 'svetu petk', 'petkovic', 'paraskev'],
      'Prepodobna mati Paraskeva (Sveta Petka)',
      10,
      27,
    ),
    (
      ['bogoprim', 'simeon i an', 'simeona i an'],
      'Sveti Simeon Bogoprimac i Ana Proročica',
      2,
      16,
    ),
    (['mirotociv', 'nemanj', 'simeon'], 'Sveti Simeon Mirotočivi', 2, 26),
    (['joakim'], 'Sveti pravedni bogoroditelji Joakim i Ana', 9, 22),
    (
      ['blaga marij', 'magdalin'],
      'Sveta Marija Magdalina (Blaga Marija)',
      8,
      4,
    ),
    (
      ['ognjena marij', 'sveta marin', 'svete marin', 'marina'],
      'Sveta velikomučenica Marina (Ognjena Marija)',
      7,
      30,
    ),
    (
      ['mala gospojin', 'rodjenje presvete bogorodic'],
      'Mala Gospojina (Rođenje Presvete Bogorodice)',
      9,
      21,
    ),
    // Saints whose names are not shared.
    (['ignjatovdan', 'ignjatij'], 'Sveti Ignjatije Bogonosac', 1, 2),
    (
      ['sveti sava', 'svetog sav', 'savindan', 'svetosavsk'],
      'Sveti Sava (Savindan)',
      1,
      27,
    ),
    (
      ['tanasijevdan', 'tanasij'],
      'Sveti Atanasije Veliki (Tanasijevdan)',
      1,
      31,
    ),
    (['trifun', 'trivun'], 'Sveti mučenik Trifun', 2, 14),
    (['sretenj'], 'Sretenje Gospodnje', 2, 15),
    (['haralamp'], 'Sveti Haralampije', 2, 23),
    (
      ['mladenc', '40 mucenik', 'cetrdeset mucenik', 'sevastij'],
      'Sveti četrdeset mučenika Sevastijskih (Mladenci)',
      3,
      22,
    ),
    (
      ['markovdan', 'sveti mark', 'svetog mark', 'apostol mark'],
      'Sveti apostol i jevanđelist Marko (Markovdan)',
      5,
      8,
    ),
    (['jeremij'], 'Sveti prorok Jeremija', 5, 14),
    (['kiril', 'ciril', 'metodij'], 'Sveti Kirilo i Metodije', 5, 24),
    (
      ['konstantin', 'carica jelen', 'carice jelen', 'sveta jelen'],
      'Sveti car Konstantin i carica Jelena',
      6,
      3,
    ),
    (
      ['nedeljic', 'sveta nedelj', 'svete nedelj'],
      'Sveta Nedelja (Nedeljica)',
      7,
      20,
    ),
    (['prokopij'], 'Sveti velikomučenik Prokopije', 7, 21),
    (['kirik', 'julit'], 'Sveti Kirik i Julita', 7, 28),
    (
      ['ilindan', 'sveti ilij', 'svetog ilij', 'prorok ilij'],
      'Sveti prorok Ilija (Ilindan)',
      8,
      2,
    ),
    (
      ['pantelin', 'pantelejmon', 'sveti pantelij', 'svetog pantelij'],
      'Sveti velikomučenik Pantelejmon',
      8,
      9,
    ),
    (
      ['krstovdan', 'vozdvizenj'],
      'Vozdviženje Časnog krsta (Krstovdan)',
      9,
      27,
    ),
    (
      ['miholjdan', 'kirijak'],
      'Prepodobni Kirijak Otšelnik (Miholjdan)',
      10,
      12,
    ),
    (['pokrov'], 'Pokrov Presvete Bogorodice', 10, 14),
    (
      ['tomindan', 'sveti tom', 'svetog tom', 'apostol tom'],
      'Sveti apostol Toma (Tomindan)',
      10,
      19,
    ),
    (
      ['srdjevdan', 'sergij', 'vakh'],
      'Sveti mučenici Sergije i Vakh (Srđevdan)',
      10,
      20,
    ),
    (
      ['lucindan', 'lukindan', 'sveti luk', 'svetog luk', 'apostol luk'],
      'Sveti apostol i jevanđelist Luka (Lučindan)',
      10,
      31,
    ),
    (
      ['mitrovdan', 'dimitrij', 'sveti mitar'],
      'Sveti velikomučenik Dimitrije (Mitrovdan)',
      11,
      8,
    ),
    (['avramij'], 'Prepodobni Avramije Zatvornik', 11, 11),
    (['vracev', 'kozm', 'damjan'], 'Sveti Kozma i Damjan (Vračevi)', 11, 14),
    (['matej', 'matijevdan'], 'Sveti apostol i jevanđelist Matej', 11, 29),
    (['alimpij'], 'Prepodobni Alimpije Stolpnik', 12, 9),
    (
      ['andrijevdan', 'sveti andr', 'svetog andr', 'apostol andr'],
      'Sveti apostol Andrej Prvozvani',
      12,
      13,
    ),
    (
      ['nikoljdan', 'sveti nikol', 'svetog nikol', 'nikola', 'nikolaj'],
      'Sveti Nikolaj Mirlikijski Čudotvorac (Nikoljdan)',
      12,
      19,
    ),
  ];

  /// Movable slava: Lazareva subota (Vrbica), the Saturday before Cveti.
  static const _lazarusKeys = ['lazarev', 'vrbic', 'lazaric'];

  /// Towns whose names start with a feast key.
  static final _feastTowns = RegExp(r'\b(lazarev|arandjelov)(ac|cu|ca|cem)\b');

  /// Lazareva subota in [year].
  static DateTime _lazarus(int year) => _days(easter(year), -8);

  /// A fixed slava falls on the same civil date every year, so its answer has
  /// no year: "Sveti Nikola (Nikoljdan) je 19. decembra." Only the movable
  /// Lazareva subota names a year; without an explicit one it is the next
  /// date from [today].
  ({String text, String source})? _slavaAnswer(
    String question,
    String? explicitYear,
  ) {
    // A birthday is not a slava, and a town named after a feast is not the
    // feast ("pijaca u Lazarevcu", "vašar u Aranđelovcu").
    if (question.contains('rodjendan')) return null;
    final q = question.replaceAll(_feastTowns, ' ');
    if (_lazarusKeys.any(q.contains)) {
      var year = explicitYear == null ? today.year : int.parse(explicitYear);
      if (explicitYear == null && _lazarus(year).isBefore(today)) year++;
      if (year > 2099) return null;
      return (
        text: 'Lazareva subota (Vrbica) je ${format(_lazarus(year))}',
        source: source,
      );
    }
    for (final (keys, name, month, day) in _slave) {
      if (keys.any((key) => _keyMatches(q, key))) {
        return (
          text: '$name je $day. ${_months[month - 1]}.',
          source: slavaSource,
        );
      }
    }
    return null;
  }

  /// A personal name alone is not a slava: "Kada je rođen Nikola Tesla?"
  /// must not answer Nikoljdan. A name key therefore needs a slava context
  /// in the question, and the word after it must not be another name
  /// ("Sveti Jovan Vladimir" is not on the list, so it gets no date).
  static final _slavaContext = RegExp(
    r'slav|\bsvet|praznik|\p{L}+dan\b',
    unicode: true,
  );

  /// Single-word keys that name a feast, not a person.
  static const _feastKeys = {
    'usekovanj',
    'glavosek',
    'glavosjek',
    'zacec',
    'verig',
    'sretenj',
    'mladenc',
    'sevastij',
    'pokrov',
    'vozdvizenj',
    'prepodobnomucenic',
    'petkovic',
    'vracev',
    'mirotociv',
    'bogoprim',
    'bogoslov',
    'milostiv',
    'zlatoust',
    'krstitelj',
    'arandjel',
    'arhangel',
    'arhandjel',
    'arhidjakon',
    'djurdjic',
    'nedeljic',
  };

  /// Words that may follow a saint's name in a slava question.
  static const _afterName = {
    'je',
    'se',
    'i',
    'a',
    'ove',
    'ovog',
    'sledece',
    'sledeceg',
    'godine',
    'datum',
    'dan',
    'dana',
    'slava',
    'slavu',
    'slavimo',
    'slavi',
    'slave',
    'kada',
    'kad',
    'krstitelj',
    'krstitelja',
    'pretece',
    'preteca',
    'mirlikijski',
    'cudotvorac',
    'arhangel',
    'apostol',
    'prorok',
    'velikomucenik',
    'zimski',
    'letnji',
    'prvozvani',
    'bogonosac',
    'veliki',
  };

  static bool _keyMatches(String q, String key) {
    final at = q.indexOf(key);
    if (at < 0) return false;
    final name =
        key.startsWith('svet') ||
        (!key.contains(' ') &&
            !key.contains('dan') &&
            !_feastKeys.contains(key));
    if (!name) return true;
    if (!_slavaContext.hasMatch(q)) return false;
    final rest = q
        .substring(at + key.length)
        .replaceFirst(RegExp(r'^\p{L}*', unicode: true), '');
    final next = RegExp(
      r'^[^\p{L}]*(\p{L}+)',
      unicode: true,
    ).firstMatch(rest)?.group(1);
    return next == null || _afterName.contains(next);
  }

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

    final asksDate =
        q.contains('kada') || q.contains('datum') || q.contains('kad ');
    if (asksDate && !q.contains('post') && !isFoodQuestion(q)) {
      if (_slavaAnswer(q, explicit) case final answer?) return answer;
    }

    if (asksDate) {
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
    // "slava" alone is not a calendar question ("Šta se služi na slavi?"
    // belongs to the cookbook); it is one when it asks which slava.
    return RegExp(
          r'\b(kad|kada|datum|kalendar\w*|praznik\w*|posti|posta|postu|post)\b',
        ).hasMatch(q) ||
        RegExp(r'\bkoj\w*\b.*\bslav').hasMatch(q);
  }

  static bool isFoodQuestion(String question) {
    final q = normalizeForSearch(question);
    return RegExp(
      // `\bjel` so "jelo", "jela" and "jelovnik" match but "Aranđelovdan"
      // (arandjelovdan) does not; "predjelo" is listed on its own.
      r'recept|\bjel[oa]|predjel|kuva|sprema|spremi|skuv|predlog|predloz|obrok|rucak|vecer|doruc|sastoj|naprav|sta ima od|pretrazi',
    ).hasMatch(q);
  }
}
