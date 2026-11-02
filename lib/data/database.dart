import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// Liste (sastojci, koraci, tipovi obroka) se čuvaju kao JSON tekst:
// uvek se čitaju zajedno sa roditeljskim redom.
//
// Lokalna baza je keš naloga (006a): podaci domaćinstva imaju `householdId`,
// lični podaci `userId`. null = podaci od pre naloga (prebacuju se jednom,
// pri prvoj prijavi). Id-jeve pravi uređaj (tekst), pa ponovljeno slanje
// na server ne pravi duplikate.

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
  TextColumn get householdId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Prethodne verzije recepta, za vraćanje posle AI izmene.
@DataClassName('RecipeVersionRow')
class RecipeVersions extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId => text().references(Recipes, #id)();
  TextColumn get recipeJson => text()();
  TextColumn get instruction => text().nullable()();

  /// ChangeKind.name: kakva izmena je zamenila ovu verziju.
  TextColumn get changeKind => text().withDefault(const Constant('ai'))();

  /// Model koji je napravio AI izmenu.
  TextColumn get changedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get householdId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PantryItemRow')
class PantryItems extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get quantity => real().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get category => text()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  TextColumn get householdId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ShoppingListRow')
class ShoppingLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get mealPlanId => text().nullable()();

  /// Redni broj nedelje kod mesečnog plana (1-5), null inače.
  IntColumn get week => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get householdId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ShoppingItemRow')
class ShoppingItems extends Table {
  TextColumn get id => text()();
  TextColumn get listId => text().references(ShoppingLists, #id)();
  TextColumn get name => text()();
  RealColumn get quantity => real().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get category => text()();
  BoolColumn get isBought => boolean().withDefault(const Constant(false))();
  BoolColumn get isManual => boolean().withDefault(const Constant(false))();
  TextColumn get fromRecipeIdsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get householdId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MealPlanRow')
class MealPlans extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get mealTypesJson => text()(); // ["breakfast","lunch","dinner"]
  BoolColumn get usePantry => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get householdId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MealPlanEntryRow')
class MealPlanEntries extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().references(MealPlans, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get mealType => text()();
  TextColumn get recipeId => text().nullable().references(Recipes, #id)();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  BoolColumn get isCooked => boolean().withDefault(const Constant(false))();
  TextColumn get householdId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RatingRow')
class Ratings extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId => text().references(Recipes, #id)();
  IntColumn get stars => integer()();
  BoolColumn get isComfortFood =>
      boolean().withDefault(const Constant(false))();
  TextColumn get comment => text().nullable()();
  DateTimeColumn get cookedAt => dateTime()();
  TextColumn get userId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Profil ukusa kao JSON (polja će se često menjati). Id je userId osobe;
/// `legacy` za red od pre naloga.
@DataClassName('UserProfileRow')
class UserProfiles extends Table {
  TextColumn get id => text()();
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

/// Nalozi prijavljeni na ovom uređaju: profil i domaćinstvo za pokretanje
/// bez mreže. Sesija (tokeni) se nikad ne čuva ovde, samo u Keychain-u.
@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get userId => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get householdId => text()();
  TextColumn get householdName => text()();
  TextColumn get role => text()();
  BoolColumn get initialDownloadDone =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastPullAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId};
}

/// Izmene koje čekaju slanje na server, redom. Čuva samo šta je promenjeno;
/// sadržaj se čita iz reda u trenutku slanja.
@DataClassName('OutboxRow')
@TableIndex(
  name: 'sync_outbox_account_state_seq',
  columns: {#accountId, #state, #seq},
)
class SyncOutbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get accountId => text()();
  TextColumn get entity => text()();
  TextColumn get recordId => text()();

  /// upsert | delete | photoUpload | photoDelete
  TextColumn get op => text()();

  /// pending | rejected
  TextColumn get state => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  /// Samo kod greške, nikad sadržaj zapisa.
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Dokle je preuzet svaki entitet naloga: (updatedAt, lastId).
@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  TextColumn get accountId => text()();
  TextColumn get entity => text()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get lastId => text()();

  @override
  Set<Column> get primaryKey => {accountId, entity};
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
    Accounts,
    SyncOutbox,
    SyncCursors,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'tavli'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Samo keš pauza (najduže jedan dan), pa tabelu pravimo iznova
        // umesto kopiranja redova u novi primarni ključ.
        await m.deleteTable(modelStatuses.actualTableName);
        await m.createTable(modelStatuses);
      }
      if (from < 3) {
        await m.addColumn(recipeVersions, recipeVersions.changeKind);
        await m.addColumn(recipeVersions, recipeVersions.changedBy);
      }
      if (from < 4) await transaction(() => _migrateToAccounts(m));
    },
  );

  /// v4: tekstualni id-jevi, kolone naloga i tabele za slanje. Postojeći
  /// redovi dobijaju slučajan id i null nalog (prebacuju se pri prijavi).
  Future<void> _migrateToAccounts(Migrator m) async {
    const randomId = CustomExpression<String>('lower(hex(randomblob(16)))');
    final existing = {
      for (final r in await customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ).get())
        r.read<String>('name'),
    };
    // Tabela koje nema (stara delimična šema) se samo napravi.
    Future<void> alter(TableMigration migration) async {
      final table = migration.affectedTable;
      if (!existing.contains(table.actualTableName)) {
        await m.createTable(table);
        return;
      }
      // Starija aplikacija može da vrati user_version na 3 iako su tabele
      // već v4. Već pretvoreni id-jevi i vlasništvo tada moraju da ostanu.
      final columns = await customSelect(
        'PRAGMA table_info("${table.actualTableName}")',
      ).get();
      final types = {
        for (final row in columns)
          row.read<String>('name'): row.read<String>('type').toUpperCase(),
      };
      final missing = [
        for (final column in migration.newColumns)
          if (!types.containsKey(column.$name)) column,
      ];
      final transformers = {
        for (final entry in migration.columnTransformer.entries)
          if (types[entry.key.$name] != 'TEXT') entry.key: entry.value,
      };
      if (missing.isEmpty && transformers.isEmpty) return;
      await m.alterTable(
        TableMigration(
          table,
          newColumns: missing,
          columnTransformer: transformers,
        ),
      );
    }

    await alter(TableMigration(recipes, newColumns: [recipes.householdId]));
    await alter(
      TableMigration(
        recipeVersions,
        columnTransformer: {recipeVersions.id: randomId},
        newColumns: [recipeVersions.householdId],
      ),
    );
    await alter(
      TableMigration(
        pantryItems,
        columnTransformer: {pantryItems.id: randomId},
        newColumns: [pantryItems.householdId],
      ),
    );
    await alter(
      TableMigration(shoppingLists, newColumns: [shoppingLists.householdId]),
    );
    await alter(
      TableMigration(
        shoppingItems,
        columnTransformer: {shoppingItems.id: randomId},
        newColumns: [shoppingItems.householdId],
      ),
    );
    await alter(TableMigration(mealPlans, newColumns: [mealPlans.householdId]));
    await alter(
      TableMigration(
        mealPlanEntries,
        columnTransformer: {mealPlanEntries.id: randomId},
        newColumns: [mealPlanEntries.householdId],
      ),
    );
    await alter(
      TableMigration(
        ratings,
        columnTransformer: {ratings.id: randomId},
        newColumns: [ratings.userId],
      ),
    );
    // Jedan red od pre naloga dobija id 'legacy'.
    await alter(
      TableMigration(
        userProfiles,
        columnTransformer: {
          userProfiles.id: const CustomExpression<String>(
            'CASE WHEN id = (SELECT MIN(id) FROM user_profiles) '
            "THEN 'legacy' ELSE 'legacy-' || id END",
          ),
        },
      ),
    );
    await m.createTable(accounts);
    await m.createTable(syncOutbox);
    final indexes = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    ).get();
    if (!indexes.any(
      (row) => row.read<String>('name') == syncOutboxAccountStateSeq.entityName,
    )) {
      await m.createIndex(syncOutboxAccountStateSeq);
    }
    await m.createTable(syncCursors);
  }
}
