import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/theme_choice.dart';

void main() {
  test('podrazumevano: Bosiljak, svetla', () {
    expect(ThemeChoice.defaults.theme, TavliTheme.bosiljak);
    expect(ThemeChoice.defaults.mode, AppThemeMode.light);
  });

  test('nazivi na srpskom', () {
    expect(TavliTheme.values.map((t) => t.label), [
      'Bosiljak',
      'Šafran',
      'Borovnica',
    ]);
    expect(AppThemeMode.values.map((m) => m.label), [
      'Svetla',
      'Tamna',
      'Kao sistem',
    ]);
  });

  test('čita sačuvane vrednosti', () {
    final c = ThemeChoice.fromSettings(theme: 'safran', mode: 'dark');
    expect(c, const ThemeChoice(TavliTheme.safran, AppThemeMode.dark));
  });

  test('nepoznate ili prazne vrednosti → podrazumevano', () {
    expect(ThemeChoice.fromSettings(), ThemeChoice.defaults);
    expect(
      ThemeChoice.fromSettings(theme: 'malina', mode: 'sepia'),
      ThemeChoice.defaults,
    );
    expect(
      ThemeChoice.fromSettings(theme: 'borovnica', mode: '??'),
      const ThemeChoice(TavliTheme.borovnica, AppThemeMode.light),
    );
  });

  test('sačuvani sistemski režim ostaje sistemski', () {
    expect(ThemeChoice.fromSettings(mode: 'system').mode, AppThemeMode.system);
  });

  test('copyWith menja samo dato polje', () {
    final c = ThemeChoice.defaults.copyWith(mode: AppThemeMode.light);
    expect(c, const ThemeChoice(TavliTheme.bosiljak, AppThemeMode.light));
    expect(
      c.copyWith(theme: TavliTheme.safran),
      const ThemeChoice(TavliTheme.safran, AppThemeMode.light),
    );
  });
}
