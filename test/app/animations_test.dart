import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
    themeAnimationStyle: AnimationStyle.noAnimation,
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
    expect(opacityOf('Pirinač'), lessThan(opacityOf('Kupus')));
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

  testWidgets('smanjeno kretanje završava aktivnu kvačicu odmah', (
    tester,
  ) async {
    await pumpArt(tester, const AnimatedCheckmark(checked: false));
    await pumpArt(tester, const AnimatedCheckmark(checked: true));
    await tester.pump(const Duration(milliseconds: 50));
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
    expect(tester.hasRunningAnimations, isFalse);
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
    expect(scale(2), inExclusiveRange(1, 1.081));
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

  testWidgets('smanjeno kretanje prekida i uklanja aktivan let čipa', (
    tester,
  ) async {
    final from = GlobalKey();
    final to = GlobalKey();
    await pumpArt(
      tester,
      Column(
        children: [
          SizedBox(key: from, width: 20, height: 20),
          const SizedBox(height: 200),
          Icon(Icons.shopping_basket, key: to),
        ],
      ),
    );
    var completed = false;
    final flight = flyChipToTarget(
      context: tester.element(find.byKey(from)),
      from: from,
      to: to,
      label: 'Luk',
    ).then((_) => completed = true);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Luk'), findsOneWidget);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    await tester.pump();
    expect(completed, isTrue);
    expect(find.text('Luk'), findsNothing);
    await flight;
  });

  group('uvodni motiv tokom učitavanja', () {
    for (final theme in TavliTheme.values) {
      testWidgets('${theme.label}: prikazuje aktivan motiv', (tester) async {
        await pumpArt(tester, const IntroScreen(), theme: theme, still: true);
        expect(find.text('Tavli'), findsOneWidget);
        expect(
          find.bySemanticsLabel(IntroMotif.labelFor(theme)),
          findsOneWidget,
        );
        expect(tester.hasRunningAnimations, isFalse);
      });
    }
  });

  testWidgets('20 prepoznatih sastojaka vidljivo je unutar 360 ms', (
    tester,
  ) async {
    final names = [for (var i = 0; i < 20; i++) 'Sastojak $i'];
    await pumpArt(
      tester,
      ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
        child: SingleChildScrollView(
          child: PhotoScan(
            photo: const SizedBox.expand(),
            scanning: false,
            ingredients: names,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 360));
    for (final name in names) {
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.text(name), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, 1);
    }
    // Sadržaj je već vidljiv na 360 ms; kontroler prijavljuje završetak
    // na prvom otkucaju posle tačne granice trajanja (Flutter isDone koristi >).
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('smanjeno kretanje zaustavlja već pokrenut bedž', (tester) async {
    Widget badge(int n) => BumpBadge(count: n, child: const Icon(Icons.abc));
    await pumpArt(tester, badge(1));
    await pumpArt(tester, badge(2));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.hasRunningAnimations, isTrue);
    await pumpArt(tester, badge(2), still: true);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    final transform = tester.widget<Transform>(
      find.ancestor(of: find.text('2'), matching: find.byType(Transform)).first,
    );
    expect(transform.transform.getMaxScaleOnAxis(), 1);
  });

  testWidgets('poruke lonca se ne menjaju u neaktivnom tabu', (tester) async {
    await pumpArt(
      tester,
      const TickerMode(enabled: false, child: SimmeringPot()),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Seckam luk…'), findsOneWidget);
    await pumpArt(
      tester,
      const TickerMode(enabled: true, child: SimmeringPot()),
    );
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Dodajem začine…'), findsOneWidget);
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

  test('svetlo u frižideru se pali postepeno bez treperenja', () {
    var previous = 0.0;
    for (var i = 0; i <= 100; i++) {
      final light = fridgeLight(i / 100);
      expect(light, greaterThanOrEqualTo(previous));
      previous = light;
    }
    expect(fridgeLight(0), 0);
    expect(fridgeLight(1), 1);
  });
}
