import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/data/database.dart';

/// Šema verzije 3 (pre naloga), tačno kako ju je pravio drift.
const _v3 = [
  'CREATE TABLE "app_settings" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, PRIMARY KEY ("key"))',
  'CREATE TABLE "meal_plan_entries" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "plan_id" TEXT NOT NULL REFERENCES meal_plans (id), "date" INTEGER NOT NULL, "meal_type" TEXT NOT NULL, "recipe_id" TEXT NULL REFERENCES recipes (id), "is_locked" INTEGER NOT NULL DEFAULT 0 CHECK ("is_locked" IN (0, 1)), "is_cooked" INTEGER NOT NULL DEFAULT 0 CHECK ("is_cooked" IN (0, 1)))',
  'CREATE TABLE "meal_plans" ("id" TEXT NOT NULL, "start_date" INTEGER NOT NULL, "end_date" INTEGER NOT NULL, "meal_types_json" TEXT NOT NULL, "use_pantry" INTEGER NOT NULL DEFAULT 1 CHECK ("use_pantry" IN (0, 1)), "created_at" INTEGER NOT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "model_statuses" ("provider" TEXT NOT NULL, "model" TEXT NOT NULL, "key_origin" TEXT NOT NULL DEFAULT \'user\', "blocked_until" INTEGER NULL, "requests_today" INTEGER NOT NULL DEFAULT 0, "usage_day" TEXT NULL, "last_error" TEXT NULL, PRIMARY KEY ("provider", "model", "key_origin"))',
  'CREATE TABLE "pantry_items" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "quantity" REAL NULL, "unit" TEXT NULL, "category" TEXT NOT NULL, "added_at" INTEGER NOT NULL, "expires_at" INTEGER NULL)',
  'CREATE TABLE "ratings" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "recipe_id" TEXT NOT NULL REFERENCES recipes (id), "stars" INTEGER NOT NULL, "is_comfort_food" INTEGER NOT NULL DEFAULT 0 CHECK ("is_comfort_food" IN (0, 1)), "comment" TEXT NULL, "cooked_at" INTEGER NOT NULL)',
  'CREATE TABLE "recipe_versions" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "recipe_id" TEXT NOT NULL REFERENCES recipes (id), "recipe_json" TEXT NOT NULL, "instruction" TEXT NULL, "change_kind" TEXT NOT NULL DEFAULT \'ai\', "changed_by" TEXT NULL, "created_at" INTEGER NOT NULL)',
  'CREATE TABLE "recipes" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "servings" INTEGER NOT NULL, "prep_minutes" INTEGER NULL, "source" TEXT NOT NULL, "ingredients_json" TEXT NOT NULL, "steps_json" TEXT NOT NULL, "image_path" TEXT NULL, "answered_by" TEXT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "shopping_items" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "list_id" TEXT NOT NULL REFERENCES shopping_lists (id), "name" TEXT NOT NULL, "quantity" REAL NULL, "unit" TEXT NULL, "category" TEXT NOT NULL, "is_bought" INTEGER NOT NULL DEFAULT 0 CHECK ("is_bought" IN (0, 1)), "is_manual" INTEGER NOT NULL DEFAULT 0 CHECK ("is_manual" IN (0, 1)), "from_recipe_ids_json" TEXT NOT NULL DEFAULT \'[]\')',
  'CREATE TABLE "shopping_lists" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "meal_plan_id" TEXT NULL, "week" INTEGER NULL, "created_at" INTEGER NOT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "user_profiles" ("id" INTEGER NOT NULL, "profile_json" TEXT NOT NULL, PRIMARY KEY ("id"))',
];

void main() {
  test('migracija 2 → 3 dodaje vrstu izmene i model, a čuva verzije', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(
          'CREATE TABLE recipe_versions (id INTEGER PRIMARY KEY, '
          'recipe_id TEXT NOT NULL, recipe_json TEXT NOT NULL, '
          'instruction TEXT, created_at INTEGER NOT NULL)',
        );
        raw.execute(
          'INSERT INTO recipe_versions (recipe_id, recipe_json, instruction, '
          "created_at) VALUES ('r1', '{}', 'bez luka', 0)",
        );
        raw.execute('PRAGMA user_version = 2');
      },
    );
    final db = AppDatabase(executor);
    addTearDown(db.close);

    final rows = await db.select(db.recipeVersions).get();
    expect(rows.single.instruction, 'bez luka');
    expect(rows.single.changeKind, 'ai');
    expect(rows.single.changedBy, isNull);
  });

  test('migracija 3 → 4 čuva sve redove, daje tekstualne id-jeve i nove tabele', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        for (final s in _v3) {
          raw.execute(s);
        }
        raw.execute(
          "INSERT INTO recipes VALUES ('r1', 'Sarma', 4, 60, 'manual', '[]', "
          "'[]', 'recipe_photos/a.jpg', NULL, 1, 2)",
        );
        raw.execute(
          "INSERT INTO recipes VALUES ('r2', 'Pasulj', 2, NULL, 'ai', '[]', "
          "'[]', NULL, 'Gemini', 1, 2)",
        );
        for (var i = 0; i < 3; i++) {
          raw.execute(
            'INSERT INTO recipe_versions (recipe_id, recipe_json, change_kind, '
            "created_at) VALUES ('r1', '{}', 'ai', $i)",
          );
        }
        raw.execute(
          'INSERT INTO recipe_versions (recipe_id, recipe_json, change_kind, '
          "created_at) VALUES ('r2', '{}', 'manual', 9)",
        );
        raw.execute(
          "INSERT INTO pantry_items (name, category, added_at) VALUES ('so', 'ostalo', 1)",
        );
        raw.execute(
          "INSERT INTO shopping_lists VALUES ('l1', 'Lista', 'p1', 1, 1)",
        );
        raw.execute(
          'INSERT INTO shopping_items (list_id, name, category) '
          "VALUES ('l1', 'mleko', 'ostalo'), ('l1', 'hleb', 'pekara')",
        );
        raw.execute(
          "INSERT INTO meal_plans VALUES ('p1', 1, 2, '[\"lunch\"]', 1, 1)",
        );
        raw.execute(
          'INSERT INTO meal_plan_entries (plan_id, date, meal_type, recipe_id) '
          "VALUES ('p1', 1, 'lunch', 'r1'), ('p1', 2, 'dinner', NULL)",
        );
        raw.execute(
          'INSERT INTO ratings (recipe_id, stars, cooked_at) '
          "VALUES ('r1', 5, 1)",
        );
        raw.execute("INSERT INTO user_profiles VALUES (1, '{\"ljuto\":true}')");
        raw.execute("INSERT INTO app_settings VALUES ('theme', 'dark')");
        raw.execute(
          "INSERT INTO model_statuses (provider, model) VALUES ('gemini', 'm')",
        );
        raw.execute('PRAGMA user_version = 3');
      },
    );
    final db = AppDatabase(executor);
    addTearDown(db.close);

    expect(db.schemaVersion, 4);

    final recipes = await db.select(db.recipes).get();
    expect(recipes.map((r) => r.id), unorderedEquals(['r1', 'r2']));
    expect(recipes.every((r) => r.householdId == null), isTrue);
    expect(
      recipes.firstWhere((r) => r.id == 'r1').imagePath,
      'recipe_photos/a.jpg',
    );

    final versions = await db.select(db.recipeVersions).get();
    expect(versions, hasLength(4));
    expect(versions.map((v) => v.id).toSet(), hasLength(4));
    expect(versions.where((v) => v.recipeId == 'r1'), hasLength(3));
    expect(
      versions.every((v) => RegExp(r'^[0-9a-f]{32}$').hasMatch(v.id)),
      isTrue,
    );
    expect(versions.every((v) => v.householdId == null), isTrue);

    final items = await db.select(db.shoppingItems).get();
    expect(items.map((i) => i.name), unorderedEquals(['mleko', 'hleb']));
    expect(
      items.every((i) => i.listId == 'l1' && i.householdId == null),
      isTrue,
    );
    expect(items.map((i) => i.id).toSet(), hasLength(2));

    final lists = await db.select(db.shoppingLists).get();
    expect(lists.single.householdId, isNull);
    expect(lists.single.mealPlanId, 'p1');

    final entries = await db.select(db.mealPlanEntries).get();
    expect(entries, hasLength(2));
    expect(entries.where((e) => e.recipeId == 'r1'), hasLength(1));
    expect(entries.every((e) => e.planId == 'p1'), isTrue);

    expect((await db.select(db.mealPlans).get()).single.householdId, isNull);
    final pantry = (await db.select(db.pantryItems).get()).single;
    expect(pantry.name, 'so');
    expect(pantry.householdId, isNull);

    final rating = (await db.select(db.ratings).get()).single;
    expect(rating.recipeId, 'r1');
    expect(rating.userId, isNull);

    final profile = (await db.select(db.userProfiles).get()).single;
    expect(profile.id, 'legacy');
    expect(profile.profileJson, '{"ljuto":true}');

    expect((await db.select(db.appSettings).get()).single.value, 'dark');
    expect(await db.select(db.modelStatuses).get(), hasLength(1));
    expect(await db.select(db.accounts).get(), isEmpty);
    expect(await db.select(db.syncOutbox).get(), isEmpty);
    expect(await db.select(db.syncCursors).get(), isEmpty);
  });
}
