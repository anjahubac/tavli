import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repository.dart';
import '../../domain/theme_choice.dart';
import '../../providers.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// Izabrana tema i režim. Kreće od podrazumevanih vrednosti, pa učita
/// sačuvane iz baze (uvodni ekran pokriva promenu).
class ThemeController extends Notifier<ThemeChoice> {
  /// Korisnik je već birao, pa zakasnelo učitavanje ne sme da ga pregazi.
  bool _changed = false;

  @override
  ThemeChoice build() {
    unawaited(_load());
    return ThemeChoice.defaults;
  }

  Future<void> _load() async {
    try {
      final saved = await ref.read(settingsRepositoryProvider).loadTheme();
      if (!_changed && ref.mounted) state = saved;
    } on Exception catch (e) {
      // Bez baze ostaje podrazumevana tema; aplikacija i dalje radi.
      if (kDebugMode) debugPrint('Tema nije učitana: ${e.runtimeType}');
    }
  }

  Future<void> set(ThemeChoice choice) async {
    _changed = true;
    state = choice;
    await ref.read(settingsRepositoryProvider).saveTheme(choice);
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeChoice>(
  ThemeController.new,
);
