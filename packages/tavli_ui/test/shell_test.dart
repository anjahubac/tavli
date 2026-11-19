import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/src/gallery/shell_sections.dart';
import 'package:tavli_ui/tavli_ui.dart';

TargetPlatform _target(TavliPlatform p) => switch (p) {
  TavliPlatform.android => TargetPlatform.android,
  TavliPlatform.ios => TargetPlatform.iOS,
  TavliPlatform.macos => TargetPlatform.macOS,
  TavliPlatform.windows => TargetPlatform.windows,
};

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  TavliPlatform platform = TavliPlatform.android,
  Size size = const Size(400, 800),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTavliTheme(
        TavliMotif.bosiljak,
        brightness,
      ).copyWith(platform: _target(platform)),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Ekran sastavljen od svih komponenti kostura, kako ga ekrani slažu.
class _Screen extends StatelessWidget {
  const _Screen({required this.cards});

  final int cards;
  @override
  Widget build(BuildContext context) {
    final desktop = TavliPlatform.of(context).isDesktop;
    final nav = TavliNavigation(
      layout: (desktop
          ? TavliNavigationLayout.side
          : TavliNavigationLayout.bottom),
      destinations: galleryDestinations,
      selectedIndex: 0,
      onSelected: (_) {},
      initials: 'AH',
    );
    final content = ListView(
      children: [
        const TavliPageHeader(overline: 'Petak, 13. novembar', title: 'Plan'),
        for (var i = 0; i < cards; i++) SizedBox(height: 80, child: Text('$i')),
      ],
    );
    if (desktop) {
      return TavliWindowFrame(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            nav,
            Expanded(child: content),
          ],
        ),
      );
    }
    return Column(
      children: [
        const TavliAppBar(initials: 'AH'),
        Expanded(child: content),
        TavliActionBar(
          actions: [
            OutlinedButton(onPressed: () {}, child: const Text('Ponovo')),
            FilledButton(onPressed: () {}, child: const Text('Nabavka')),
          ],
        ),
        nav,
      ],
    );
  }
}

void main() {
  group('TavliAppBar', () {
    testWidgets('Android: naslov levo, avatar 40, visina 64', (tester) async {
      await pump(tester, const TavliAppBar(initials: 'AH'));
      expect(tester.getSize(find.byType(TavliAppBar)).height, 64);
      final avatar = find.text('AH');
      expect(
        tester
            .getSize(
              find.ancestor(of: avatar, matching: find.byType(SizedBox)).first,
            )
            .width,
        40,
      );
      final title = tester.getRect(find.text('Tavli'));
      expect(title.left, 20);
    });

    testWidgets('iOS: naslov u sredini, avatar 36, visina 56', (tester) async {
      await pump(
        tester,
        const TavliAppBar(initials: 'AH'),
        platform: TavliPlatform.ios,
      );
      expect(tester.getSize(find.byType(TavliAppBar)).height, 56);
      final avatar = find.text('AH');
      expect(
        tester
            .getSize(
              find.ancestor(of: avatar, matching: find.byType(SizedBox)).first,
            )
            .width,
        36,
      );
      final bar = tester.getRect(find.byType(TavliAppBar));
      final title = tester.getCenter(find.text('Tavli'));
      expect(title.dx, closeTo(bar.center.dx, 1));
    });

    testWidgets('dodir na avatar otvara profil', (tester) async {
      var opened = false;
      await pump(
        tester,
        TavliAppBar(initials: 'AH', onProfile: () => opened = true),
      );
      await tester.tap(find.bySemanticsLabel('Profil'));
      expect(opened, isTrue);
    });
  });

  group('TavliNavigation', () {
    Future<List<int>> pumpNav(
      WidgetTester tester, {
      TavliNavigationLayout? layout,
      TavliPlatform platform = TavliPlatform.android,
      Size size = const Size(400, 800),
    }) async {
      final taps = <int>[];
      await pump(
        tester,
        Align(
          alignment: Alignment.bottomLeft,
          child: TavliNavigation(
            layout: layout,
            destinations: galleryDestinations,
            selectedIndex: 2,
            onSelected: taps.add,
            initials: 'AH',
          ),
        ),
        platform: platform,
        size: size,
      );
      return taps;
    }

    testWidgets('telefon: donja traka, Početna u sredini', (tester) async {
      final taps = await pumpNav(tester);
      final xs = [
        for (final d in galleryDestinations)
          tester.getCenter(find.text(d.label)).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
      expect(xs[2], closeTo(200, 1));
      await tester.tap(find.text('Recepti'));
      expect(taps, [3]);
      expect(find.text('Profil'), findsNothing);
    });

    testWidgets('izabrani tab je označen za čitač ekrana', (tester) async {
      await pumpNav(tester);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Početna')),
        matchesSemantics(
          label: 'Početna',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('Android 80, iOS viša traka (98)', (tester) async {
      await pumpNav(tester);
      expect(tester.getSize(find.byType(TavliNavigation)).height, 80);
      await pumpNav(tester, platform: TavliPlatform.ios);
      expect(tester.getSize(find.byType(TavliNavigation)).height, 98);
    });

    testWidgets('računar: bočna traka, Početna prva, Profil na dnu', (
      tester,
    ) async {
      final taps = await pumpNav(
        tester,
        platform: TavliPlatform.macos,
        size: const Size(1200, 800),
      );
      expect(tester.getSize(find.byType(TavliNavigation)).width, 220);
      final ys = {
        for (final d in galleryDestinations)
          d.label: tester.getCenter(find.text(d.label)).dy,
      };
      expect(ys['Početna']!, lessThan(ys['Plan']!));
      expect(ys['Plan']!, lessThan(ys['Nabavka']!));
      expect(ys['Nabavka']!, lessThan(ys['Recepti']!));
      expect(ys['Recepti']!, lessThan(ys['Ostava']!));
      expect(
        tester.getCenter(find.text('Profil')).dy,
        greaterThan(ys['Ostava']!),
      );
      expect(tester.getBottomLeft(find.text('Profil')).dy, greaterThan(700));
      // Indeksi ostaju po redosledu iz liste, ne po redosledu na ekranu.
      await tester.tap(find.text('Početna'));
      await tester.tap(find.text('Plan'));
      expect(taps, [2, 0]);
    });

    testWidgets('bez zadatog rasporeda: širok telefon dobija bočnu', (
      tester,
    ) async {
      await pumpNav(tester, size: const Size(800, 600));
      expect(tester.getSize(find.byType(TavliNavigation)).width, 220);
    });

    testWidgets('dodir na Profil u bočnoj traci', (tester) async {
      var opened = false;
      await pump(
        tester,
        Row(
          children: [
            TavliNavigation(
              layout: TavliNavigationLayout.side,
              destinations: galleryDestinations,
              selectedIndex: null,
              onSelected: (_) {},
              initials: 'AH',
              onProfile: () => opened = true,
            ),
          ],
        ),
        size: const Size(1200, 800),
      );
      await tester.tap(find.text('Profil'));
      expect(opened, isTrue);
    });
  });

  group('TavliPageHeader', () {
    testWidgets('telefon 28, računar 26, akcije desno', (tester) async {
      await pump(
        tester,
        const TavliPageHeader(overline: 'Petak', title: 'Danas'),
      );
      expect(tester.widget<Text>(find.text('Danas')).style!.fontSize, 28);
      expect(find.text('Petak'), findsOneWidget);

      await pump(
        tester,
        TavliPageHeader(
          title: 'Recepti',
          actions: [
            FilledButton(onPressed: () {}, child: const Text('Dodaj recept')),
          ],
        ),
        platform: TavliPlatform.windows,
        size: const Size(1200, 800),
      );
      expect(tester.widget<Text>(find.text('Recepti')).style!.fontSize, 26);
      final title = tester.getCenter(find.text('Recepti'));
      final action = tester.getCenter(find.text('Dodaj recept'));
      expect(action.dx, greaterThan(1000));
      expect(action.dy, closeTo(title.dy, 4));
    });
  });

  group('TavliActionBar', () {
    testWidgets('ostaje na istom mestu kada se promeni sadržaj', (
      tester,
    ) async {
      await pump(tester, const _Screen(cards: 2));
      final week = tester.getRect(find.byType(TavliActionBar));
      await pump(tester, const _Screen(cards: 20));
      final month = tester.getRect(find.byType(TavliActionBar));
      expect(month, week);
      // Odmah iznad navigacije.
      expect(week.bottom, tester.getRect(find.byType(TavliNavigation)).top);
    });

    testWidgets('dugmad dele širinu', (tester) async {
      await pump(tester, const _Screen(cards: 1));
      final a = tester.getSize(find.byType(OutlinedButton));
      final b = tester.getSize(find.byType(FilledButton));
      expect(a.width, b.width);
      expect(a.height, 56);
      expect(b.height, 56);
    });

    testWidgets('tekst dugmadi staje u jedan red na telefonu', (tester) async {
      await pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: TavliActionBar(
            actions: [
              OutlinedButton(
                onPressed: () {},
                child: const Text('Ponovo predloži'),
              ),
              FilledButton(
                onPressed: () {},
                child: const Text('Otvori nabavku'),
              ),
            ],
          ),
        ),
        size: const Size(360, 800),
      );
      final line = tester.getSize(find.text('Otvori nabavku')).height;
      expect(tester.getSize(find.text('Ponovo predloži')).height, line);
      expect(line, lessThan(30));
    });
  });

  testWidgets('TavliFloatingButton: visina 56, tekst i dodir', (tester) async {
    var pressed = false;
    await pump(
      tester,
      Center(
        child: TavliFloatingButton(
          icon: Icons.add,
          label: 'Dodaj recept',
          onPressed: () => pressed = true,
        ),
      ),
    );
    expect(tester.getSize(find.byType(TavliFloatingButton)).height, 56);
    await tester.tap(find.text('Dodaj recept'));
    expect(pressed, isTrue);
  });

  group('TavliWindowFrame', () {
    for (final p in TavliPlatform.values) {
      testWidgets('naslovna traka samo na Windows-u: ${p.name}', (
        tester,
      ) async {
        await pump(
          tester,
          const TavliWindowFrame(child: Text('sadržaj')),
          platform: p,
          size: const Size(1200, 800),
        );
        expect(
          find.text('Tavli'),
          p == TavliPlatform.windows ? findsOneWidget : findsNothing,
        );
        expect(
          tester.getTopLeft(find.text('sadržaj')).dy,
          p == TavliPlatform.windows
              ? TavliWindowFrame.windowsTitleBarHeight
              : 0,
        );
      });
    }
  });

  // Ceo kostur na telefonu i računaru, sa tekstom 1x i 2x, svetlo i tamno.
  for (final platform in TavliPlatform.values) {
    for (final size in const [Size(400, 800), Size(1200, 800)]) {
      for (final scale in const [1.0, 2.0]) {
        for (final brightness in Brightness.values) {
          testWidgets('kostur bez grešaka u rasporedu: ${platform.name} '
              '${size.width.toInt()}, ${scale}x, ${brightness.name}', (
            tester,
          ) async {
            await pump(
              tester,
              const _Screen(cards: 6),
              platform: platform,
              size: size,
              textScale: scale,
              brightness: brightness,
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
