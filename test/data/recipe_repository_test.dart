import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/recipe_repository.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/recipe_version.dart';

import '../helpers/fake_photo_store.dart';

Recipe recipe(String id, {String title = 'Sarma', DateTime? createdAt}) =>
    Recipe(
      id: id,
      title: title,
      servings: 4,
      ingredients: const [Ingredient(name: 'kupus')],
      steps: const ['Kuvati.'],
      source: RecipeSource.manual,
      createdAt: createdAt ?? DateTime.utc(2026),
    );

void main() {
  late AppDatabase db;
  late FakePhotoStore photos;
  late RecipeRepository repo;
  var now = DateTime.utc(2026, 10, 30, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    photos = FakePhotoStore();
    now = DateTime.utc(2026, 10, 30, 12);
    repo = RecipeRepository(db, photos, clock: () => now);
  });
  tearDown(() => db.close());

  test('lista je od najnovijeg ka najstarijem', () async {
    await repo.create(recipe('a', title: 'Pasulj', createdAt: DateTime(2026)));
    await repo.create(recipe('b', createdAt: DateTime(2026, 5)));

    final list = await repo.watchAll().first;
    expect(list.map((r) => r.title), ['Sarma', 'Pasulj']);
    expect((await repo.get('a'))!.ingredients.single.name, 'kupus');
    expect(await repo.get('nema'), isNull);
  });

  test('izmena čuva prethodnu verziju sa vrstom, zahtevom i modelom', () async {
    await repo.create(recipe('a'));
    await repo.update(
      recipe('a', title: 'Posna sarma'),
      kind: ChangeKind.ai,
      instruction: 'posno',
      changedBy: 'Gemini Pro',
    );

    expect((await repo.get('a'))!.title, 'Posna sarma');
    final v = (await repo.watchVersions('a').first).single;
    expect(v.recipe.title, 'Sarma');
    expect(v.kind, ChangeKind.ai);
    expect(v.instruction, 'posno');
    expect(v.changedBy, 'Gemini Pro');
    expect(v.createdAt.isAtSameMomentAs(now), isTrue);
  });

  test('čuva se najviše 30 verzija', () async {
    await repo.create(recipe('a', title: 'v0'));
    for (var i = 1; i <= 35; i++) {
      now = now.add(const Duration(minutes: 1));
      await repo.update(recipe('a', title: 'v$i'), kind: ChangeKind.manual);
    }
    final versions = await repo.watchVersions('a').first;
    expect(versions, hasLength(30));
    expect(versions.first.recipe.title, 'v34');
    expect(versions.last.recipe.title, 'v5');
  });

  test('poništavanje vraća prethodno stanje i briše tu verziju', () async {
    await repo.create(recipe('a'));
    await repo.update(recipe('a', title: 'Druga'), kind: ChangeKind.ai);

    expect(await repo.undoLast('a'), isTrue);
    expect((await repo.get('a'))!.title, 'Sarma');
    expect(await repo.watchVersions('a').first, isEmpty);
    expect(await repo.undoLast('a'), isFalse);
  });

  test('vraćanje starije verzije čuva trenutno stanje', () async {
    await repo.create(recipe('a', title: 'Prva'));
    await repo.update(recipe('a', title: 'Druga'), kind: ChangeKind.ai);
    now = now.add(const Duration(minutes: 1));
    await repo.update(recipe('a', title: 'Treća'), kind: ChangeKind.ai);

    final oldest = (await repo.watchVersions('a').first).last;
    now = now.add(const Duration(minutes: 1));
    await repo.restore(oldest.id);

    expect((await repo.get('a'))!.title, 'Prva');
    final versions = await repo.watchVersions('a').first;
    expect(versions.first.kind, ChangeKind.restore);
    expect(versions.first.recipe.title, 'Treća');

    await repo.undoLast('a');
    expect((await repo.get('a'))!.title, 'Treća');
  });

  test('brisanje uklanja recept, verzije i sliku', () async {
    final path = await photos.save(Uint8List.fromList([1]));
    await repo.create(recipe('a').copyWith(imagePath: path));
    await repo.update(recipe('a', title: 'B'), kind: ChangeKind.manual);
    await db
        .into(db.ratings)
        .insert(
          RatingsCompanion.insert(recipeId: 'a', stars: 5, cookedAt: now),
        );

    await repo.delete('a');

    expect(await repo.get('a'), isNull);
    expect(await db.select(db.recipeVersions).get(), isEmpty);
    expect(await db.select(db.ratings).get(), isEmpty);
    expect(photos.saved, isEmpty);
  });

  test('izmena nepostojećeg recepta baca grešku', () async {
    expect(
      () => repo.update(recipe('x'), kind: ChangeKind.manual),
      throwsStateError,
    );
  });

  test('pokvaren zapis verzije se preskače', () async {
    await repo.create(recipe('a'));
    await db
        .into(db.recipeVersions)
        .insert(
          RecipeVersionsCompanion.insert(
            recipeId: 'a',
            recipeJson: '{"title": ""}',
            createdAt: now,
            changeKind: const Value('ai'),
          ),
        );
    expect(await repo.watchVersions('a').first, isEmpty);
  });
}
