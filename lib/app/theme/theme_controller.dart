import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repository.dart';
import '../../domain/theme_choice.dart';
import '../../providers.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// Izbor se vidi odmah; upisi čekaju učitavanje i izvršavaju se redom.
class ThemeController extends Notifier<ThemeChoice> {
  bool _changed = false;
  int _revision = 0;
  ThemeChoice _saved = ThemeChoice.defaults;
  late Future<void> _pending;

  @override
  ThemeChoice build() {
    _pending = _load();
    return ThemeChoice.defaults;
  }

  Future<void> _load() async {
    try {
      final saved = await ref.read(settingsRepositoryProvider).loadTheme();
      _saved = saved;
      if (!_changed && ref.mounted) state = saved;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('Tema nije učitana: ${e.runtimeType}');
    }
  }

  /// false: izbor nije sačuvan; poslednji potvrđeni izbor se vraća.
  Future<bool> set(ThemeChoice choice) {
    _changed = true;
    final revision = ++_revision;
    final repo = ref.read(settingsRepositoryProvider);
    state = choice;
    final result = _pending.then((_) async {
      try {
        await repo.saveTheme(choice);
        _saved = choice;
        return true;
      } on Exception {
        if (ref.mounted && revision == _revision) state = _saved;
        return false;
      }
    });
    _pending = result.then((_) {});
    return result;
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeChoice>(
  ThemeController.new,
);
