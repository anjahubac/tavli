import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// Liste (sastojci, koraci, tipovi obroka) se čuvaju kao JSON tekst:
// uvek se čitaju zajedno sa roditeljskim redom.

@DataClassName('RecipeRow')
class Recipes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get servings => integer()();
  IntColumn get prepMinutes => integer().nullable()();
  TextColumn get source => text()(); // RecipeSource.name
  TextColumn get ingredientsJson => text()();
  TextColumn get stepsJson => text()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get answeredBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Prethodne verzije recepta, za vraćanje posle AI izmene.
@DataClassName('RecipeVersionRow')
class RecipeVersions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recipeId => text().references(Recipes, #id)();
  TextColumn get recipeJson => text()();
  TextColumn get instruction => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('PantryItemRow')
class PantryItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get quantity => real().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get category => text()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
}

@DataClassName('ShoppingListRow')
class ShoppingLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get mealPlanId => text().nullable()();

  /// Redni broj nedelje kod mesečnog plana (1-5), null inače.
  IntColumn get week => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ShoppingItemRow')
class ShoppingItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get listId => text().references(ShoppingLists, #id)();
  TextColumn get name => text()();
  RealColumn get quantity => real().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get category => text()();
  BoolColumn get isBought => boolean().withDefault(const Constant(false))();
  BoolColumn get isManual => boolean().withDefault(const Constant(false))();
  TextColumn get fromRecipeIdsJson =>
      text().withDefault(const Constant('[]'))();
}

@DataClassName('MealPlanRow')
class MealPlans extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get mealTypesJson => text()(); // ["breakfast","lunch","dinner"]
  BoolColumn get usePantry => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MealPlanEntryRow')
class MealPlanEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get planId => text().references(MealPlans, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get mealType => text()();
  TextColumn get recipeId => text().nullable().references(Recipes, #id)();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  BoolColumn get isCooked => boolean().withDefault(const Constant(false))();
}

@DataClassName('RatingRow')
class Ratings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recipeId => text().references(Recipes, #id)();
  IntColumn get stars => integer()();
  BoolColumn get isComfortFood =>
      boolean().withDefault(const Constant(false))();
  TextColumn get comment => text().nullable()();
  DateTimeColumn get cookedAt => dateTime()();
}

/// Jedan red sa profilom ukusa kao JSON (polja će se često menjati).
@DataClassName('UserProfileRow')
class UserProfiles extends Table {
  IntColumn get id => integer()();
  TextColumn get profileJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('ModelStatusRow')
class ModelStatuses extends Table {
  TextColumn get provider => text()();
  TextColumn get model => text()();

  /// KeyOrigin.name: limiti važe posebno za svaki ključ.
  TextColumn get keyOrigin => text().withDefault(const Constant('user'))();
  DateTimeColumn get blockedUntil => dateTime().nullable()();
  IntColumn get requestsToday => integer().withDefault(const Constant(0))();
  TextColumn get usageDay => text().nullable()(); // yyyy-mm-dd
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {provider, model, keyOrigin};
}

@DriftDatabase(
  tables: [
    Recipes,
    RecipeVersions,
    PantryItems,
    ShoppingLists,
    ShoppingItems,
    MealPlans,
    MealPlanEntries,
    Ratings,
    UserProfiles,
    AppSettings,
    ModelStatuses,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'tavli'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Samo keš pauza (najduže jedan dan), pa tabelu pravimo iznova
        // umesto kopiranja redova u novi primarni ključ.
        await m.deleteTable(modelStatuses.actualTableName);
        await m.createTable(modelStatuses);
      }
    },
  );
}
