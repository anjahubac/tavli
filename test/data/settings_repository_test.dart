import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/settings_repository.dart';
import 'package:tavli/domain/theme_choice.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepository(db);
  });

  tearDown(() => db.close());

  test(
    'get vraća null za nepostojeći ključ, set pa get vraća vrednost',
    () async {
      expect(await repo.get('x'), isNull);
      await repo.set('x', '1');
      await repo.set('x', '2');
      expect(await repo.get('x'), '2');
    },
  );

  test('prazna baza → podrazumevana tema', () async {
    expect(await repo.loadTheme(), ThemeChoice.defaults);
  });

  test('sačuvana tema se vraća posle ponovnog otvaranja', () async {
    const choice = ThemeChoice(TavliTheme.borovnica, AppThemeMode.dark);
    await repo.saveTheme(choice);
    expect(await SettingsRepository(db).loadTheme(), choice);
    expect(await repo.get('theme'), 'borovnica');
    expect(await repo.get('theme_mode'), 'dark');
  });
}
