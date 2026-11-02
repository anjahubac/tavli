import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/database.dart';

/// Pripada li zapis domaćinstvu ili osobi.
enum EntityScope { household, user }

/// Jedan entitet koji se čuva na serveru: lokalna drift tabela ↔ tabela
/// na serveru. Mapiranje: camelCase ↔ snake_case, JSON tekst ↔ jsonb,
/// lokalna putanja slike `recipe_photos/x.jpg` ↔ samo `x.jpg`, vreme u UTC.
abstract class SyncEntity<T extends Table, R> {
  const SyncEntity();

  String get name;
  String get remoteTable;
  EntityScope get scope;

  /// Kolona sa id-jem na serveru (`user_id` za profil ukusa).
  String get remoteId => 'id';

  /// Roditelj (zbog redosleda i brisanja), npr. recipe za recipe_version.
  String? get parent => null;

  TableInfo<T, R> table(AppDatabase db);
  Expression<String> idColumn(T t);

  /// Kolona naloga (householdId ili userId).
  GeneratedColumn<String> scopeColumn(T t);

  Map<String, Object?> toRemote(R row);
  Insertable<R> fromRemote(Map<String, Object?> json);

  Future<R?> read(AppDatabase db, String id) => (db.select(
    table(db),
  )..where((t) => idColumn(t).equals(id))).getSingleOrNull();

  Future<void> deleteLocal(AppDatabase db, String id) =>
      (db.delete(table(db))..where((t) => idColumn(t).equals(id))).go();

  Future<void> write(AppDatabase db, Map<String, Object?> json) =>
      db.into(table(db)).insertOnConflictUpdate(fromRemote(json));
}

String _ts(DateTime d) => d.toUtc().toIso8601String();
DateTime _date(Object? v) => DateTime.parse(v! as String).toLocal();
DateTime? _dateOrNull(Object? v) => v == null ? null : _date(v);
String _json(Object? v) => jsonEncode(v);
double? _double(Object? v) => (v as num?)?.toDouble();

/// Lokalna relativna putanja slike → ime fajla na serveru i nazad.
String? photoFileName(String? localPath) => localPath?.split('/').last;
String? photoLocalPath(String? fileName) =>
    fileName == null ? null : 'recipe_photos/$fileName';

class RecipeEntity extends SyncEntity<$RecipesTable, RecipeRow> {
  const RecipeEntity();
  @override
  String get name => 'recipe';
  @override
  String get remoteTable => 'recipes';
  @override
  EntityScope get scope => EntityScope.household;
  @override
  $RecipesTable table(AppDatabase db) => db.recipes;
  @override
  Expression<String> idColumn($RecipesTable t) => t.id;
  @override
  GeneratedColumn<String> scopeColumn($RecipesTable t) => t.householdId;

  @override
  Map<String, Object?> toRemote(RecipeRow r) => {
    'id': r.id,
    'household_id': r.householdId,
    'title': r.title,
    'servings': r.servings,
    'prep_minutes': r.prepMinutes,
    'source': r.source,
    'ingredients': jsonDecode(r.ingredientsJson),
    'steps': jsonDecode(r.stepsJson),
    'image_path': photoFileName(r.imagePath),
    'answered_by': r.answeredBy,
    'created_at': _ts(r.createdAt),
  };

  @override
  RecipesCompanion fromRemote(Map<String, Object?> j) => RecipesCompanion(
    id: Value(j['id']! as String),
    householdId: Value(j['household_id'] as String?),
    title: Value(j['title']! as String),
    servings: Value(j['servings']! as int),
    prepMinutes: Value(j['prep_minutes'] as int?),
    source: Value(j['source']! as String),
    ingredientsJson: Value(_json(j['ingredients'])),
    stepsJson: Value(_json(j['steps'])),
    imagePath: Value(photoLocalPath(j['image_path'] as String?)),
    answeredBy: Value(j['answered_by'] as String?),
    createdAt: Value(_date(j['created_at'])),
    updatedAt: Value(_date(j['updated_at'] ?? j['created_at'])),
  );
}

class RecipeVersionEntity
    extends SyncEntity<$RecipeVersionsTable, RecipeVersionRow> {
  const RecipeVersionEntity();
  @override
  String get name => 'recipe_version';
  @override
  String get remoteTable => 'recipe_versions';
  @override
  EntityScope get scope => EntityScope.household;
  @override
  String get parent => 'recipe';
  @override
  $RecipeVersionsTable table(AppDatabase db) => db.recipeVersions;
  @override
  Expression<String> idColumn($RecipeVersionsTable t) => t.id;
  @override
  GeneratedColumn<String> scopeColumn($RecipeVersionsTable t) => t.householdId;

  @override
  Map<String, Object?> toRemote(RecipeVersionRow r) => {
    'id': r.id,
    'household_id': r.householdId,
    'recipe_id': r.recipeId,
    'recipe_json': jsonDecode(r.recipeJson),
    'instruction': r.instruction,
    'change_kind': r.changeKind,
    'changed_by': r.changedBy,
    'created_at': _ts(r.createdAt),
  };

  @override
  RecipeVersionsCompanion fromRemote(Map<String, Object?> j) =>
      RecipeVersionsCompanion(
        id: Value(j['id']! as String),
        householdId: Value(j['household_id'] as String?),
        recipeId: Value(j['recipe_id']! as String),
        recipeJson: Value(_json(j['recipe_json'])),
        instruction: Value(j['instruction'] as String?),
        changeKind: Value(j['change_kind']! as String),
        changedBy: Value(j['changed_by'] as String?),
        createdAt: Value(_date(j['created_at'])),
      );
}

class ShoppingListEntity
    extends SyncEntity<$ShoppingListsTable, ShoppingListRow> {
  const ShoppingListEntity();
  @override
  String get name => 'shopping_list';
  @override
  String get remoteTable => 'shopping_lists';
  @override
  EntityScope get scope => EntityScope.household;
  @override
  String get parent => 'meal_plan';
  @override
  $ShoppingListsTable table(AppDatabase db) => db.shoppingLists;
  @override
  Expression<String> idColumn($ShoppingListsTable t) => t.id;
  @override
  GeneratedColumn<String> scopeColumn($ShoppingListsTable t) => t.householdId;

  @override
  Map<String, Object?> toRemote(ShoppingListRow r) => {
    'id': r.id,
    'household_id': r.householdId,
    'name': r.name,
    'meal_plan_id': r.mealPlanId,
    'week': r.week,
    'created_at': _ts(r.createdAt),
  };

  @override
  ShoppingListsCompanion fromRemote(Map<String, Object?> j) =>
      ShoppingListsCompanion(
        id: Value(j['id']! as String),
        householdId: Value(j['household_id'] as String?),
        name: Value(j['name']! as String),
        mealPlanId: Value(j['meal_plan_id'] as String?),
        week: Value(j['week'] as int?),
        createdAt: Value(_date(j['created_at'])),
      );
}

class ShoppingItemEntity
    extends SyncEntity<$ShoppingItemsTable, ShoppingItemRow> {
  const ShoppingItemEntity();
  @override
  String get name => 'shopping_item';
  @override
  String get remoteTable => 'shopping_items';
  @override
  EntityScope get scope => EntityScope.household;
  @override
  String get parent => 'shopping_list';
  @override
  $ShoppingItemsTable table(AppDatabase db) => db.shoppingItems;
  @override
  Expression<String> idColumn($ShoppingItemsTable t) => t.id;
  @override
  GeneratedColumn<String> scopeColumn($ShoppingItemsTable t) => t.householdId;

  @override
  Map<String, Object?> toRemote(ShoppingItemRow r) => {
    'id': r.id,
    'household_id': r.householdId,
    'list_id': r.listId,
    'name': r.name,
    'quantity': r.quantity,
    'unit': r.unit,
    'category': r.category,
    'is_bought': r.isBought,
    'is_manual': r.isManual,
    'from_recipe_ids': jsonDecode(r.fromRecipeIdsJson),
  };

  @override
  ShoppingItemsCompanion fromRemote(Map<String, Object?> j) =>
      ShoppingItemsCompanion(
        id: Value(j['id']! as String),
        householdId: Value(j['household_id'] as String?),
        listId: Value(j['list_id']! as String),
        name: Value(j['name']! as String),
        quantity: Value(_double(j['quantity'])),
        unit: Value(j['unit'] as String?),
        category: Value(j['category']! as String),
        isBought: Value(j['is_bought'] as bool? ?? false),
        isManual: Value(j['is_manual'] as bool? ?? false),
        fromRecipeIdsJson: Value(_json(j['from_recipe_ids'] ?? const [])),
      );
}

class PantryItemEntity extends SyncEntity<$PantryItemsTable, PantryItemRow> {
  const PantryItemEntity();
  @override
  String get name => 'pantry_item';
  @override
  String get remoteTable => 'pantry_items';
  @override
  EntityScope get scope => EntityScope.household;
  @override
  $PantryItemsTable table(AppDatabase db) => db.pantryItems;
  @override
  Expression<String> idColumn($PantryItemsTable t) => t.id;
  @override
  GeneratedColumn<String> scopeColumn($PantryItemsTable t) => t.householdId;

  @override
  Map<String, Object?> toRemote(PantryItemRow r) => {
    'id': r.id,
    'household_id': r.householdId,
    'name': r.name,
    'quantity': r.quantity,
    'unit': r.unit,
    'category': r.category,
    'added_at': _ts(r.addedAt),
    'expires_at': r.expiresAt == null ? null : _ts(r.expiresAt!),
  };

  @override
  PantryItemsCompanion fromRemote(Map<String, Object?> j) =>
      PantryItemsCompanion(
        id: Value(j['id']! as String),
        householdId: Value(j['household_id'] as String?),
        name: Value(j['name']! as String),
        quantity: Value(_double(j['quantity'])),
        unit: Value(j['unit'] as String?),
        category: Value(j['category']! as String),
        addedAt: Value(_date(j['added_at'])),
        expiresAt: Value(_dateOrNull(j['expires_at'])),
      );
}

class MealPlanEntity extends SyncEntity<$MealPlansTable, MealPlanRow> {
  const MealPlanEntity();
  @override
  String get name => 'meal_plan';
  @override
  String get remoteTable => 'meal_plans';
  @override
  EntityScope get scope => EntityScope.household;
  @override
  $MealPlansTable table(AppDatabase db) => db.mealPlans;
  @override
  Expression<String> idColumn($MealPlansTable t) => t.id;
  @override
  GeneratedColumn<String> scopeColumn($MealPlansTable t) => t.householdId;

  @override
  Map<String, Object?> toRemote(MealPlanRow r) => {
    'id': r.id,
    'household_id': r.householdId,
    'start_date': _ts(r.startDate),
    'end_date': _ts(r.endDate),
    'meal_types': jsonDecode(r.mealTypesJson),
    'use_pantry': r.usePantry,
    'created_at': _ts(r.createdAt),
  };

  @override
  MealPlansCompanion fromRemote(Map<String, Object?> j) => MealPlansCompanion(
    id: Value(j['id']! as String),
    householdId: Value(j['household_id'] as String?),
    startDate: Value(_date(j['start_date'])),
    endDate: Value(_date(j['end_date'])),
    mealTypesJson: Value(_json(j['meal_types'])),
    usePantry: Value(j['use_pantry'] as bool? ?? true),
    createdAt: Value(_date(j['created_at'])),
  );
}

class MealPlanEntryEntity
    extends SyncEntity<$MealPlanEntriesTable, MealPlanEntryRow> {
  const MealPlanEntryEntity();
  @override
  String get name => 'meal_plan_entry';
  @override
  String get remoteTable => 'meal_plan_entries';
  @override
  EntityScope get scope => EntityScope.household;
  @override
  String get parent => 'meal_plan';
  @override
  $MealPlanEntriesTable table(AppDatabase db) => db.mealPlanEntries;
  @override
  Expression<String> idColumn($MealPlanEntriesTable t) => t.id;
  @override
  GeneratedColumn<String> scopeColumn($MealPlanEntriesTable t) => t.householdId;

  @override
  Map<String, Object?> toRemote(MealPlanEntryRow r) => {
    'id': r.id,
    'household_id': r.householdId,
    'plan_id': r.planId,
    'date': _ts(r.date),
    'meal_type': r.mealType,
    'recipe_id': r.recipeId,
    'is_locked': r.isLocked,
    'is_cooked': r.isCooked,
  };

  @override
  MealPlanEntriesCompanion fromRemote(Map<String, Object?> j) =>
      MealPlanEntriesCompanion(
        id: Value(j['id']! as String),
        householdId: Value(j['household_id'] as String?),
        planId: Value(j['plan_id']! as String),
        date: Value(_date(j['date'])),
        mealType: Value(j['meal_type']! as String),
        recipeId: Value(j['recipe_id'] as String?),
        isLocked: Value(j['is_locked'] as bool? ?? false),
        isCooked: Value(j['is_cooked'] as bool? ?? false),
      );
}

class RatingEntity extends SyncEntity<$RatingsTable, RatingRow> {
  const RatingEntity();
  @override
  String get name => 'rating';
  @override
  String get remoteTable => 'ratings';
  @override
  EntityScope get scope => EntityScope.user;
  @override
  String get parent => 'recipe';
  @override
  $RatingsTable table(AppDatabase db) => db.ratings;
  @override
  Expression<String> idColumn($RatingsTable t) => t.id;
  @override
  GeneratedColumn<String> scopeColumn($RatingsTable t) => t.userId;

  @override
  Map<String, Object?> toRemote(RatingRow r) => {
    'id': r.id,
    'user_id': r.userId,
    'recipe_id': r.recipeId,
    'stars': r.stars,
    'is_comfort_food': r.isComfortFood,
    'comment': r.comment,
    'cooked_at': _ts(r.cookedAt),
  };

  @override
  RatingsCompanion fromRemote(Map<String, Object?> j) => RatingsCompanion(
    id: Value(j['id']! as String),
    userId: Value(j['user_id'] as String?),
    recipeId: Value(j['recipe_id']! as String),
    stars: Value(j['stars']! as int),
    isComfortFood: Value(j['is_comfort_food'] as bool? ?? false),
    comment: Value(j['comment'] as String?),
    cookedAt: Value(_date(j['cooked_at'])),
  );
}

/// Profil ukusa: lokalni id je userId osobe.
class TasteProfileEntity
    extends SyncEntity<$UserProfilesTable, UserProfileRow> {
  const TasteProfileEntity();
  @override
  String get name => 'taste_profile';
  @override
  String get remoteTable => 'taste_profiles';
  @override
  String get remoteId => 'user_id';
  @override
  EntityScope get scope => EntityScope.user;
  @override
  $UserProfilesTable table(AppDatabase db) => db.userProfiles;
  @override
  Expression<String> idColumn($UserProfilesTable t) => t.id;
  @override
  GeneratedColumn<String> scopeColumn($UserProfilesTable t) => t.id;

  @override
  Map<String, Object?> toRemote(UserProfileRow r) => {
    'user_id': r.id,
    'profile': jsonDecode(r.profileJson),
  };

  @override
  UserProfilesCompanion fromRemote(Map<String, Object?> j) =>
      UserProfilesCompanion(
        id: Value(j['user_id']! as String),
        profileJson: Value(_json(j['profile'])),
      );
}

/// Ime u profilu (lokalno u `Accounts`). Šalje se kao izmena imena, ne upsert.
const profileEntity = 'profile';

/// Svi entiteti sa podacima, redom roditelj pre deteta (slanje i preuzimanje).
const List<SyncEntity<Table, Object?>> syncEntities = [
  RecipeEntity(),
  RecipeVersionEntity(),
  MealPlanEntity(),
  ShoppingListEntity(),
  ShoppingItemEntity(),
  PantryItemEntity(),
  MealPlanEntryEntity(),
  RatingEntity(),
  TasteProfileEntity(),
];

SyncEntity<Table, Object?>? entityByName(String name) {
  for (final e in syncEntities) {
    if (e.name == name) return e;
  }
  return null;
}
