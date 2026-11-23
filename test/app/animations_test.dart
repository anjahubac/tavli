import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/app/animations/all_bought.dart';
import 'package:tavli/app/animations/egg_timer.dart';
import 'package:tavli/app/animations/empty_basket.dart';
import 'package:tavli/app/animations/empty_fridge.dart';
import 'package:tavli/app/animations/empty_tabs.dart';
import 'package:tavli/app/animations/intro_overlay.dart';
import 'package:tavli/app/animations/photo_scan.dart';
import 'package:tavli/app/animations/simmering_pot.dart';
import 'package:tavli/app/animations/spoon_refresh.dart';
import 'package:tavli_ui/tavli_ui.dart';

/// Widget u aplikaciji sa temom; [still] = sistem traži smanjeno kretanje.
Future<void> pumpArt(
  WidgetTester tester,
  Widget child, {
  bool still = false,
  TavliMotif theme = TavliMotif.bosiljak,
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
    'Lonac koji krčka': const SimmeringPot(),
    'Sve je kupljeno': const AllBoughtArt(),
    'Prazan frižider': const EmptyFridge(),
    'Postavljen sto': const EmptyTable(),
    'Obrok u nedelji': const EmptyWeek(),
    'Prazna kuvarica': const EmptyCookbook(),
    'Prazna korpa za nabavku': const EmptyBasket(),
    'Varjača u loncu': const SpoonPot(),
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
        for (final theme in TavliMotif.values) {
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
    for (final w in const [
      AllBoughtArt(),
      EmptyFridge(),
      EmptyTable(),
      EmptyWeek(),
      EmptyCookbook(),
      EmptyBasket(),
    ]) {
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

  testWidgets('skeniranje: bez čipa ispod slike, pa sastojci jedan po '
      'jedan', (tester) async {
    await pumpArt(
      tester,
      const PhotoScan(photo: SizedBox.expand(), scanning: true),
    );
    expect(find.text('Tražim sastojke…'), findsNothing);

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

  group('uvodni motiv tokom učitavanja', () {
    final logo = find.byWidgetPredicate(
      (widget) => widget is Image && widget.semanticLabel == 'Tavli',
    );

    for (final motif in TavliMotif.values) {
      for (final brightness in Brightness.values) {
        testWidgets('${motif.name} ${brightness.name}: motiv i logotip', (
          tester,
        ) async {
          await pumpArt(
            tester,
            const IntroScreen(),
            theme: motif,
            brightness: brightness,
            still: true,
          );
          expect(find.bySemanticsLabel('Tavli'), findsOneWidget);
          expect(
            tester.widget<Image>(logo).color,
            Theme.of(tester.element(logo)).colorScheme.onSurface,
          );
          expect(tester.hasRunningAnimations, isFalse);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Image &&
                  widget.image is AssetImage &&
                  (widget.image as AssetImage).assetName.contains(
                    'assets/branding/intro/${motif.name}-',
                  ),
            ),
            findsNothing,
          );
        });
      }
    }
    for (final size in [const Size(320, 568), const Size(1200, 760)]) {
      testWidgets('logotip na širini ${size.width} i sa 2× tekstom', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();

        await pumpArt(tester, const IntroScreen(), still: true);

        expect(logo, findsOneWidget);
        final image = find.descendant(
          of: logo,
          matching: find.byType(RawImage),
        );
        expect(tester.widget<RawImage>(image).image, isNull);
        final bounds = tester.getRect(logo);
        expect(bounds.right, lessThanOrEqualTo(size.width));
        expect(bounds.height, closeTo(bounds.width * 250 / 629, 0.01));
        expect(tester.takeException(), isNull);
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

  testWidgets('prazni ekrani: crtež raste sa širinom, najviše 200', (
    tester,
  ) async {
    Future<double> widthIn(double box) async {
      await pumpArt(
        tester,
        SizedBox(width: box, child: const EmptyTable()),
        still: true,
      );
      return tester.getSize(find.byType(MotionCanvas)).width;
    }

    expect(await widthIn(250), closeTo(150, 0.01));
    expect(await widthIn(900), 200);
  });
}
