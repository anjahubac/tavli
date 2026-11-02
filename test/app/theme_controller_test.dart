import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/app/theme/theme_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/domain/theme_choice.dart';

import '../helpers/controlled_settings.dart';

void main() {
  late AppDatabase db;
  late ControlledSettings repo;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ControlledSettings(db);
    container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );
    container.read(themeControllerProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('neuspešan upis vraća poslednju sačuvanu temu bez izuzetka', () async {
    final old = repo.saved;
    repo.fail = true;
    await expectLater(
      container
          .read(themeControllerProvider.notifier)
          .set(ThemeChoice.defaults),
      completion(false),
    );
    expect(container.read(themeControllerProvider), old);
  });

  test(
    'brzi izbori se čuvaju redom, poslednji ostaje posle pokretanja',
    () async {
      repo.gate = Completer<void>();
      final controller = container.read(themeControllerProvider.notifier);
      const first = ThemeChoice(TavliTheme.safran, AppThemeMode.light);
      const last = ThemeChoice(TavliTheme.bosiljak, AppThemeMode.dark);
      final one = controller.set(first);
      final two = controller.set(last);
      await Future<void>.delayed(Duration.zero);
      expect(repo.writes, [first]);
      expect(container.read(themeControllerProvider), last);
      repo.gate!.complete();
      await Future.wait([one, two]);
      expect(repo.writes, [first, last]);
      expect(repo.saved, last);
    },
  );
}
