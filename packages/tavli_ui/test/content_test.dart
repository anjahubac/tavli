import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(400, 800),
  TargetPlatform platform = TargetPlatform.android,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTavliTheme(
        TavliMotif.bosiljak,
        Brightness.light,
      ).copyWith(platform: platform),
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: reduceMotion),
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

BorderRadius radiusOfMaterial(WidgetTester tester, Finder material) {
  final shape = tester.widget<Material>(material).shape!;
  return (shape as RoundedRectangleBorder).borderRadius as BorderRadius;
}

void main() {
  group('TavliCard', () {
    testWidgets('radijus 20, kompaktna 14, bez senke', (tester) async {
      await pump(
        tester,
        const Column(
          children: [
            TavliCard(key: ValueKey('plain'), child: Text('Obična')),
            TavliCard(
              key: ValueKey('compact'),
              variant: TavliCardVariant.compact,
              child: Text('Kompaktna'),
            ),
          ],
        ),
      );
      Finder materialOf(String key) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Material),
      );
      expect(
        radiusOfMaterial(tester, materialOf('plain').first),
        BorderRadius.circular(20),
      );
      expect(
        radiusOfMaterial(tester, materialOf('compact').first),
        BorderRadius.circular(14),
      );
      expect(tester.widget<Material>(materialOf('plain').first).elevation, 0);
    });

    testWidgets('skuvana kartica ima zelenu kvačicu', (tester) async {
      await pump(
        tester,
        const TavliCard(
          variant: TavliCardVariant.cooked,
          child: Text('Ovsena kaša'),
        ),
      );
      expect(find.byType(TavliTag), findsOneWidget);
      expect(find.bySemanticsLabel('Skuvano'), findsOneWidget);
    });

    testWidgets('dodir na karticu', (tester) async {
      var taps = 0;
      await pump(
        tester,
        TavliCard(onTap: () => taps++, child: const Text('Sarma')),
      );
      await tester.tap(find.text('Sarma'));
      expect(taps, 1);
    });

    testWidgets('kartice u istom redu su iste visine', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 360,
          child: TavliCardRow(
            children: [
              TavliCard(key: ValueKey('a'), child: Text('Čorba')),
              TavliCard(
                key: ValueKey('b'),
                child: Text('Piletina sa povrćem iz rerne i krompirom'),
              ),
            ],
          ),
        ),
      );
      final a = tester.getSize(find.byKey(const ValueKey('a')));
      final b = tester.getSize(find.byKey(const ValueKey('b')));
      expect(a.height, b.height);
      expect(a.width, b.width);
    });
  });

  group('TavliListRow', () {
    testWidgets('red bez količine prikazuje samo naziv', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 360,
          child: TavliListGroup(
            children: [
              TavliListRow(title: 'Brašno', quantity: '1 kg'),
              TavliListRow(title: 'So'),
              TavliListRow(title: 'Biber', quantity: ''),
            ],
          ),
        ),
      );
      expect(find.text('1 kg'), findsOneWidget);
      Iterable<Text> textsIn(String title) => tester.widgetList<Text>(
        find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(TavliListRow),
          ),
          matching: find.byType(Text),
        ),
      );
      expect(textsIn('So').map((t) => t.data), ['So']);
      expect(textsIn('Biber').map((t) => t.data), ['Biber']);
      expect(
        tester.getSize(find.byType(TavliListRow).first).height,
        greaterThanOrEqualTo(52),
      );
    });

    testWidgets('grupa ima razdelnike samo između redova', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 360,
          child: TavliListGroup(
            children: [
              TavliListRow(title: 'A'),
              TavliListRow(title: 'B'),
              TavliListRow(title: 'C'),
            ],
          ),
        ),
      );
      expect(find.byType(TavliDivider), findsNWidgets(2));
      expect(
        radiusOfMaterial(
          tester,
          find
              .descendant(
                of: find.byType(TavliListGroup),
                matching: find.byType(Material),
              )
              .first,
        ),
        BorderRadius.circular(16),
      );
    });

    testWidgets('prevlačenje otkriva „Ukloni“ širine 96', (tester) async {
      var removed = 0;
      await pump(
        tester,
        SizedBox(
          width: 360,
          child: TavliListGroup(
            children: [
              TavliListRow(
                title: 'Jaja',
                quantity: '10 kom',
                onRemove: () => removed++,
              ),
            ],
          ),
        ),
      );
      await tester.drag(find.text('Jaja'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      final button = find.text('Ukloni');
      expect(
        tester.getSize(
          find.ancestor(of: button, matching: find.byType(SizedBox)).first,
        ),
        const Size(96, 52),
      );
      // Red je pomeren tačno za širinu dugmeta.
      expect(tester.getTopLeft(find.text('Jaja')).dx, lessThan(20 + 14 - 90));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(removed, 1);
    });

    testWidgets('kratko prevlačenje se vraća', (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 360,
          child: TavliListGroup(
            children: [TavliListRow(title: 'Jaja', onRemove: () {})],
          ),
        ),
      );
      final start = tester.getTopLeft(find.text('Jaja'));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Jaja')),
      );
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Jaja')), start);
    });

    testWidgets('čitač ekrana dobija akciju „Ukloni“', (tester) async {
      final semantics = tester.ensureSemantics();
      var removed = 0;
      await pump(
        tester,
        SizedBox(
          width: 360,
          child: TavliListRow(title: 'Jaja', onRemove: () => removed++),
        ),
      );
      final node = tester.getSemantics(find.text('Jaja'));
      final data = node.getSemanticsData();
      expect(data.customSemanticsActionIds, isNotEmpty);
      final id = data.customSemanticsActionIds!.single;
      expect(CustomSemanticsAction.getAction(id)?.label, 'Ukloni');
      node.owner!.performAction(node.id, SemanticsAction.customAction, id);
      await tester.pumpAndSettle();
      expect(removed, 1);
      semantics.dispose();
    });

    testWidgets('strelica i dodir', (tester) async {
      var taps = 0;
      await pump(
        tester,
        SizedBox(
          width: 360,
          child: TavliListRow(
            leading: const TavliThumbnail.row(),
            title: 'Sarma',
            subtitle: '2 h',
            showChevron: true,
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      await tester.tap(find.text('Sarma'));
      expect(taps, 1);
    });
  });

  group('TavliDataTable', () {
    testWidgets('zaglavlje, redovi i prazna ćelija', (tester) async {
      var tapped = '';
      await pump(
        tester,
        SizedBox(
          width: 600,
          child: TavliDataTable(
            columns: const [
              TavliColumn('Namirnica', flex: 3),
              TavliColumn('Količina', alignEnd: true),
            ],
            rows: [
              TavliTableRow(const [
                'Brašno',
                '1 kg',
              ], onTap: () => tapped = 'b'),
              const TavliTableRow(['So', '']),
            ],
          ),
        ),
        size: const Size(800, 600),
      );
      expect(find.text('Namirnica'), findsOneWidget);
      expect(find.text('Količina'), findsOneWidget);
      expect(find.byType(TavliDivider), findsNWidgets(2));
      expect(tester.widget<Text>(find.text('1 kg')).textAlign, TextAlign.end);
      await tester.tap(find.text('Brašno'));
      expect(tapped, 'b');
    });
  });

  group('TavliNotice', () {
    testWidgets('boje značenja i link', (tester) async {
      var opened = 0;
      await pump(
        tester,
        TavliNotice(
          tone: TavliNoticeTone.warning,
          message: 'Za sutrašnji ručak fale 2 namirnice.',
          linkLabel: 'Nabavka',
          onLink: () => opened++,
        ),
      );
      final context = tester.element(find.byType(TavliNotice));
      final warning = TavliStatusColors.of(context).warning;
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(TavliNotice),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, warning.background);
      expect(decoration.border, isNull);
      expect(decoration.borderRadius, BorderRadius.circular(16));
      expect(
        tester.widget<Text>(find.text('Nabavka')).style?.color,
        warning.foreground,
      );
      await tester.tap(find.text('Nabavka'));
      expect(opened, 1);
    });

    testWidgets('greška koristi boje greške iz teme', (tester) async {
      await pump(
        tester,
        const TavliNotice(tone: TavliNoticeTone.error, message: 'Greška'),
      );
      final c = Theme.of(tester.element(find.byType(TavliNotice))).colorScheme;
      expect(
        tester.widget<Text>(find.text('Greška')).style?.color,
        c.onErrorContainer,
      );
    });
  });

  group('TavliSectionHeader', () {
    testWidgets('dve varijante; čitač ekrana čita izvorni tekst', (
      tester,
    ) async {
      await pump(
        tester,
        const Column(
          children: [
            TavliSectionHeader('Na umu'),
            TavliSectionHeader(
              'Kupljeno · 2',
              style: TavliSectionHeaderStyle.bold,
            ),
          ],
        ),
      );
      expect(find.text('NA UMU'), findsOneWidget);
      expect(find.text('Kupljeno · 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Na umu'), findsOneWidget);
    });
  });

  group('Sličica, avatar i oznaka', () {
    testWidgets('mere iz standarda', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TavliThumbnail.row(key: ValueKey('row')),
              TavliThumbnail.banner(key: ValueKey('banner')),
              TavliAvatar(key: ValueKey('avatar'), initials: 'AH'),
              TavliTag.cooked(key: ValueKey('tag')),
            ],
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('row'))),
        const Size(56, 56),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('banner'))),
        const Size(300, 120),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('avatar'))),
        const Size(40, 40),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('tag'))),
        const Size(18, 18),
      );
      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byKey(const ValueKey('row')),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(14));
    });

    testWidgets('avatar je 36 na iOS-u', (tester) async {
      await pump(
        tester,
        const TavliAvatar(key: ValueKey('a'), initials: 'AH'),
        platform: TargetPlatform.iOS,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('a'))),
        const Size(36, 36),
      );
    });
  });

  group('Stanja ekrana', () {
    testWidgets('prazan ekran sa akcijom', (tester) async {
      var added = 0;
      await pump(
        tester,
        SizedBox(
          width: 360,
          child: TavliEmptyState(
            icon: Icons.menu_book_outlined,
            title: 'Još nema recepata',
            message: 'Dodaj prvi recept.',
            action: TavliButton.primary(
              label: 'Dodaj recept',
              onPressed: () => added++,
            ),
          ),
        ),
      );
      expect(find.text('Još nema recepata'), findsOneWidget);
      await tester.tap(find.text('Dodaj recept'));
      expect(added, 1);
    });

    testWidgets('učitavanje miruje kad se traži smanjeno kretanje', (
      tester,
    ) async {
      await pump(
        tester,
        const TavliLoading(message: 'Pravim recept…'),
        reduceMotion: true,
      );
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, isNotNull);
      expect(find.bySemanticsLabel('Pravim recept…'), findsOneWidget);
    });

    testWidgets('učitavanje se okreće', (tester) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTavliTheme(TavliMotif.bosiljak, Brightness.light),
          home: const Scaffold(body: TavliLoading()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, isNull);
      expect(find.bySemanticsLabel('Učitavanje'), findsOneWidget);
    });
  });
}
