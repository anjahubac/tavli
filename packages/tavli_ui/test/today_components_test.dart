import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(400, 800),
  double textScale = 1,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTavliTheme(TavliMotif.bosiljak, Brightness.light),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

TavliNextMealCard nextMeal({bool wide = false}) => TavliNextMealCard(
  overline: 'Sledeće · Večera',
  title: 'Musaka od krompira',
  detail: '75 min · 4 porcije',
  wide: wide,
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
);

const tomorrow = [
  TavliUpcomingMeal(label: 'Doručak', title: 'Kajgana'),
  TavliUpcomingMeal(label: 'Ručak', title: 'Punjene paprike'),
];

void main() {
  group('TavliNextMealCard', () {
    testWidgets('velika slova iznad naslova, naslov 20 na telefonu i 24 '
        'na širokom ekranu', (tester) async {
      await pump(tester, Padding(padding: EdgeInsets.zero, child: nextMeal()));
      expect(find.text('SLEDEĆE · VEČERA'), findsOneWidget);
      expect(find.bySemanticsLabel('Sledeće · Večera'), findsOneWidget);
      double titleSize() =>
          tester.widget<Text>(find.text('Musaka od krompira')).style!.fontSize!;
      expect(titleSize(), 20);
      expect(
        find.ancestor(
          of: find.text('Musaka od krompira'),
          matching: find.byWidgetPredicate(
            (w) => w is TavliCard && w.variant == TavliCardVariant.highlighted,
          ),
        ),
        findsOneWidget,
      );

      await pump(tester, nextMeal(wide: true));
      expect(titleSize(), 24);
    });

    for (final size in [const Size(320, 800), const Size(1200, 800)]) {
      testWidgets('${size.width} px, tekst 2×: dugmad iste visine, bez '
          'preliva', (tester) async {
        await pump(
          tester,
          SingleChildScrollView(child: nextMeal()),
          size: size,
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(FilledButton)).height,
          tester.getSize(find.byType(OutlinedButton)).height,
        );
      });
    }
  });

  testWidgets('TavliUpcomingMeals: red na telefonu, kartica na računaru', (
    tester,
  ) async {
    await pump(
      tester,
      const TavliUpcomingMeals(title: 'Sutra', meals: tomorrow),
    );
    expect(find.text('SUTRA'), findsOneWidget);
    expect(find.text('Kajgana · Punjene paprike'), findsOneWidget);
    expect(find.byType(TavliCard), findsNothing);

    await pump(
      tester,
      const TavliUpcomingMeals(title: 'Sutra', meals: tomorrow, card: true),
    );
    expect(find.byType(TavliCard), findsOneWidget);
    expect(find.text('Doručak'), findsOneWidget);
    expect(find.text('Punjene paprike'), findsOneWidget);
    expect(find.byType(TavliDivider), findsOneWidget);
  });

  testWidgets('TavliMultiChoice pali i gasi čipove nezavisno', (tester) async {
    var selected = {'Ručak'};
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => TavliMultiChoice<String>(
          options: const [
            TavliOption('Doručak', 'Doručak'),
            TavliOption('Ručak', 'Ručak'),
            TavliOption('Večera', 'Večera'),
          ],
          selected: selected,
          onChanged: (v) => setState(() => selected = v),
        ),
      ),
    );
    await tester.tap(find.text('Večera'));
    await tester.pump();
    expect(selected, {'Ručak', 'Večera'});
    await tester.tap(find.text('Ručak'));
    await tester.pump();
    expect(selected, {'Večera'});
    expect(
      tester.getSemantics(find.text('Večera')),
      isSemantics(
        isButton: true,
        hasCheckedState: true,
        isChecked: true,
        label: 'Večera',
      ),
    );
  });

  testWidgets('TavliExpandable otvara sadržaj dodirom; dugme desno ga ne '
      'otvara', (tester) async {
    var replaced = 0;
    await pump(
      tester,
      TavliExpandable(
        title: 'Ručak',
        subtitle: 'Pasulj',
        trailing: TavliIconButton(
          glyph: TavliIcons.swap,
          semanticLabel: 'Zameni jelo',
          onPressed: () => replaced++,
        ),
        children: const [Text('Sastojci')],
      ),
      disableAnimations: true,
    );
    expect(find.text('Sastojci'), findsNothing);
    await tester.tap(find.byType(TavliIconButton));
    await tester.pump();
    expect(replaced, 1);
    expect(find.text('Sastojci'), findsNothing);

    await tester.tap(find.text('Pasulj'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sastojci'), findsOneWidget);
    await tester.tap(find.text('Ručak'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sastojci'), findsNothing);
  });

  testWidgets('TavliProgressBar: opis za čitač ekrana i tekst ispod', (
    tester,
  ) async {
    await pump(
      tester,
      const TavliProgressBar(
        value: 0.5,
        message: 'Pripremljeno 3 od 6 obroka.',
        semanticLabel: 'Napredak predloga',
      ),
    );
    expect(find.text('Pripremljeno 3 od 6 obroka.'), findsOneWidget);
    expect(find.bySemanticsLabel('Napredak predloga'), findsOneWidget);
  });

  testWidgets('TavliPage: razmaci sa platna na telefonu i računaru', (
    tester,
  ) async {
    const box = Key('box');
    await pump(
      tester,
      const TavliPage(children: [SizedBox(key: box, height: 10)]),
    );
    expect(tester.getTopLeft(find.byKey(box)), const Offset(20, 8));

    await pump(
      tester,
      const TavliPage(wide: true, children: [SizedBox(key: box, height: 10)]),
      size: const Size(1200, 800),
    );
    expect(tester.getTopLeft(find.byKey(box)), const Offset(28, 24));

    await pump(
      tester,
      const TavliPage(
        wide: true,
        maxWidth: TavliWidth.readable,
        children: [SizedBox(key: box, height: 10)],
      ),
      size: const Size(1200, 800),
    );
    expect(tester.getSize(find.byKey(box)).width, TavliWidth.readable);
  });

  test('TavliWidth.side: najviše 300, a najviše trećina sadržaja', () {
    expect(TavliWidth.side(1200), TavliWidth.detail);
    expect(TavliWidth.side(600), 200);
  });
}
