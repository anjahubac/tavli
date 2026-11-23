import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../account/auth_controller.dart';
import '../domain/ids.dart';
import '../domain/plan_calendar.dart';
import '../domain/recipe.dart';
import '../domain/shopping_demand.dart';
import '../domain/shopping_source.dart';
import '../domain/shopping_sync.dart';
import '../domain/supply_allocation.dart';
import '../sync/synced_writer.dart';
import 'database.dart';
import 'shopping_models.dart';
import 'shopping_totals.dart';

export 'shopping_models.dart';

part 'shopping_items.dart';
part 'shopping_reconcile.dart';
part 'shopping_sources.dart';

// Nazivi entiteta za outbox (SyncedWriter).
const _shoppingList = 'shopping_list';
const _shoppingItem = 'shopping_item';
const _source = 'shopping_source';
const _contribution = 'shopping_contribution';
const _allocation = 'supply_allocation';

/// Trajni ID nedeljne liste: SHA-256 od JSON niza
/// `["shopping-week", planId, "yyyy-MM-dd"]` (početak nedelje, ISO datum).
/// Isti plan i dan daju isti ID i kada oba uređaja rade offline. Format je
/// deo ugovora sa serverom i drugim verzijama aplikacije; ne menja se.
String weekListId(String planId, CivilDate start) => sha256
    .convert(utf8.encode(jsonEncode(['shopping-week', planId, start.isoDate])))
    .toString();

/// Zajednička stanja i pozivi između delova [ShoppingRepository]
/// (`shopping_sources.dart`, `shopping_items.dart`, `shopping_reconcile.dart`).
abstract class _ShoppingBase {
  AppDatabase get _db;
  AccountScope get _scope;
  SyncedWriter get _writer;
  DateTime Function() get _clock;
  Set<String> get _released;
  Set<String> get _reopened;

  Future<String> _ensureList();
  Future<MealPlanRow?> _plan(String planId);
  Future<String> weekList(String planId, WeekPeriod period);
  Future<void> _reconcile();
  Future<void> _deleteContribution(String id);
  Future<void> _migrateLegacyUnits(
    List<ShoppingSourceRow> sources,
    Map<String, ShoppingContributionRow> contributions,
  );
  List<DemandLine> _demand(
    ShoppingSourceRow s,
    Map<String, MealPlanEntryRow> entries,
  );
}

/// Kupovina domaćinstva; svaka izmena ima outbox u istoj transakciji.
class ShoppingRepository extends _ShoppingBase
    with _ShoppingSources, _ShoppingItems, _ShoppingReconcile {
  ShoppingRepository(
    this._db, {
    required this._scope,
    required this._writer,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  @override
  final AppDatabase _db;
  @override
  final AccountScope _scope;
  @override
  final SyncedWriter _writer;
  @override
  final DateTime Function() _clock;

  /// Ažurira raspodelu i otvorene stavke nakon promene količine u ostavi.
  Future<void> reconcileSupply() => _db.transaction(_reconcile);

  @override
  Future<String> _ensureList() => _db.transaction(() async {
    final existing =
        await (_db.select(_db.shoppingLists)
              ..where(
                (t) =>
                    t.householdId.equals(_scope.householdId) &
                    t.mealPlanId.isNull(),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    final id = newId();
    await _db
        .into(_db.shoppingLists)
        .insert(
          ShoppingListsCompanion.insert(
            id: id,
            name: 'Kupovina',
            createdAt: _clock().toUtc(),
            householdId: Value(_scope.householdId),
          ),
        );
    await _writer.upsert('shopping_list', id);
    return id;
  });

  static List<String> _recipes(ShoppingItemRow row) => [
    for (final id in jsonDecode(row.fromRecipeIdsJson) as List<dynamic>)
      id as String,
  ];

  Future<List<ShoppingItemRow>> _items() async {
    final id = await _ensureList();
    return (_db.select(_db.shoppingItems)..where(
          (t) => t.listId.equals(id) & t.householdId.equals(_scope.householdId),
        ))
        .get();
  }

  Future<ShoppingSyncPlan> plan(
    String recipeId, {
    required List<Ingredient> missing,
    required List<Ingredient> have,
  }) async {
    final rows = [
      for (final row in await _items())
        if (_recipes(row).contains(recipeId)) row,
    ];
    return planRecipeShopping(
      missing: missing,
      have: have,
      inList: {for (final row in rows) ingredientKey(row.name)},
      bought: {
        for (final row in rows)
          if (row.isBought) ingredientKey(row.name),
      },
    );
  }

  /// Ponovni klik dodaje samo razliku; drugi recept deli postojeću stavku.
  Future<List<Ingredient>> addMissing(
    String recipeId, {
    required List<Ingredient> missing,
    required List<Ingredient> have,
  }) => _db.transaction(() async {
    final p = await plan(recipeId, missing: missing, have: have);
    final listId = await _ensureList();
    final open = {
      for (final row in await _items())
        if (!row.isBought) ingredientKey(row.name): row,
    };
    for (final ingredient in p.toAdd) {
      final existing = open[ingredientKey(ingredient.name)];
      if (existing != null) {
        await (_db.update(
          _db.shoppingItems,
        )..where((t) => t.id.equals(existing.id))).write(
          ShoppingItemsCompanion(
            fromRecipeIdsJson: Value(
              jsonEncode([..._recipes(existing), recipeId]),
            ),
          ),
        );
        await _writer.upsert('shopping_item', existing.id);
      } else {
        final id = newId();
        await _db
            .into(_db.shoppingItems)
            .insert(
              ShoppingItemsCompanion.insert(
                id: id,
                listId: listId,
                name: ingredient.name,
                quantity: Value(ingredient.quantity),
                unit: Value(ingredient.unit),
                category: ingredient.category,
                fromRecipeIdsJson: Value(jsonEncode([recipeId])),
                householdId: Value(_scope.householdId),
              ),
            );
        await _writer.upsert('shopping_item', id);
      }
    }
    return p.toAdd;
  });

  /// "Imam" uklanja samo doprinos ovog recepta; kupljeno ostaje.
  Future<bool> markHave(String recipeId, Ingredient ingredient) =>
      _db.transaction(() async {
        var removed = false;
        for (final row in await _items()) {
          final recipes = _recipes(row);
          if (row.isBought ||
              ingredientKey(row.name) != ingredientKey(ingredient.name) ||
              !recipes.contains(recipeId)) {
            continue;
          }
          removed = true;
          final rest = [...recipes]..remove(recipeId);
          if (rest.isEmpty && !row.isManual) {
            await (_db.delete(
              _db.shoppingItems,
            )..where((t) => t.id.equals(row.id))).go();
            await _writer.delete('shopping_item', row.id);
          } else {
            await (_db.update(
              _db.shoppingItems,
            )..where((t) => t.id.equals(row.id))).write(
              ShoppingItemsCompanion(
                fromRecipeIdsJson: Value(jsonEncode(rest)),
              ),
            );
            await _writer.upsert('shopping_item', row.id);
          }
        }
        return removed;
      });

  Future<int> openCount() async =>
      (await _items()).where((row) => !row.isBought).length;
  Future<List<String>> openNames() async => [
    for (final row in await _items())
      if (!row.isBought) row.name,
  ];

  Future<void> markBought(String name) => _db.transaction(() async {
    for (final row in await _items()) {
      if (ingredientKey(row.name) == ingredientKey(name) && !row.isBought) {
        await (_db.update(_db.shoppingItems)..where((t) => t.id.equals(row.id)))
            .write(const ShoppingItemsCompanion(isBought: Value(true)));
        await _writer.upsert('shopping_item', row.id);
      }
    }
  });

  // ---------------------------------------------------------------------
  // 010: nedeljne liste plana, izvori, doprinosi i raspodela zalihe.

  /// Lista nabavke bez plana (samostalni recepti i ručne stavke).
  Future<String> recipeList() => _ensureList();

  /// Kanonska lista za nedeljni deo plana: ista za isti plan i nedelju.
  /// Posle kreiranja se ne menja (videti `ShoppingListEntity`): server
  /// odbacuje kasnije upsertove istog ID-ja.
  @override
  Future<String> weekList(String planId, WeekPeriod period) =>
      _db.transaction(() async {
        final start = period.range.start.toWire();
        final existing =
            await (_db.select(_db.shoppingLists)..where(
                  (t) =>
                      t.householdId.equals(_scope.householdId) &
                      t.mealPlanId.equals(planId) &
                      t.periodStart.equals(start),
                ))
                .getSingleOrNull();
        if (existing != null) return existing.id;
        final id = weekListId(planId, period.range.start);
        await _db
            .into(_db.shoppingLists)
            .insert(
              ShoppingListsCompanion.insert(
                id: id,
                name: 'Nedelja ${period.number}',
                mealPlanId: Value(planId),
                week: Value(period.number),
                periodStart: Value(start),
                periodEnd: Value(period.range.end.toWire()),
                createdAt: _clock().toUtc(),
                householdId: Value(_scope.householdId),
              ),
            );
        await _writer.upsert(_shoppingList, id);
        return id;
      });

  /// Stavke jedne liste (nedelje ili liste bez plana).
  Future<List<ShoppingItemRow>> listItems(String listId) =>
      (_db.select(_db.shoppingItems)
            ..where(
              (t) =>
                  t.listId.equals(listId) &
                  t.householdId.equals(_scope.householdId),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  @override
  Future<MealPlanRow?> _plan(String planId) =>
      (_db.select(_db.mealPlans)..where(
            (t) =>
                t.id.equals(planId) & t.householdId.equals(_scope.householdId),
          ))
          .getSingleOrNull();

  /// Zbir stavki po namirnici i grupi jedinica (za prikaz celog plana).
  static List<PlanTotal> totalsOf(List<ShoppingItemRow> items) =>
      shoppingTotalsOf(items);

  /// Stavke čiji su doprinosi obrisani u ovoj transakciji: posle
  /// usklađivanja se brišu ako ih više ništa ne traži.
  @override
  final _released = <String>{};

  /// Poništene kupovine iz obroka: usklađivanje ih vraća kao otvorene
  /// stavke iste grupe (isti id) ili briše ako više nisu potrebne.
  @override
  final _reopened = <String>{};
}
