import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/app/theme/app_theme.dart';
import 'package:tavli/domain/theme_choice.dart';
import 'package:tavli/features/settings/animations_gallery_screen.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('galerija prikazuje svih devet animacija po imenu', (
    tester,
  ) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTavliTheme(TavliTheme.bosiljak, Brightness.light),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const AnimationsGalleryScreen(),
          ),
        ),
      ),
    );
    expect(animationNames, hasLength(11)); // uvod ×3 + 8
    for (final name in animationNames) {
      await tester.scrollUntilVisible(
        find.text(name),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(name), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  for (final reduced in [true, false]) {
    testWidgets(
      'sastojci (smanjeno kretanje: $reduced): štikliran = imam; ponovno "Dodaj u kupovinu" '
      'dodaje samo razliku; "imam" skida stavku',
      (tester) async {
        tester.view.physicalSize = const Size(400, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTavliTheme(TavliTheme.bosiljak, Brightness.light),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reduced),
                child: const TickerMode(
                  enabled: false,
                  child: AnimationsGalleryScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.scrollUntilVisible(
          find.text('Kupovina'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        Future<void> tap(String text) async {
          await tester.ensureVisible(find.text(text));
          await tester.pumpAndSettle();
          await tester.tap(find.text(text));
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
        }

        int badge() => find.text('1').evaluate().isNotEmpty
            ? 1
            : find.text('2').evaluate().isNotEmpty
            ? 2
            : 0;

        // 3 stvari, imam 2 (meso je već štiklirano, štikliram i luk).
        expect(find.text('Dodaj u kupovinu (2)'), findsOneWidget);
        await tap('Crni luk');
        expect(find.text('imam'), findsNWidgets(2));
        expect(find.text('Dodaj u kupovinu (1)'), findsOneWidget);
        expect(badge(), 0); // štikliranje ne dira kupovinu

        await tap('Dodaj u kupovinu (1)');
        expect(badge(), 1);
        expect(find.text('Sve je u kupovini'), findsOneWidget);

        // Ipak nemam luk: dodaje se samo on, krompir se ne duplira.
        await tap('Crni luk');
        expect(find.text('Dodaj u kupovinu (1)'), findsOneWidget);
        await tap('Dodaj u kupovinu (1)');
        expect(badge(), 2);
        expect(find.text('Dodato u nabavku: 1'), findsOneWidget);
        expect(find.text('Sve je u kupovini'), findsOneWidget);

        // Ipak imam luk: tiho izlazi iz kupovine.
        await tap('Crni luk');
        expect(badge(), 1);
        expect(find.text('Sve je u kupovini'), findsOneWidget);
      },
    );
  }

  testTavli('Ostava i Nabavka imaju animirana prazna stanja', (tester) async {
    await pumpTavli(tester);
    await tester.tap(find.text('Ostava'));
    await tester.pumpAndSettle();
    expect(find.text('Još nema unetih namirnica'), findsOneWidget);
    expect(
      find.text('Ovde ćeš pratiti namirnice koje imaš kod kuće.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Prazan frižider'), findsOneWidget);

    await tester.tap(find.text('Nabavka'));
    // Nabavka sada ima miran prikaz prazne korpe.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Nabavka je prazna'), findsOneWidget);
    expect(find.bySemanticsLabel('Prazna korpa za nabavku'), findsOneWidget);
    await tester.tap(find.text('Pogledaj recepte'));
    await tester.pumpAndSettle();
    expect(currentTab(tester), 'Recepti');
  });
  for (final size in [const Size(320, 900), wide]) {
    testTavli('prazni ekrani sa 2× tekstom na ${size.width} px', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTavli(tester, size: size, location: '/pantry');
      expect(find.text('Još nema unetih namirnica'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.shopping_basket_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Nabavka je prazna'), findsOneWidget);
      await tester.ensureVisible(find.text('Pogledaj recepte'));
      await tester.tap(find.text('Pogledaj recepte'));
      await tester.pumpAndSettle();
      expect(currentTab(tester), 'Recepti');
      expect(tester.takeException(), isNull);
    });
  }
}
