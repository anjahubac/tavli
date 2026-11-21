import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(400, 800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTavliTheme(TavliMotif.bosiljak, Brightness.light),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(
          body: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<TavliStripDay> week({int disabledBefore = 0}) => [
  for (var i = 0; i < 7; i++)
    TavliStripDay(
      weekday: ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'][i],
      day: '${9 + i}',
      semanticLabel: 'dan ${9 + i}',
      enabled: i >= disabledBefore,
    ),
];

List<TavliCalendarDay> month({int marks = 3}) => [
  for (var i = 0; i < 35; i++)
    TavliCalendarDay(
      day: '${i + 1}',
      semanticLabel: 'dan ${i + 1}',
      active: i < 30,
      marks: [
        if (i == 2)
          for (var m = 0; m < marks; m++)
            TavliCalendarMark('Jelo $m', done: m == 0),
      ],
    ),
];

const weekdays = ['P', 'U', 'S', 'Č', 'P', 'S', 'N'];

void main() {
  group('TavliWeekStrip', () {
    testWidgets('bira dan; dani van plana se ne biraju', (tester) async {
      int? picked;
      await pump(
        tester,
        TavliWeekStrip(
          days: week(disabledBefore: 2),
          selectedIndex: 4,
          onSelected: (i) => picked = i,
        ),
      );

      await tester.tap(find.text('15'));
      expect(picked, 6);
      picked = null;
      await tester.tap(find.text('9'));
      expect(picked, isNull);
      expect(
        tester.getSemantics(find.bySemanticsLabel('dan 13')),
        isSemantics(
          label: 'dan 13',
          isButton: true,
          isSelected: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(tester.getSize(find.byType(TavliWeekStrip)).height, 60);
    });

    testWidgets('320 px i dvostruk tekst: bez prelivanja', (tester) async {
      await pump(
        tester,
        TavliWeekStrip(days: week(), selectedIndex: 0, onSelected: (_) {}),
        size: const Size(320, 400),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('TavliMonthCalendar', () {
    testWidgets('tačka za svako jelo; dan van meseca se ne bira', (
      tester,
    ) async {
      int? picked;
      await pump(
        tester,
        TavliMonthCalendar(
          weekdays: weekdays,
          days: month(marks: 5),
          selectedIndex: 0,
          onSelected: (i) => picked = i,
        ),
      );
      final dots = find.descendant(
        of: find.bySemanticsLabel('dan 3'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      expect(dots, findsNWidgets(5));

      await tester.tap(find.text('3'));
      expect(picked, 2);
      picked = null;
      await tester.tap(find.text('33'));
      expect(picked, isNull);
    });

    testWidgets('računar: nazivi jela, a nizak prozor pomera mrežu bez '
        'prelivanja', (tester) async {
      await pump(
        tester,
        SizedBox(
          height: 700,
          child: TavliMonthCalendar(
            detailed: true,
            weekdays: const ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'],
            days: month(),
            selectedIndex: 2,
            onSelected: (_) {},
          ),
        ),
        size: const Size(1000, 760),
      );
      expect(find.text('Jelo 1'), findsOneWidget);
      expect(find.text('PON'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);

      await pump(
        tester,
        SizedBox(
          height: 200,
          child: TavliMonthCalendar(
            detailed: true,
            weekdays: const ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'],
            days: month(),
            selectedIndex: 2,
            onSelected: (_) {},
          ),
        ),
        size: const Size(1000, 400),
        textScale: 2,
      );
      expect(find.byType(ListView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('TavliMealCard', () {
    testWidgets('telefon: skuvano je zasenčeno i kaže „skuvano“; prazno '
        'mesto se ne otvara', (tester) async {
      var taps = 0;
      await pump(
        tester,
        Column(
          children: [
            TavliMealCard(
              label: 'Večera',
              title: 'Musaka',
              detail: '75 min · 4 porcije',
              onTap: () => taps++,
            ),
            TavliMealCard(
              label: 'Ručak',
              title: 'Pasulj',
              cooked: true,
              onTap: () => taps++,
            ),
            const TavliMealCard(
              label: 'Užina',
              title: 'Nije planirano',
              muted: true,
            ),
          ],
        ),
      );
      expect(find.text('Ručak · skuvano'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Večera, Musaka, 75 min · 4 porcije'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Ručak, Pasulj, skuvano'), findsOneWidget);

      await tester.tap(find.text('Musaka'));
      await tester.tap(find.text('Pasulj'));
      await tester.tap(find.text('Nije planirano'));
      expect(taps, 2);

      final c = Theme.of(tester.element(find.text('Musaka'))).colorScheme;
      Material card(String text) => tester.widget<Material>(
        find
            .ancestor(of: find.text(text), matching: find.byType(Material))
            .first,
      );
      expect(card('Musaka').color, c.surface);
      expect(card('Pasulj').color, c.surfaceContainerHigh);
    });

    testWidgets('računar: kompaktna kartica sa zelenom oznakom skuvanog', (
      tester,
    ) async {
      await pump(
        tester,
        const SizedBox(
          width: 140,
          child: TavliMealCard(
            compact: true,
            label: 'Doručak',
            title: 'Palačinke',
            detail: 'ne prikazuje se',
            cooked: true,
          ),
        ),
      );
      expect(find.byType(TavliTag), findsOneWidget);
      expect(find.text('Doručak'), findsOneWidget);
      expect(find.text('ne prikazuje se'), findsNothing);
    });
  });

  group('TavliWeekGrid', () {
    Widget grid() => TavliWeekGrid(
      days: [
        for (final d in week())
          TavliWeekDay(
            weekday: d.weekday,
            day: d.day,
            semanticLabel: d.semanticLabel,
            highlighted: d.day == '13',
          ),
      ],
      rows: [
        for (var m = 0; m < 3; m++)
          [
            for (var d = 0; d < 7; d++)
              d == 6
                  ? null
                  : TavliMealCard(
                      compact: true,
                      label: 'Obrok $m',
                      title: 'Jelo $m-$d sa dugim nazivom',
                    ),
          ],
      ],
    );

    testWidgets('popunjava visinu, kartice u redu iste visine', (tester) async {
      await pump(
        tester,
        SizedBox(height: 600, child: grid()),
        size: const Size(1000, 700),
      );
      expect(find.byType(ListView), findsNothing);
      final a = tester.getSize(find.text('Jelo 0-0 sa dugim nazivom'));
      expect(a.width, greaterThan(0));
      Size card(String t) => tester.getSize(
        find.ancestor(of: find.text(t), matching: find.byType(TavliMealCard)),
      );
      expect(
        card('Jelo 1-0 sa dugim nazivom').height,
        card('Jelo 1-5 sa dugim nazivom').height,
      );
    });

    testWidgets('nizak prozor i dvostruk tekst: pomera se bez prelivanja', (
      tester,
    ) async {
      await pump(
        tester,
        SizedBox(height: 300, child: grid()),
        size: const Size(800, 400),
        textScale: 2,
      );
      expect(find.byType(ListView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('TavliPeriodSwitcher: strelica bez radnje je isključena', (
    tester,
  ) async {
    var prev = 0;
    await pump(
      tester,
      TavliPeriodSwitcher(
        label: '9. – 15. novembar',
        previousLabel: 'Prethodna nedelja',
        nextLabel: 'Sledeća nedelja',
        onPrevious: () => prev++,
        onNext: null,
      ),
    );
    await tester.tap(find.byType(TavliIconButton).first);
    await tester.tap(find.byType(TavliIconButton).last);
    expect(prev, 1);
    expect(find.text('9. – 15. novembar'), findsOneWidget);
  });
}
