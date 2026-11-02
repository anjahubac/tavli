import 'dart:async';

import 'package:tavli/data/settings_repository.dart';
import 'package:tavli/domain/theme_choice.dart';

class ControlledSettings extends SettingsRepository {
  ControlledSettings(super.db);
  ThemeChoice saved = const ThemeChoice(
    TavliTheme.borovnica,
    AppThemeMode.dark,
  );
  final writes = <ThemeChoice>[];
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<ThemeChoice> loadTheme() async => saved;

  @override
  Future<void> saveTheme(ThemeChoice choice) async {
    writes.add(choice);
    await gate?.future;
    if (fail) throw Exception('fake storage failure');
    saved = choice;
  }
}
