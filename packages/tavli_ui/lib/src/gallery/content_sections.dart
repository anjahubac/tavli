import 'package:material_ui/material_ui.dart';

import '../content/tavli_card.dart';
import '../content/tavli_data_table.dart';
import '../content/tavli_expandable.dart';
import '../content/tavli_list.dart';
import '../content/tavli_media.dart';
import '../content/tavli_notice.dart';
import '../content/tavli_plan.dart';
import '../content/tavli_recipe_tile.dart';
import '../content/tavli_states.dart';
import '../content/tavli_tag.dart';
import '../content/tavli_today.dart';
import '../controls/tavli_button.dart';
import '../controls/tavli_icon_button.dart';
import '../controls/tavli_rows.dart';
import '../icons/tavli_icons.dart';
import '../tokens.dart';
import 'gallery_section.dart';

/// Odeljci galerije za kartice, liste, napomene i stanja ekrana.
class TavliContentGallerySections extends StatelessWidget {
  const TavliContentGallerySections({super.key});

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: TavliSpacing.medium);
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GallerySection(title: 'Kartice', child: _Cards()),
        GallerySection(title: 'Početna: danas i sutra', child: _Today()),
        GallerySection(title: 'Mreža kartica', child: _Grid()),
        GallerySection(title: 'Liste', child: _Lists()),
        GallerySection(title: 'Tabela za računar', child: _Table()),
        GallerySection(
          title: 'Napomene',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TavliNotice(
                message: 'Plan se pravi od recepata iz tvoje kolekcije.',
              ),
              gap,
              _WarningNotice(),
              gap,
              TavliNotice(
                tone: TavliNoticeTone.success,
                message: 'Namirnice su prebačene u ostavu.',
              ),
              gap,
              TavliNotice(
                tone: TavliNoticeTone.error,
                title: 'Recept nije napravljen',
                message: 'Svi AI modeli su trenutno zauzeti. Probaj ponovo.',
              ),
            ],
          ),
        ),
        GallerySection(title: 'Proširivi blok', child: _Expandables()),
        GallerySection(title: 'Naslov odeljka', child: _Headers()),
        GallerySection(title: 'Sličica, avatar i oznaka', child: _Media()),
        GallerySection(title: 'Prazan ekran i učitavanje', child: _States()),
        GallerySection(title: 'Plan: nedelja i mesec', child: _Plan()),
        GallerySection(title: 'Omiljeni recepti', child: _Favorites()),
      ],
    );
  }
}

class _Favorites extends StatelessWidget {
  const _Favorites();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          TavliAddTile(label: 'Dodaj', onTap: () {}),
          TavliRecipeTile(title: 'Musaka od krompira', onTap: () {}),
          TavliRecipeTile(title: 'Punjene paprike', tintIndex: 1, onTap: () {}),
        ],
      ),
    ),
  );
}

class _WarningNotice extends StatelessWidget {
  const _WarningNotice();

  @override
  Widget build(BuildContext context) => TavliNotice(
    tone: TavliNoticeTone.warning,
    message: 'Za sutrašnji ručak fale 2 namirnice.',
    linkLabel: 'Nabavka',
    onLink: () {},
  );
}

class _MealCard extends StatelessWidget {
  const _MealCard(this.slot, this.name, this.variant, {this.extra});

  final String slot;
  final String name;
  final TavliCardVariant variant;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = variant == TavliCardVariant.highlighted
        ? null
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final compact = variant == TavliCardVariant.compact;
    return TavliCard(
      variant: variant,
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slot,
            style: t.labelMedium?.copyWith(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: t.titleMedium?.copyWith(
              fontSize: compact ? 13 : 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 4),
            Text(
              extra!,
              style: t.bodySmall?.copyWith(fontSize: 13, color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards();

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: TavliSpacing.medium);
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryLabeled(
          'Obična, istaknuta i skuvana · iste visine u redu',
          TavliCardRow(
            children: [
              _MealCard('Doručak', 'Ovsena kaša', TavliCardVariant.cooked),
              _MealCard(
                'Ručak · sledeći',
                'Piletina sa povrćem iz rerne',
                TavliCardVariant.highlighted,
                extra: '45 min',
              ),
              _MealCard('Večera', 'Čorba', TavliCardVariant.plain),
            ],
          ),
        ),
        gap,
        GalleryLabeled(
          'Kompaktna · radijus 14',
          TavliCardRow(
            spacing: 6,
            children: [
              _MealCard('Pon', 'Sarma', TavliCardVariant.compact),
              _MealCard('Uto', 'Musaka od tikvica', TavliCardVariant.compact),
              _MealCard('Sre', 'Pasulj', TavliCardVariant.compact),
              _MealCard('Čet', 'Riba', TavliCardVariant.compact),
            ],
          ),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid();

  static const _recipes = [
    ('Musaka od krompira', '75 min · 4 porcije'),
    ('Pasulj prebranac', '120 min · 6 porcija'),
    ('Čorba od povrća', '40 min · 4 porcije'),
    ('Proja', '35 min · 8 porcija'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return GalleryLabeled(
      'Recepti na računaru · tri kolone, kartice u redu iste visine',
      TavliCardGrid(
        columns: 3,
        spacing: TavliSpacing.small,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recipes.length,
        itemBuilder: (context, i) => TavliCard(
          padding: EdgeInsets.zero,
          selected: i == 1,
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TavliThumbnail.cardTop(tintIndex: i),
              Padding(
                padding: const EdgeInsets.all(TavliSpacing.small),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_recipes[i].$1, style: t.titleSmall),
                    Text(
                      _recipes[i].$2,
                      style: t.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Lists extends StatefulWidget {
  const _Lists();

  @override
  State<_Lists> createState() => _ListsState();
}

class _ListsState extends State<_Lists> {
  final _pantry = ['Brašno', 'Jaja', 'So', 'Maslinovo ulje'];
  final _amounts = {'Brašno': '1 kg', 'Jaja': '10 kom', 'Maslinovo ulje': ''};
  final _bought = {'Paradajz': false, 'Luk': false};

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: TavliSpacing.medium);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryLabeled(
          'Sa količinom (bez količine samo naziv) · prevuci ulevo za „Ukloni“',
          TavliListGroup(
            children: [
              for (final item in _pantry)
                TavliListRow(
                  key: ValueKey(item),
                  title: item,
                  quantity: _amounts[item],
                  onRemove: () => setState(() => _pantry.remove(item)),
                ),
            ],
          ),
        ),
        gap,
        GalleryLabeled(
          'Sa sličicom i strelicom',
          TavliListGroup(
            children: [
              TavliListRow(
                leading: const TavliThumbnail.row(),
                title: 'Sarma',
                subtitle: '2 h · 6 porcija',
                showChevron: true,
                onTap: () {},
              ),
              TavliListRow(
                leading: const TavliThumbnail.row(tintIndex: 1),
                title: 'Gibanica',
                subtitle: '1 h 10 min · 8 porcija',
                showChevron: true,
                onTap: () {},
              ),
            ],
          ),
        ),
        gap,
        GalleryLabeled(
          'Sa ikonicom, dugmadima desno i za brisanje',
          TavliListGroup(
            children: [
              TavliListRow(
                leading: const Icon(Icons.key_outlined),
                title: '••••7Lm2',
                subtitle: 'Dodat 14.11.2026 · Radi',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TavliButton.text(label: 'Proveri', onPressed: () {}),
                    TavliIconButton(
                      icon: Icons.delete_outline_rounded,
                      semanticLabel: 'Obriši ključ',
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              TavliListRow(
                leading: const Icon(Icons.delete_forever_outlined),
                title: 'Obriši nalog',
                subtitle: 'Trajno briše nalog i sve podatke',
                destructive: true,
                onTap: () {},
              ),
            ],
          ),
        ),
        gap,
        GalleryLabeled(
          'Grupisana lista sa naslovima odeljaka',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TavliSectionHeader('Povrće'),
              TavliListGroup(
                children: [
                  for (final e in _bought.entries)
                    TavliCheckRow(
                      title: e.key,
                      detail: '1 kg',
                      checked: e.value,
                      onChanged: (v) => setState(() => _bought[e.key] = v),
                    ),
                ],
              ),
              const TavliSectionHeader(
                'Kupljeno · 1',
                style: TavliSectionHeaderStyle.bold,
              ),
              TavliListGroup(
                children: [
                  TavliCheckRow(
                    title: 'Pirinač',
                    detail: '500 g',
                    checked: true,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table();

  @override
  Widget build(BuildContext context) {
    return GalleryLabeled(
      '4 namirnice',
      TavliDataTable(
        columns: const [
          TavliColumn('Namirnica', flex: 3),
          TavliColumn('Količina', flex: 2, alignEnd: true),
        ],
        rows: [
          TavliTableRow(const ['Brašno', '1 kg'], onTap: () {}),
          TavliTableRow(const ['Jaja', '10 kom'], onTap: () {}),
          TavliTableRow(const ['So', ''], onTap: () {}),
          TavliTableRow(const ['Maslinovo ulje', '0,5 l'], onTap: () {}),
        ],
      ),
    );
  }
}

class _Headers extends StatelessWidget {
  const _Headers();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TavliSectionHeader('Na umu'),
        TavliSectionHeader(
          'Sutra',
          trailing: TavliButton.text(label: 'Prikaži plan', onPressed: () {}),
        ),
        const TavliSectionHeader(
          'Kupljeno · 2',
          style: TavliSectionHeaderStyle.bold,
        ),
      ],
    );
  }
}

class _Media extends StatelessWidget {
  const _Media();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryLabeled(
          'Sličica 56 · tri meke boje',
          Row(
            spacing: TavliSpacing.small,
            children: [
              TavliThumbnail.row(),
              TavliThumbnail.row(tintIndex: 1),
              TavliThumbnail.row(tintIndex: 2),
            ],
          ),
        ),
        SizedBox(height: TavliSpacing.medium),
        GalleryLabeled(
          'Sličica u kartici na računaru · visina 120',
          TavliThumbnail.banner(tintIndex: 2),
        ),
        SizedBox(height: TavliSpacing.medium),
        GalleryLabeled(
          'Avatar 40 (36 na iOS-u) i oznaka skuvanog',
          Row(
            spacing: TavliSpacing.medium,
            children: [
              TavliAvatar(initials: 'AH', semanticLabel: 'Anja'),
              TavliAvatar(initials: 'M', size: 30),
              TavliTag.cooked(),
            ],
          ),
        ),
      ],
    );
  }
}

class _States extends StatefulWidget {
  const _States();

  @override
  State<_States> createState() => _StatesState();
}

class _StatesState extends State<_States> {
  // Okretanje je ugašeno dok se ne uključi, da galerija i testovi miruju.
  bool _spin = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TavliCard(
          child: TavliEmptyState(
            icon: Icons.menu_book_outlined,
            title: 'Još nema recepata',
            message:
                'Fotografiši recept ili upiši naziv jela, a AI će ga '
                'prepisati za tebe.',
            action: TavliButton.primary(
              label: 'Dodaj recept',
              icon: Icons.add,
              onPressed: () {},
            ),
          ),
        ),
        const SizedBox(height: TavliSpacing.medium),
        TavliCard(
          child: Column(
            children: [
              const SizedBox(height: TavliSpacing.medium),
              TickerMode(
                enabled: _spin,
                child: const TavliLoading(message: 'Pravim recept…'),
              ),
              const SizedBox(height: TavliSpacing.small),
              TavliSwitchRow(
                title: 'Animacija učitavanja',
                value: _spin,
                onChanged: (v) => setState(() => _spin = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Plan sa platna: izbor perioda, traka dana, kartice obroka, mesec sa
/// tačkama i obroci dana, pa nedeljna mreža za računar.
class _Plan extends StatefulWidget {
  const _Plan();

  @override
  State<_Plan> createState() => _PlanState();
}

class _PlanState extends State<_Plan> {
  int _day = 4;
  int _date = 18;

  static const _week = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
  static const _meals = [
    ['Palačinke', 'Pileća supa', 'Pita sa sirom'],
    ['Jaja na oko', 'Sarma', 'Salata sa tunom'],
    ['Omlet sa povrćem', 'Grašak sa piletinom', 'Proja'],
    ['Griz', 'Riblji paprikaš', 'Testenina sa sirom'],
    ['Ovsena kaša sa jabukom', 'Pasulj prebranac', 'Musaka od krompira'],
    ['Kajgana', 'Punjene paprike', 'Čorba od povrća'],
    ['Popara', 'Pečeno pile', 'Gibanica'],
  ];
  static const _types = ['Doručak', 'Ručak', 'Večera'];

  /// Skuvano: sve do petka, pa doručak i ručak u petak.
  bool _cooked(int day, int meal) => day < 4 || (day == 4 && meal < 2);

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: TavliSpacing.medium);
    // Novembar 2026: počinje u nedelju, mreža od 26. oktobra do 6. decembra.
    final days = [
      for (var i = 0; i < 42; i++)
        () {
          final n = i - 5;
          final inMonth = n >= 1 && n <= 30;
          final day = inMonth ? n : (n < 1 ? 31 + n : n - 30);
          final planned = n >= 9 && n <= 22;
          final week = n >= 9 && n <= 15;
          return TavliCalendarDay(
            day: '$day',
            active: inMonth,
            semanticLabel: '$day. novembar',
            marks: [
              if (planned)
                for (var m = 0; m < 3; m++)
                  TavliCalendarMark(
                    week ? _meals[n - 9][m] : _types[m],
                    done: week && _cooked(n - 9, m),
                  ),
            ],
          );
        }(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TavliPeriodSwitcher(
          label: '9. – 15. novembar',
          previousLabel: 'Prethodna nedelja',
          nextLabel: 'Sledeća nedelja',
          onPrevious: () {},
          onNext: null,
        ),
        TavliWeekStrip(
          selectedIndex: _day,
          onSelected: (i) => setState(() => _day = i),
          days: [
            for (var i = 0; i < 7; i++)
              TavliStripDay(
                weekday: _week[i],
                day: '${9 + i}',
                semanticLabel: '${_week[i]} ${9 + i}',
              ),
          ],
        ),
        const TavliSectionHeader(
          'Petak, 13. novembar',
          style: TavliSectionHeaderStyle.title,
        ),
        for (var m = 0; m < 3; m++) ...[
          TavliMealCard(
            label: _types[m],
            title: _meals[_day][m],
            detail: '75 min · 4 porcije',
            cooked: _cooked(_day, m),
            onTap: () {},
          ),
          const SizedBox(height: TavliSpacing.small),
        ],
        const TavliMealCard(
          label: 'Užina',
          title: 'Nije planirano',
          muted: true,
        ),
        gap,
        TavliMonthCalendar(
          weekdays: const ['P', 'U', 'S', 'Č', 'P', 'S', 'N'],
          days: days,
          selectedIndex: _date + 5,
          onSelected: (i) => setState(() => _date = i - 5),
        ),
        const SizedBox(height: TavliSpacing.small),
        const TavliCalendarLegend(),
        gap,
        TavliMealList(
          children: [
            for (var m = 0; m < 3; m++)
              TavliMealRow(
                label: _types[m],
                title: _meals[4][m],
                cooked: _cooked(4, m),
                onTap: () {},
              ),
          ],
        ),
        gap,
        SizedBox(
          height: 300,
          child: TavliWeekGrid(
            days: [
              for (var i = 0; i < 7; i++)
                TavliWeekDay(
                  weekday: _week[i],
                  day: '${9 + i}',
                  semanticLabel: '${_week[i]} ${9 + i}',
                  highlighted: i == 4,
                ),
            ],
            rows: [
              for (var m = 0; m < 3; m++)
                [
                  for (var d = 0; d < 7; d++)
                    TavliMealCard(
                      compact: true,
                      label: _types[m],
                      title: _meals[d][m],
                      cooked: _cooked(d, m),
                      onTap: () {},
                    ),
                ],
            ],
          ),
        ),
        gap,
        SizedBox(
          height: 360,
          child: TavliMonthCalendar(
            detailed: true,
            weekdays: _week,
            days: days,
            selectedIndex: _date + 5,
            onSelected: (i) => setState(() => _date = i - 5),
          ),
        ),
      ],
    );
  }
}

class _Today extends StatelessWidget {
  const _Today();

  static const _tomorrow = [
    TavliUpcomingMeal(label: 'Doručak', title: 'Kajgana'),
    TavliUpcomingMeal(label: 'Ručak', title: 'Punjene paprike'),
    TavliUpcomingMeal(label: 'Večera', title: 'Čorba od povrća'),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: TavliSpacing.medium,
    children: [
      TavliNextMealCard(
        overline: 'Sledeće · Večera',
        title: 'Musaka od krompira',
        detail: '75 min · 4 porcije',
        actions: [
          TavliButton.primary(
            label: 'Kuvaj',
            glyph: TavliIcons.cook,
            onPressed: () {},
          ),
          TavliButton.secondary(
            label: 'Skuvano',
            glyph: TavliIcons.check,
            onPressed: () {},
          ),
        ],
      ),
      const TavliStatusText('Svi današnji obroci su skuvani.'),
      const GalleryLabeled(
        'Sutra · telefon',
        TavliUpcomingMeals(title: 'Sutra', meals: _tomorrow),
      ),
      const GalleryLabeled(
        'Sutra · računar',
        TavliUpcomingMeals(title: 'Sutra', meals: _tomorrow, card: true),
      ),
    ],
  );
}

class _Expandables extends StatelessWidget {
  const _Expandables();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: TavliSpacing.medium,
    children: [
      TavliExpandable(
        title: 'Ručak',
        subtitle: 'Pasulj prebranac\nIz mojih recepata',
        trailing: TavliIconButton(
          glyph: TavliIcons.swap,
          semanticLabel: 'Zameni jelo',
          onPressed: () {},
        ),
        initiallyExpanded: true,
        children: const [
          Text('Sastojci za 4 porcije · 90 min'),
          Text('• Pasulj 500 g'),
          Text('• Crni luk 2 kom'),
        ],
      ),
      const TavliExpandable(
        title: 'Više opcija',
        subtitle: 'Ostava i posebni zahtevi, nije obavezno',
        inset: false,
        children: [Text('Sadržaj')],
      ),
      const TavliProgressBar(
        value: 3 / 7,
        message: 'Pripremam plan… Pripremljeno 3 od 7 obroka.',
        semanticLabel: 'Napredak predloga',
      ),
    ],
  );
}
