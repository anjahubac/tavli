import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/app/animations/egg_timer.dart';
import 'package:tavli/app/animations/empty_fridge.dart';
import 'package:tavli/app/animations/ingredient_check.dart';
import 'package:tavli/app/animations/intro_motif.dart';
import 'package:tavli/app/animations/intro_overlay.dart';
import 'package:tavli/app/animations/photo_scan.dart';
import 'package:tavli/app/animations/plate_drop.dart';
import 'package:tavli/app/animations/shopping_bag.dart';
import 'package:tavli/app/animations/simmering_pot.dart';
import 'package:tavli/app/animations/spoon_refresh.dart';
import 'package:tavli/app/theme/app_theme.dart';
import 'package:tavli/domain/theme_choice.dart';

/// Widget u aplikaciji sa temom; [still] = sistem traži smanjeno kretanje.
Future<void> pumpArt(
  WidgetTester tester,
  Widget child, {
  bool still = false,
  TavliTheme theme = TavliTheme.bosiljak,
  Brightness brightness = Brightness.light,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildTavliTheme(theme, brightness),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  ),
);

void main() {
  final pieces = <String, Widget>{
    'Grančica bosiljka': const IntroMotif(motif: TavliTheme.bosiljak),
    'Cvet šafrana': const IntroMotif(motif: TavliTheme.safran),
    'Borovnice padaju u činiju': const IntroMotif(motif: TavliTheme.borovnica),
    'Lonac koji krčka': const SimmeringPot(),
    'Puna kesa za kupovinu': const ShoppingBagFull(),
    'Prazan frižider': const EmptyFridge(),
    'Varjača u loncu': const SpoonPot(),
    'Recept na tanjiru': const PlatePlanDrop(),
    'Jaje se kuva': const EggTimer(),
    'Skeniranje fotografije': const PhotoScan(
      photo: SizedBox.expand(),
      scanning: true,
    ),
  };

  group('svaka animacija', () {
    for (final MapEntry(key: label, value: widget) in pieces.entries) {
      testWidgets('$label: radi i ima opis za čitač ekrana', (tester) async {
        await pumpArt(tester, widget);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.bySemanticsLabel(label), findsOneWidget);
        expect(tester.hasRunningAnimations, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$label: smanjeno kretanje → mirna slika', (tester) async {
        await pumpArt(tester, widget, still: true);
        expect(tester.hasRunningAnimations, isFalse);
        expect(find.bySemanticsLabel(label), findsOneWidget);
      });

      testWidgets('$label: iscrtava se u svih 6 tema', (tester) async {
        for (final theme in TavliTheme.values) {
          for (final b in Brightness.values) {
            await pumpArt(tester, widget, theme: theme, brightness: b);
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull);
          }
        }
      });
    }
  });

  testWidgets('jednokratne animacije stanu na završnoj slici', (tester) async {
    for (final w in const [ShoppingBagFull(), EmptyFridge(), PlatePlanDrop()]) {
      await pumpArt(tester, w);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    }
  });

  testWidgets('lonac menja poruke; sa smanjenim kretanjem ostaje prva', (
    tester,
  ) async {
    await pumpArt(tester, const SimmeringPot());
    expect(find.text('Seckam luk…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Dodajem začine…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Mešam…'), findsOneWidget);

    await pumpArt(tester, SimmeringPot(key: UniqueKey()), still: true);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Seckam luk…'), findsOneWidget);
  });

  testWidgets('skeniranje: čip "Tražim sastojke…", pa sastojci jedan po '
      'jedan', (tester) async {
    await pumpArt(
      tester,
      const PhotoScan(photo: SizedBox.expand(), scanning: true),
    );
    expect(find.text('Tražim sastojke…'), findsOneWidget);

    await pumpArt(
      tester,
      const PhotoScan(
        photo: SizedBox.expand(),
        scanning: false,
        ingredients: ['Kupus', 'Meso', 'Pirinač'],
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    double opacityOf(String name) => tester
        .widget<Opacity>(
          find.ancestor(of: find.text(name), matching: find.byType(Opacity)),
        )
        .opacity;
    expect(opacityOf('Kupus'), greaterThan(0));
    expect(opacityOf('Pirinač'), 0);
    await tester.pumpAndSettle();
    for (final n in ['Kupus', 'Meso', 'Pirinač']) {
      expect(opacityOf(n), 1);
    }
    expect(find.text('Tražim sastojke…'), findsNothing);
  });

  testWidgets('kvačica se iscrtava do kraja', (tester) async {
    double progress() =>
        (tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byType(AnimatedCheckmark),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as CheckPainter)
            .t;

    await pumpArt(tester, const AnimatedCheckmark(checked: false));
    expect(progress(), 0);
    await pumpArt(tester, const AnimatedCheckmark(checked: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(progress(), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(progress(), 1);
  });

  testWidgets('kvačica sa smanjenim kretanjem odmah gotova', (tester) async {
    await pumpArt(tester, const AnimatedCheckmark(checked: false), still: true);
    await pumpArt(tester, const AnimatedCheckmark(checked: true), still: true);
    await tester.pump();
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(AnimatedCheckmark),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as CheckPainter;
    expect(painter.t, 1);
  });

  testWidgets('bedž poskoči kad broj poraste, a ne kad padne', (tester) async {
    Widget badge(int n) => BumpBadge(count: n, child: const Icon(Icons.abc));
    double scale(int n) => tester
        .widget<Transform>(
          find
              .ancestor(of: find.text('$n'), matching: find.byType(Transform))
              .first,
        )
        .transform
        .getMaxScaleOnAxis();

    await pumpArt(tester, badge(1));
    await pumpArt(tester, badge(2));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(2), greaterThan(1.2));
    await tester.pumpAndSettle();
    expect(scale(2), closeTo(1, 0.001));

    await pumpArt(tester, badge(1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(1), closeTo(1, 0.001));

    await pumpArt(tester, badge(1), still: true);
    await pumpArt(tester, badge(3), still: true);
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(3), closeTo(1, 0.001));
  });

  testWidgets('čip leti do ikone Kupovine i nestane', (tester) async {
    final from = GlobalKey();
    final to = GlobalKey();
    await pumpArt(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(key: from, width: 20, height: 20),
          const SizedBox(height: 200),
          Icon(Icons.shopping_basket, key: to),
        ],
      ),
    );
    final done = flyChipToTarget(
      context: tester.element(find.byKey(from)),
      from: from,
      to: to,
      label: 'Mleveno meso',
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Mleveno meso'), findsOneWidget);
    await tester.pumpAndSettle();
    await done;
    expect(find.text('Mleveno meso'), findsNothing);
  });

  group('uvod', () {
    for (final theme in TavliTheme.values) {
      testWidgets('${theme.label}: motiv teme, nestane posle ≈1,8 s', (
        tester,
      ) async {
        await pumpArt(
          tester,
          const IntroOverlay(child: Text('Aplikacija')),
          theme: theme,
        );
        expect(find.text('Tavli'), findsOneWidget);
        expect(
          find.bySemanticsLabel(IntroMotif.labelFor(theme)),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 1800));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Tavli'), findsNothing);
        expect(find.text('Aplikacija'), findsOneWidget);
      });
    }

    testWidgets('dodir preskače uvod', (tester) async {
      await pumpArt(tester, const IntroOverlay(child: Text('Aplikacija')));
      await tester.tap(find.text('Tavli'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Tavli'), findsNothing);
    });

    testWidgets('isključen uvod se ne prikazuje', (tester) async {
      await pumpArt(
        tester,
        const IntroOverlay(enabled: false, child: Text('Aplikacija')),
      );
      expect(find.text('Tavli'), findsNothing);
    });
  });

  testWidgets('povlačenje nadole: varjača meša dok traje osvežavanje', (
    tester,
  ) async {
    var refreshed = 0;
    await pumpArt(
      tester,
      SpoonRefresh(
        onRefresh: () async {
          refreshed++;
          await Future<void>.delayed(const Duration(seconds: 1));
        },
        child: ListView(
          children: const [SizedBox(height: 600, child: Text('Lista'))],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Varjača u loncu'), findsNothing);
    await tester.fling(find.text('Lista'), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('Varjača u loncu'), findsOneWidget);
    expect(refreshed, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Varjača u loncu'), findsNothing);
  });

  test('tajmer: format m:ss', () {
    expect(EggTimer.format(const Duration(minutes: 6)), '6:00');
    expect(EggTimer.format(const Duration(minutes: 1, seconds: 5)), '1:05');
  });

  test('svetlo u frižideru treperi pa ostaje upaljeno', () {
    expect(fridgeLight(0.1), 0);
    final flicker = [for (var t = 0.4; t < 0.78; t += 0.02) fridgeLight(t)];
    expect(flicker, contains(lessThan(0.5)));
    expect(fridgeLight(1), 1);
  });
}
