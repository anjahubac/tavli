import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

Future<void> pumpGallery(WidgetTester tester, {VoidCallback? onClose}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: TavliGallery(onClose: onClose)));
}

ThemeData galleryTheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(TavliGallerySections)));

Future<void> choose(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ChoiceChip, label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('podrazumevano: Bosiljak, svetlo, 1x, Android', (tester) async {
    await pumpGallery(tester);
    final t = galleryTheme(tester);
    expect(t.extension<TavliColors>()!.motif, TavliMotif.bosiljak);
    expect(t.brightness, Brightness.light);
    expect(TavliPlatform.fromTarget(t.platform), TavliPlatform.android);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('prekidači menjaju temu, osvetljenost i platformu', (
    tester,
  ) async {
    await pumpGallery(tester);
    await choose(tester, 'Borovnica');
    await choose(tester, 'Tamno');
    await choose(tester, 'macOS');

    final t = galleryTheme(tester);
    expect(t.extension<TavliColors>()!.motif, TavliMotif.borovnica);
    expect(t.brightness, Brightness.dark);
    expect(
      t.colorScheme.primary,
      TavliPalette.of(TavliMotif.borovnica, Brightness.dark).primary,
    );
    expect(TavliPlatform.fromTarget(t.platform), TavliPlatform.macos);
  });

  testWidgets('veličina teksta važi za sadržaj, ne za prekidače', (
    tester,
  ) async {
    await pumpGallery(tester);
    await choose(tester, '2x');

    final content = tester.element(find.byType(TavliGallerySections));
    expect(MediaQuery.textScalerOf(content).scale(10), 20);
    final controls = tester.element(find.text('Tema'));
    expect(MediaQuery.textScalerOf(controls).scale(10), 10);
  });

  testWidgets('dugme nazad zove onClose', (tester) async {
    var closed = false;
    await pumpGallery(tester, onClose: () => closed = true);
    await tester.tap(find.byType(BackButton));
    expect(closed, isTrue);
  });

  for (final platform in TavliPlatform.values) {
    for (final scale in tavliGalleryTextScales) {
      testWidgets(
        'sadržaj bez grešaka u rasporedu: ${platform.name}, ${scale}x',
        (tester) async {
          await pumpGallery(tester);
          await choose(tester, tavliPlatformLabel(platform));
          await tester.tap(
            find.widgetWithText(
              ChoiceChip,
              '${scale.toString().replaceAll('.0', '').replaceAll('.', ',')}x',
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
