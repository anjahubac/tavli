import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/app/theme/tavli_palette.dart';
import 'package:tavli/data/settings_repository.dart';

import '../helpers/test_app.dart';

ThemeData appTheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first));

void main() {
  testTavli('podrazumevano: Bosiljak, svetla tema kad je sistem svetao', (
    tester,
  ) async {
    await pumpTavli(tester);
    final t = appTheme(tester);
    expect(t.brightness, Brightness.light);
    expect(t.colorScheme.primary, TavliPalette.bosiljakLight.primary);
  });

  testTavli('Profil → Izgled: Šafran i Tamna se odmah primene i sačuvaju', (
    tester,
  ) async {
    final app = await pumpTavli(tester, location: '/profile');
    await tester.tap(find.text('Izgled'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Šafran'));
    await tester.pumpAndSettle();
    expect(
      appTheme(tester).colorScheme.primary,
      TavliPalette.safranLight.primary,
    );

    await tester.tap(find.text('Tamna'));
    await tester.pumpAndSettle();
    expect(appTheme(tester).brightness, Brightness.dark);
    expect(
      appTheme(tester).colorScheme.primary,
      TavliPalette.safranDark.primary,
    );

    final repo = SettingsRepository(app.db);
    expect(await repo.get('theme'), 'safran');
    expect(await repo.get('theme_mode'), 'dark');
  });

  testTavli('posle ponovnog pokretanja koristi sačuvanu temu', (tester) async {
    await pumpTavli(
      tester,
      settings: {'theme': 'borovnica', 'theme_mode': 'dark'},
    );
    final t = appTheme(tester);
    expect(t.brightness, Brightness.dark);
    expect(t.colorScheme.primary, TavliPalette.borovnicaDark.primary);
  });

  testTavli('Kao sistem prati tamni sistem', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpTavli(tester);
    expect(appTheme(tester).brightness, Brightness.dark);
  });

  testTavli('širok ekran: sve tri teme i režimi su vidljivi', (tester) async {
    await pumpTavli(tester, size: wide, location: '/profile/appearance');
    for (final name in [
      'Bosiljak',
      'Šafran',
      'Borovnica',
      'Svetla',
      'Tamna',
      'Kao sistem',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testTavli('Profil u debug verziji ima Animacije', (tester) async {
    await pumpTavli(tester, location: '/profile');
    expect(find.text('Animacije'), findsOneWidget);
    expect(find.text('Izgled'), findsOneWidget);
  });
}
