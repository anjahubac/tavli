/// Tri teme aplikacije; svaka ima svetlu i tamnu paletu.
enum TavliTheme {
  bosiljak('Bosiljak'),
  safran('Šafran'),
  borovnica('Borovnica');

  const TavliTheme(this.label);

  final String label;
}

/// Svetla, tamna ili kao u sistemu.
enum AppThemeMode {
  light('Svetla'),
  dark('Tamna'),
  system('Kao sistem');

  const AppThemeMode(this.label);

  final String label;
}

/// Izbor teme i režima koji korisnik čuva u Profilu.
class ThemeChoice {
  const ThemeChoice(this.theme, this.mode);

  static const defaults = ThemeChoice(TavliTheme.bosiljak, AppThemeMode.system);

  /// Iz sačuvanih podešavanja; nepoznate vrednosti (npr. iz druge verzije
  /// aplikacije) daju podrazumevane.
  factory ThemeChoice.fromSettings({String? theme, String? mode}) =>
      ThemeChoice(
        TavliTheme.values.asNameMap()[theme] ?? defaults.theme,
        AppThemeMode.values.asNameMap()[mode] ?? defaults.mode,
      );

  final TavliTheme theme;
  final AppThemeMode mode;

  ThemeChoice copyWith({TavliTheme? theme, AppThemeMode? mode}) =>
      ThemeChoice(theme ?? this.theme, mode ?? this.mode);

  @override
  bool operator ==(Object other) =>
      other is ThemeChoice && other.theme == theme && other.mode == mode;

  @override
  int get hashCode => Object.hash(theme, mode);

  @override
  String toString() => 'ThemeChoice(${theme.name}, ${mode.name})';
}
