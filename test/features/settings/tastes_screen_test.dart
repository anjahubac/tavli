import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/data/allergen_repository.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/favorite_repository.dart';
import 'package:tavli/data/planning_sharing_repository.dart';
import 'package:tavli/data/taste_profile_repository.dart';
import 'package:tavli/domain/allergen_group.dart';
import 'package:tavli/domain/recipe_labels.dart';
import 'package:tavli/providers.dart';
import 'package:tavli/sync/sync_remote.dart';
import 'package:tavli/sync/synced_writer.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/test_app.dart';

const _tomato = '00000000-0000-4000-8000-000000000001';
const _beet = '00000000-0000-4000-8000-000000000002';
const _withdrawn = '00000000-0000-4000-8000-000000000003';

Future<void> _seedFoods(AppDatabase db) async {
  final now = DateTime.utc(2026);
  for (final (id, name, withdrawn) in [
    (_tomato, 'paradajz', false),
    (_beet, 'cvekla', false),
    (_withdrawn, 'stara namirnica', true),
  ]) {
    await db
        .into(db.foods)
        .insert(
          FoodsCompanion.insert(
            id: id,
            slug: name,
            name: name,
            category: 'povrće',
            baseUnit: 'gram',
            withdrawnAt: Value(withdrawn ? now : null),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}

/// Saglasnost na „serveru“: prati revizije kao prava RPC funkcija.
class _FakeSharing implements PlanningSharingRepository {
  _FakeSharing({this.offline = false});

  bool offline;
  PlanningSharing current = PlanningSharing.initial;
  final writes = <bool>[];

  @override
  Future<PlanningSharing> getSharing() async {
    if (offline) throw const TransientSyncError('offline');
    return current;
  }

  @override
  Future<PlanningSharing> setPreferences(
    bool enabled, {
    required int expectedRevision,
  }) async {
    if (offline) throw const TransientSyncError('offline');
    if (expectedRevision != current.revision) {
      throw const PlanningSharingConflict();
    }
    writes.add(enabled);
    return current = PlanningSharing(
      preferences: enabled,
      revision: current.revision + 1,
    );
  }
}

SyncedWriter _writer(TestApp app) =>
    SyncedWriter(app.db, accountId: app.scope.userId);

AllergenRepository _allergens(TestApp app) =>
    AllergenRepository(app.db, scope: app.scope, writer: _writer(app));

TasteProfileRepository _tastes(TestApp app) =>
    TasteProfileRepository(app.db, scope: app.scope, writer: _writer(app));

FavoriteRepository _favorites(TestApp app) =>
    FavoriteRepository(app.db, scope: app.scope, writer: _writer(app));

Future<TestApp> _open(
  WidgetTester tester, {
  Size size = phone,
  _FakeSharing? sharing,
  bool withSharing = true,
  List<String> recipes = const [],
}) => pumpTavli(
  tester,
  size: size,
  location: '/profile/tastes',
  recipes: [
    for (final (i, title) in recipes.indexed) sampleRecipe('r$i', title),
  ],
  setup: _seedFoods,
  overrides: [
    planningSharingRepositoryProvider.overrideWithValue(
      withSharing ? sharing ?? _FakeSharing() : null,
    ),
  ],
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) =>
    _tap(tester, find.text(text).first);

void main() {
  testTavli('Profil vodi na Ukuse i alergene sa pregledom izbora', (
    tester,
  ) async {
    final app = await pumpTavli(tester, location: '/profile');
    expect(find.text('ISHRANA'), findsOneWidget);
    expect(find.text('Ništa nije izabrano'), findsOneWidget);

    await _allergens(app).saveSelection({AllergenGroup.milk});
    await tester.pumpAndSettle();
    expect(find.text('1 alergen'), findsOneWidget);

    await tester.tap(find.text('Ukusi i alergeni'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TavliBackAppBar, 'Ukusi i alergeni'),
      findsOneWidget,
    );
    await tester.tap(iconButton('Nazad'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TavliBackAppBar, 'Profil'), findsOneWidget);
  });

  testTavli('alergen se čuva odmah i vidi se u zbiru', (tester) async {
    final app = await _open(tester);
    expect(find.text('Nijedan'), findsOneWidget);

    await _tapText(tester, 'Mleko');
    expect(await _allergens(app).getSelection(), {AllergenGroup.milk});
    expect(find.text('Izabrano: 1'), findsOneWidget);

    await _tapText(tester, 'Mleko');
    expect(await _allergens(app).getSelection(), isEmpty);
    expect(await _writer(app).unsentCount(), greaterThan(0));
  });

  testTavli('vrsta jela: Volim, pa Ne volim, pa bez izbora', (tester) async {
    final app = await _open(tester);
    final soup = DishKind.soup.label;

    await _tapText(tester, soup);
    var prefs = await _tastes(app).getDishPreferences();
    expect(prefs.liked, {DishKind.soup});
    expect(find.bySemanticsLabel('$soup: Volim'), findsOneWidget);

    await _tapText(tester, soup);
    prefs = await _tastes(app).getDishPreferences();
    expect(prefs.liked, isEmpty);
    expect(prefs.disliked, {DishKind.soup});

    await _tapText(tester, soup);
    prefs = await _tastes(app).getDishPreferences();
    expect(prefs.liked, isEmpty);
    expect(prefs.disliked, isEmpty);
  });

  testTavli('kuhinja se čuva kao kod sa servera', (tester) async {
    final app = await _open(tester);
    await _tapText(tester, 'Japanska');
    await _tapText(tester, 'Japanska');
    final prefs = await _tastes(app).getCuisinePreferences();
    expect(prefs.disliked.map((c) => c.name), ['japanese']);
  });

  testTavli('namirnica: dodaj u Volim i Ne volim, pa ukloni', (tester) async {
    final app = await _open(tester);
    final addButtons = find.bySemanticsLabel('Dodaj');

    // Prvo „Dodaj“ u kartici je pod „Volim“.
    await _tap(tester, addButtons.at(1));
    expect(find.text('Dodaj namirnicu'), findsOneWidget);
    // Povučena namirnica se ne nudi.
    expect(find.text('Stara namirnica'), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'parad');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TavliButton, 'Volim'));
    await tester.pumpAndSettle();
    expect(find.text('Već je u Volim'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(TavliSheet),
        matching: find.text('Ne volim'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'cvek');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TavliButton, 'Ne volim'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TavliButton, 'Gotovo'));
    await tester.pumpAndSettle();

    var prefs = await _tastes(app).getFoodPreferences();
    expect(prefs.liked, {_tomato});
    expect(prefs.disliked, {_beet});
    expect(find.text('Paradajz'), findsOneWidget);
    expect(find.text('Cvekla'), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel('Ukloni Paradajz'));
    prefs = await _tastes(app).getFoodPreferences();
    expect(prefs.liked, isEmpty);
    expect(find.text('Paradajz'), findsNothing);
  });

  testTavli('omiljeni recept se bira u listi i otvara sa pločice', (
    tester,
  ) async {
    final app = await _open(tester, recipes: ['Musaka', 'Proja']);
    expect(find.text('Musaka'), findsNothing);

    await _tap(tester, find.bySemanticsLabel('Dodaj').first);
    expect(find.text('Izabrano: 0'), findsOneWidget);

    await tester.tap(iconButton('Dodaj u omiljene: Musaka'));
    await tester.pumpAndSettle();
    expect(find.text('Izabrano: 1'), findsOneWidget);
    expect(await _favorites(app).getFavoriteRecipeIds(), {'r0'});

    await tester.enterText(find.byType(TextField).last, 'xyz');
    await tester.pumpAndSettle();
    expect(find.text('Nema recepta sa tim imenom.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TavliButton, 'Gotovo'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Musaka'));
    expect(recipeHeading('Musaka'), findsOneWidget);
  });

  testTavli('deljenje se uključuje tek posle potvrde i važi sa servera', (
    tester,
  ) async {
    final sharing = _FakeSharing();
    await _open(tester, sharing: sharing);
    final row = find.widgetWithText(TavliSwitchRow, 'Deli ukuse i omiljene');
    await _tap(tester, row);
    expect(find.textContaining('Gemini, Groq ili OpenRouter'), findsOneWidget);
    await tester.tap(find.text('Otkaži'));
    await tester.pumpAndSettle();
    expect(sharing.writes, isEmpty);

    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deli'));
    await tester.pumpAndSettle();
    expect(sharing.writes, [true]);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    // Isključivanje ne traži potvrdu.
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(sharing.writes, [true, false]);
  });

  testTavli('bez mreže deljenje ostaje isto i nudi ponovni pokušaj', (
    tester,
  ) async {
    final sharing = _FakeSharing(offline: true);
    await _open(tester, sharing: sharing);
    expect(find.text('Pokušaj ponovo'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

    sharing.offline = false;
    await _tapText(tester, 'Pokušaj ponovo');
    expect(find.text('Pokušaj ponovo'), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
  });

  testTavli('promena na drugom uređaju: poruka i nova vrednost', (
    tester,
  ) async {
    final sharing = _FakeSharing();
    await _open(tester, sharing: sharing);
    // Drugi uređaj je u međuvremenu uključio pa isključio deljenje.
    sharing.current = const PlanningSharing(preferences: false, revision: 2);

    final row = find.widgetWithText(TavliSwitchRow, 'Deli ukuse i omiljene');
    await _tap(tester, row);
    await tester.tap(find.text('Deli'));
    await tester.pumpAndSettle();
    expect(find.textContaining('promenjeno na drugom uređaju'), findsOneWidget);
    expect(sharing.writes, isEmpty);
  });

  testTavli('aplikacija bez servera: prekidač je isključen', (tester) async {
    await _open(tester, withSharing: false);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });

  testTavli('širok ekran: dve kolone i pretraga namirnica u kartici', (
    tester,
  ) async {
    final app = await _open(tester, size: wide);
    expect(find.byType(TavliBackAppBar), findsNothing);
    final allergens = tester.getTopLeft(find.text('ALERGENI'));
    final kinds = tester.getTopLeft(find.text('VRSTE JELA I KUHINJE'));
    expect(kinds.dx, greaterThan(allergens.dx));
    expect(kinds.dy, closeTo(allergens.dy, 4));
    expect(find.byType(TavliToggleChip), findsNWidgets(14));

    await tester.enterText(find.byType(TextField).first, 'cvek');
    await tester.pumpAndSettle();
    await tester.tap(iconButton('Ne volim: Cvekla'));
    await tester.pumpAndSettle();
    expect((await _tastes(app).getFoodPreferences()).disliked, {_beet});
  });

  for (final size in [const Size(320, 700), wide]) {
    testTavli('tekst 2×, ${size.width.toInt()} px: bez prelivanja', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _open(tester, size: size, recipes: ['Pasulj prebranac']);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
