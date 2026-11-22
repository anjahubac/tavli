import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(400, 800),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTavliTheme(TavliMotif.bosiljak, brightness),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Size sizeOf(WidgetTester tester, String text) => tester.getSize(
  find.ancestor(of: find.text(text), matching: find.byType(TavliButton)),
);

BorderRadius? radiusOf(WidgetTester tester, String text) {
  final material = tester.widget<Material>(
    find.ancestor(of: find.text(text), matching: find.byType(Material)).first,
  );
  final shape = material.shape;
  return shape is RoundedRectangleBorder
      ? shape.borderRadius as BorderRadius
      : null;
}

void main() {
  group('TavliButton', () {
    testWidgets('mere iz standarda', (tester) async {
      await pump(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TavliButton.primary(label: 'Glavno', onPressed: () {}),
            TavliButton.secondary(label: 'Sporedno', onPressed: () {}),
            TavliButton.text(label: 'Tekst', onPressed: () {}),
            TavliButton.destructive(label: 'Obriši', onPressed: () {}),
          ],
        ),
      );
      expect(sizeOf(tester, 'Glavno').height, 48);
      expect(sizeOf(tester, 'Sporedno').height, 48);
      expect(sizeOf(tester, 'Tekst').height, 48);
      expect(sizeOf(tester, 'Obriši').height, 48);
      expect(radiusOf(tester, 'Glavno'), BorderRadius.circular(16));
      expect(radiusOf(tester, 'Sporedno'), BorderRadius.circular(16));
      expect(radiusOf(tester, 'Tekst'), BorderRadius.circular(14));

      final style = tester.widget<Text>(find.text('Glavno'));
      final rendered = tester
          .renderObject<RenderParagraph>(find.text('Glavno'))
          .text
          .style;
      expect(style.data, 'Glavno');
      expect(rendered?.fontSize, 15);
      expect(rendered?.fontWeight, FontWeight.w700);
    });

    testWidgets('za brisanje je u boji greške', (tester) async {
      await pump(
        tester,
        TavliButton.destructive(label: 'Obriši', onPressed: () {}),
      );
      final error = buildTavliTheme(
        TavliMotif.bosiljak,
        Brightness.light,
      ).colorScheme.error;
      final color = tester
          .renderObject<RenderParagraph>(find.text('Obriši'))
          .text
          .style
          ?.color;
      expect(color, error);
    });

    testWidgets('dodir i isključeno stanje', (tester) async {
      var taps = 0;
      await pump(
        tester,
        Column(
          children: [
            TavliButton.primary(label: 'Da', onPressed: () => taps++),
            const TavliButton.primary(label: 'Ne', onPressed: null),
          ],
        ),
      );
      await tester.tap(find.text('Da'));
      await tester.tap(find.text('Ne'), warnIfMissed: false);
      expect(taps, 1);
      expect(
        tester.getSemantics(find.text('Ne')),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
    });

    testWidgets('sa ikonicom', (tester) async {
      await pump(
        tester,
        TavliButton.primary(
          label: 'Dodaj recept',
          icon: Icons.add,
          onPressed: () {},
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(sizeOf(tester, 'Dodaj recept').height, 48);
    });
  });

  group('TavliButtonRow', () {
    testWidgets('sporedno pored glavnog je iste visine, 48', (tester) async {
      await pump(
        tester,
        TavliButtonRow(
          children: [
            TavliButton.secondary(label: 'Skuvano', onPressed: () {}),
            TavliButton.primary(label: 'Kuvaj', onPressed: () {}),
          ],
        ),
      );
      expect(sizeOf(tester, 'Skuvano').height, 48);
      expect(sizeOf(tester, 'Kuvaj').height, 48);
    });

    testWidgets('tekstualno pored sporednog je iste visine, 48', (
      tester,
    ) async {
      await pump(
        tester,
        TavliButtonRow(
          children: [
            TavliButton.secondary(label: 'Otkaži', onPressed: () {}),
            TavliButton.text(label: 'Preskoči', onPressed: () {}),
          ],
        ),
      );
      expect(sizeOf(tester, 'Otkaži').height, 48);
      expect(sizeOf(tester, 'Preskoči').height, 48);
    });

    testWidgets('samo tekstualna dugmad su visine 48', (tester) async {
      await pump(
        tester,
        TavliButtonRow(
          children: [
            TavliButton.text(label: 'Otkaži', onPressed: () {}),
            TavliButton.text(label: 'Preskoči', onPressed: () {}),
          ],
        ),
      );
      expect(sizeOf(tester, 'Otkaži').height, 48);
      expect(sizeOf(tester, 'Preskoči').height, 48);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('glavno i sporedno dele širinu, tekst ${scale}x', (
        tester,
      ) async {
        await pump(
          tester,
          SizedBox(
            width: 320,
            child: TavliButtonRow(
              expand: true,
              children: [
                TavliButton.secondary(
                  label: 'Ponovo predloži sve obroke',
                  onPressed: () {},
                ),
                TavliButton.primary(label: 'Kuvaj', onPressed: () {}),
              ],
            ),
          ),
          textScale: scale,
        );
        final a = sizeOf(tester, 'Ponovo predloži sve obroke');
        final b = sizeOf(tester, 'Kuvaj');
        expect(a.height, greaterThanOrEqualTo(48));
        expect(a.height, b.height);
        expect(a.width, b.width);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('u traci sa akcijama sva dugmad su 48', (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 360,
          child: TavliActionBar(
            actions: [
              TavliButton.secondary(label: 'A', onPressed: () {}),
              TavliButton.secondary(label: 'B', onPressed: () {}),
            ],
          ),
        ),
      );
      expect(sizeOf(tester, 'A').height, 48);
      expect(sizeOf(tester, 'B').height, 48);
    });
  });

  group('TavliIconButton', () {
    testWidgets('opis za čitač ekrana, 48 x 48', (tester) async {
      var taps = 0;
      await pump(
        tester,
        TavliIconButton(
          icon: Icons.edit_outlined,
          semanticLabel: 'Izmeni recept',
          onPressed: () => taps++,
        ),
      );
      final box = tester.getSize(find.byType(TavliIconButton));
      expect(box.width, greaterThanOrEqualTo(48));
      expect(box.height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel('Izmeni recept'), findsOneWidget);
      await tester.tap(find.byType(TavliIconButton));
      expect(taps, 1);
    });
  });

  group('TavliTextField', () {
    testWidgets('visina 48, radijus 16, tekst 16, naziv iznad', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 300,
          child: TavliTextField(label: 'Naziv recepta', hint: 'npr. Sarma'),
        ),
      );
      expect(tester.getSize(find.byType(TextField)).height, 48);
      final decorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );
      final border = decorator.decoration.enabledBorder! as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(16));
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).style.fontSize,
        16,
      );
      expect(
        tester.getRect(find.text('Naziv recepta')).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(TextField)).top),
      );
      expect(find.bySemanticsLabel(RegExp('Naziv recepta')), findsWidgets);
    });

    testWidgets('greška ispod polja i crvena ivica', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 300,
          child: TavliTextField(label: 'Količina', errorText: 'Unesi broj'),
        ),
      );
      expect(find.text('Unesi broj'), findsOneWidget);
      final decorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );
      final error = buildTavliTheme(
        TavliMotif.bosiljak,
        Brightness.light,
      ).colorScheme.error;
      expect(
        (decorator.decoration.errorBorder! as OutlineInputBorder)
            .borderSide
            .color,
        error,
      );
    });

    testWidgets('unos i isključeno polje', (tester) async {
      final changes = <String>[];
      await pump(
        tester,
        SizedBox(
          width: 300,
          child: Column(
            children: [
              TavliTextField(label: 'Naziv', onChanged: changes.add),
              const TavliTextField(label: 'Porcije', enabled: false),
            ],
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'Sarma');
      expect(changes, ['Sarma']);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isFalse,
      );
    });
  });

  group('TavliSearchField', () {
    testWidgets('lupa, visina 48, brisanje teksta', (tester) async {
      final changes = <String>[];
      await pump(
        tester,
        SizedBox(
          width: 300,
          child: TavliSearchField(
            hint: 'Pretraži recepte',
            onChanged: changes.add,
          ),
        ),
      );
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(tester.getSize(find.byType(TextField)).height, 48);
      expect(find.bySemanticsLabel('Obriši pretragu'), findsNothing);

      await tester.enterText(find.byType(TextField), 'sarma');
      await tester.pump();
      expect(find.bySemanticsLabel('Obriši pretragu'), findsOneWidget);

      await tester.tap(find.byType(TavliIconButton));
      await tester.pump();
      expect(find.text('sarma'), findsNothing);
      expect(changes, ['sarma', '']);
      expect(find.bySemanticsLabel('Obriši pretragu'), findsNothing);
    });
  });

  group('TavliChoice', () {
    Widget segmented(bool month, ValueChanged<bool> onChanged) =>
        TavliChoice<bool>.segmented(
          options: const [
            TavliOption(false, 'Nedelja'),
            TavliOption(true, 'Mesec'),
          ],
          selected: month,
          onChanged: onChanged,
        );

    Rect segmentRect(WidgetTester tester, String label) => tester.getRect(
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
    );

    testWidgets('segmentno: visina 40, segmenti iste širine', (tester) async {
      await pump(tester, segmented(false, (_) {}));
      final whole = tester.getSize(find.byType(TavliChoice<bool>));
      expect(whole.height, 40);
      final week = segmentRect(tester, 'Nedelja');
      final month = segmentRect(tester, 'Mesec');
      expect(week.width, month.width);
    });

    testWidgets('segmentno: širina se ne menja sa izborom', (tester) async {
      await pump(tester, segmented(false, (_) {}));
      final before = tester.getRect(find.byType(TavliChoice<bool>));
      await pump(tester, segmented(true, (_) {}));
      expect(tester.getRect(find.byType(TavliChoice<bool>)), before);
    });

    testWidgets('segmentno: ne rasteže se u koloni', (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [segmented(false, (_) {})],
          ),
        ),
      );
      expect(tester.getSize(find.byType(IntrinsicWidth)).width, lessThan(360));
    });

    testWidgets('segmentno: izbor i stanje za čitač ekrana', (tester) async {
      bool? picked;
      await pump(tester, segmented(false, (v) => picked = v));
      await tester.tap(find.text('Mesec'));
      expect(picked, isTrue);
      expect(
        tester.getSemantics(find.text('Nedelja')),
        isSemantics(
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          label: 'Nedelja',
        ),
      );
    });

    testWidgets('čipovi: visina 36, radijus 10, izbor', (tester) async {
      int? picked;
      await pump(
        tester,
        TavliChoice<int>.chips(
          options: const [
            TavliOption(1, 'Nedelja 1'),
            TavliOption(2, 'Nedelja 2'),
            TavliOption(0, 'Ceo plan'),
          ],
          selected: 1,
          onChanged: (v) => picked = v,
        ),
      );
      final chip = find.ancestor(
        of: find.text('Ceo plan'),
        matching: find.byType(Material),
      );
      expect(tester.getSize(chip.first).height, 36);
      expect(radiusOf(tester, 'Ceo plan'), BorderRadius.circular(10));
      await tester.tap(find.text('Ceo plan'));
      expect(picked, 0);
    });

    testWidgets('isključen izbor ne reaguje', (tester) async {
      await pump(
        tester,
        const TavliChoice<int>.chips(
          options: [TavliOption(1, 'A'), TavliOption(2, 'B')],
          selected: 1,
          onChanged: null,
        ),
      );
      await tester.tap(find.text('B'));
      expect(
        tester.getSemantics(find.text('B')),
        isSemantics(
          isButton: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          label: 'B',
        ),
      );
    });
  });

  group('TavliCheckRow', () {
    testWidgets('štikliranje, precrtano, visina 52, polje 22', (tester) async {
      var checked = false;
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 320,
            child: TavliCheckRow(
              title: 'Paradajz',
              detail: '1,5 kg',
              checked: checked,
              onChanged: (v) => setState(() => checked = v),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(TavliCheckRow)).height,
        greaterThanOrEqualTo(52),
      );
      final box = find.descendant(
        of: find.byType(TavliCheckRow),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 22 && w.height == 22,
        ),
      );
      expect(box, findsOneWidget);
      TextDecoration? decoration() => tester
          .renderObject<RenderParagraph>(find.text('Paradajz'))
          .text
          .style
          ?.decoration;
      expect(decoration(), isNot(TextDecoration.lineThrough));

      await tester.tap(find.text('Paradajz'));
      await tester.pump();
      expect(checked, isTrue);
      expect(decoration(), TextDecoration.lineThrough);
      expect(find.text('1,5 kg'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(TavliCheckRow)),
        isSemantics(
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          label: 'Paradajz\n1,5 kg',
        ),
      );
    });
  });

  group('TavliCheckRow, lista i detalj', () {
    testWidgets('red bira, polje štiklira; izabran red ima pozadinu', (
      tester,
    ) async {
      var checked = false;
      var selected = 0;
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 400,
            child: TavliCheckRow(
              title: 'Krompir',
              detail: '1,5 kg',
              checked: checked,
              selected: true,
              onChanged: (v) => setState(() => checked = v),
              onSelect: () => selected++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Krompir'));
      await tester.pump();
      expect(selected, 1);
      expect(checked, isFalse);

      final box = find.descendant(
        of: find.byType(TavliCheckRow),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 22 && w.height == 22,
        ),
      );
      await tester.tap(box);
      await tester.pump();
      expect(checked, isTrue);
      expect(selected, 1);

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TavliCheckRow),
              matching: find.byType(Material),
            )
            .first,
      );
      final scheme = Theme.of(tester.element(box)).colorScheme;
      expect(material.color, scheme.primaryContainer);
    });

    testWidgets('dug pritisak i radnja za čitač ekrana', (tester) async {
      var opened = 0;
      await pump(
        tester,
        SizedBox(
          width: 320,
          child: TavliCheckRow(
            title: 'Mleko',
            checked: false,
            onChanged: (_) {},
            onLongPress: () => opened++,
            longPressLabel: 'Za koje obroke',
          ),
        ),
      );
      await tester.longPress(find.text('Mleko'));
      await tester.pump();
      expect(opened, 1);
      final semantics = tester.getSemantics(find.text('Mleko'));
      expect(semantics.getSemanticsData().customSemanticsActionIds, isNotEmpty);
    });

    testWidgets('dugme desno je posebna radnja', (tester) async {
      var checked = false;
      var deleted = 0;
      await pump(
        tester,
        SizedBox(
          width: 320,
          child: TavliCheckRow(
            title: 'Deterdžent',
            checked: checked,
            onChanged: (v) => checked = v,
            trailing: TavliIconButton(
              glyph: TavliIcons.delete,
              semanticLabel: 'Obriši',
              onPressed: () => deleted++,
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Obriši'));
      await tester.pump();
      expect(deleted, 1);
      expect(checked, isFalse);
    });
  });

  group('Tavli ikonice u komponentama', () {
    testWidgets('dugme, dugme sa ikonicom i prazno stanje', (tester) async {
      await pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TavliButton.primary(
              label: 'Prebaci u ostavu (2)',
              glyph: TavliIcons.pantry,
              onPressed: () {},
            ),
            TavliIconButton(
              glyph: TavliIcons.add,
              semanticLabel: 'Dodaj',
              onPressed: () {},
            ),
            const SizedBox(
              height: 320,
              child: TavliEmptyState(
                glyph: TavliIcons.shopping,
                title: 'Nabavka je prazna',
              ),
            ),
          ],
        ),
      );
      expect(find.byType(TavliIcon), findsNWidgets(3));
      expect(find.byType(Icon), findsNothing);
      expect(find.bySemanticsLabel('Dodaj'), findsOneWidget);
    });
  });

  group('TavliSwitchRow', () {
    testWidgets('dodir na red menja vrednost, podnaslov', (tester) async {
      var value = false;
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 340,
            child: TavliSwitchRow(
              title: 'Sakrij brojeve u planu',
              subtitle: 'Kalorije se ne prikazuju',
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      );
      expect(find.text('Kalorije se ne prikazuju'), findsOneWidget);
      expect(
        tester.getSize(find.byType(TavliSwitchRow)).height,
        greaterThanOrEqualTo(52),
      );
      await tester.tap(find.text('Sakrij brojeve u planu'));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(value, isFalse);
    });
  });

  testWidgets('galerija kontrola bez grešaka u rasporedu, tekst 2x', (
    tester,
  ) async {
    for (final b in Brightness.values) {
      await pump(
        tester,
        const SingleChildScrollView(child: TavliGallerySections()),
        textScale: 2,
        brightness: b,
        size: const Size(400, 1200),
      );
      expect(tester.takeException(), isNull);
    }
  });

  group('TavliCodeField', () {
    testWidgets('nalepljen kod: samo cifre, najviše 6, po jedna u polju', (
      tester,
    ) async {
      final code = TextEditingController();
      addTearDown(code.dispose);
      final changes = <String>[];
      await pump(
        tester,
        TavliCodeField(
          label: 'Kod iz poruke',
          controller: code,
          helper: 'Možeš i da nalepiš ceo kod.',
          onChanged: changes.add,
        ),
      );
      expect(find.text('Kod iz poruke'), findsOneWidget);
      expect(find.text('Možeš i da nalepiš ceo kod.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '123 4567');
      await tester.pump();
      expect(code.text, '123456');
      expect(changes.last, '123456');
      for (final d in ['1', '2', '3', '4', '5', '6']) {
        expect(find.text(d), findsOneWidget);
      }
      expect(find.text('7'), findsNothing);
    });

    testWidgets('staje u 280 px i uz tekst 2×', (tester) async {
      final code = TextEditingController();
      addTearDown(code.dispose);
      await pump(
        tester,
        SizedBox(
          width: 240,
          child: TavliCodeField(label: 'Kod iz poruke', controller: code),
        ),
        size: const Size(280, 600),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Kanvas prijave', () {
    testWidgets('tonsko dugme: 48, radijus 16, svetla pozadina', (
      tester,
    ) async {
      await pump(
        tester,
        TavliButton.tonal(label: 'Pošalji mi kod', onPressed: () {}),
      );
      expect(sizeOf(tester, 'Pošalji mi kod').height, 48);
      expect(radiusOf(tester, 'Pošalji mi kod'), BorderRadius.circular(16));
      final scheme = Theme.of(tester.element(find.text('Pošalji mi kod')))
          .colorScheme;
      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('Pošalji mi kod'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, scheme.primaryContainer);
    });

    testWidgets('visoko polje je 60, a kod iz poruke isto toliko', (
      tester,
    ) async {
      final code = TextEditingController();
      addTearDown(code.dispose);
      await pump(
        tester,
        SizedBox(
          width: 360,
          child: Column(
            children: [
              const TavliTextField(label: 'E-pošta', tall: true),
              TavliCodeField(label: 'Kod iz poruke', controller: code),
            ],
          ),
        ),
      );
      expect(tester.getSize(find.byType(TextFormField)).height, 60);
      final box = find.descendant(
        of: find.byType(TavliCodeField),
        matching: find.byType(DecoratedBox),
      );
      expect(tester.getSize(box.first).height, 60);
    });
  });
}
