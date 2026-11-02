import 'dart:convert';

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

/// Zbir jedne namirnice u celom planu (mesec): samo za čitanje. Radnje idu
/// na nedeljne stavke iz [itemIds]; mesečna lista se ne čuva.
class PlanTotal {
  const PlanTotal({
    required this.ingredient,
    required this.unitGroup,
    required this.name,
    required this.category,
    required this.baseUnit,
    required this.openMicros,
    required this.boughtMicros,
    required this.hasUnknown,
    required this.itemIds,
    required this.listIds,
  });

  final String ingredient;
  final String unitGroup;
  final String name;
  final String category;
  final String baseUnit;

  /// Preostalo za kupovinu i već kupljeno, u milionitim delovima [baseUnit].
  final int openMicros;
  final int boughtMicros;

  /// Neka otvorena stavka nema poznatu količinu (traži proveru).
  final bool hasUnknown;
  final List<String> itemIds;
  final List<String> listIds;
}

/// Kupovina domaćinstva; svaka izmena ima outbox u istoj transakciji.
class ShoppingRepository {
  ShoppingRepository(
    this._db, {
    required this._scope,
    required this._writer,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final AccountScope _scope;
  final SyncedWriter _writer;
  final DateTime Function() _clock;

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

  static const _shoppingList = 'shopping_list';
  static const _shoppingItem = 'shopping_item';
  static const _source = 'shopping_source';
  static const _contribution = 'shopping_contribution';
  static const _allocation = 'supply_allocation';

  /// Lista nabavke bez plana (samostalni recepti i ručne stavke).
  Future<String> recipeList() => _ensureList();

  /// Kanonska lista za nedeljni deo plana: ista za isti plan i nedelju.
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
        final id = newId();
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

  Future<MealPlanRow?> _plan(String planId) =>
      (_db.select(_db.mealPlans)..where(
            (t) =>
                t.id.equals(planId) & t.householdId.equals(_scope.householdId),
          ))
          .getSingleOrNull();

  /// Usklađuje nabavku plana sa odobrenim obrocima: jedan izvor po obroku u
  /// listi njegove nedelje, pa doprinosi, raspodela zalihe i otvorene
  /// stavke. Ponovljen poziv bez promene ne menja ništa.
  Future<void> reconcilePlan(String planId) => _db.transaction(() async {
    final plan = await _plan(planId);
    if (plan == null) return;
    final range = DateRange(
      CivilDate.fromWire(plan.startDate),
      CivilDate.fromWire(plan.endDate),
    );
    final entries =
        await (_db.select(_db.mealPlanEntries)..where(
              (t) =>
                  t.planId.equals(planId) &
                  t.householdId.equals(_scope.householdId),
            ))
            .get();
    final planLists = {
      for (final l
          in await (_db.select(_db.shoppingLists)..where(
                (t) =>
                    t.mealPlanId.equals(planId) &
                    t.householdId.equals(_scope.householdId),
              ))
              .get())
        l.id,
    };
    final sources = {
      for (final s
          in await (_db.select(_db.shoppingSources)..where(
                (t) =>
                    t.householdId.equals(_scope.householdId) &
                    t.kind.equals(ShoppingSourceKind.planEntry.name) &
                    t.listId.isIn(planLists),
              ))
              .get())
        s.planEntryId!: s,
    };
    final now = _clock().toUtc();
    final kept = <String>{};
    for (final e in entries) {
      final period = periodFor(range, CivilDate.fromWire(e.date));
      if (e.recipeSnapshotJson == null || period == null) continue;
      final listId = await weekList(planId, period);
      var source = sources[e.id];
      if (source != null && source.listId != listId) {
        // Obrok premešten u drugu nedelju: stari izvor oslobađa zalihu.
        await _deleteSource(source.id);
        source = null;
      }
      final closedAt = e.isCooked ? (source?.closedAt ?? now) : null;
      if (source == null) {
        final id = newId();
        await _db
            .into(_db.shoppingSources)
            .insert(
              ShoppingSourcesCompanion.insert(
                id: id,
                listId: listId,
                kind: ShoppingSourceKind.planEntry.name,
                planEntryId: Value(e.id),
                closedAt: Value(closedAt),
                createdAt: now,
                householdId: Value(_scope.householdId),
              ),
            );
        await _writer.upsert(_source, id);
        kept.add(id);
      } else {
        kept.add(source.id);
        if (source.closedAt != closedAt) {
          await (_db.update(_db.shoppingSources)
                ..where((t) => t.id.equals(source!.id)))
              .write(ShoppingSourcesCompanion(closedAt: Value(closedAt)));
          await _writer.upsert(_source, source.id);
        }
      }
    }
    // Obrok obrisan ili bez recepta: njegov izvor i neiskorišćena zaliha
    // se oslobađaju; kupljene stavke ostaju.
    for (final s in sources.values) {
      if (!kept.contains(s.id)) await _deleteSource(s.id);
    }
    await _reconcile();
  });

  /// Dodaje (ili menja) samostalnu pripremu recepta bez plana. Isto
  /// poreklo ([originKey]: recept iz biblioteke ili nesačuvan nacrt) menja
  /// postojeću otvorenu pripremu; [repeat] ("Ponovi nabavku") pravi novu, a
  /// stara ostaje istorija. Vraća id pripreme.
  Future<String> addRecipePreparation({
    required RecipeSnapshot snapshot,
    required int servings,
    required String originKey,
    String? recipeId,
    bool repeat = false,
  }) => _db.transaction(() async {
    if (servings < minServings || servings > maxServings) {
      throw ArgumentError.value(servings, 'servings', 'Porcije van opsega');
    }
    final listId = await _ensureList();
    final now = _clock().toUtc();
    final current =
        await (_db.select(_db.shoppingSources)
              ..where(
                (t) =>
                    t.householdId.equals(_scope.householdId) &
                    t.kind.equals(ShoppingSourceKind.recipePreparation.name) &
                    t.originKey.equals(originKey) &
                    t.supersededAt.isNull() &
                    t.closedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    final json = jsonEncode(snapshot.toJson());
    String id;
    if (current != null && !repeat) {
      id = current.id;
      if (current.recipeSnapshotJson != json || current.servings != servings) {
        await (_db.update(
          _db.shoppingSources,
        )..where((t) => t.id.equals(id))).write(
          ShoppingSourcesCompanion(
            recipeSnapshotJson: Value(json),
            servings: Value(servings),
          ),
        );
        await _writer.upsert(_source, id);
      }
    } else {
      if (current != null) {
        await (_db.update(_db.shoppingSources)
              ..where((t) => t.id.equals(current.id)))
            .write(ShoppingSourcesCompanion(supersededAt: Value(now)));
        await _writer.upsert(_source, current.id);
      }
      id = newId();
      await _db
          .into(_db.shoppingSources)
          .insert(
            ShoppingSourcesCompanion.insert(
              id: id,
              listId: listId,
              kind: ShoppingSourceKind.recipePreparation.name,
              recipeSnapshotJson: Value(json),
              servings: Value(servings),
              recipeId: Value(recipeId),
              originKey: Value(originKey),
              createdAt: now,
              householdId: Value(_scope.householdId),
            ),
          );
      await _writer.upsert(_source, id);
    }
    await _reconcile();
    return id;
  });

  /// Uklanja izvor (npr. samostalnu pripremu): oslobađa njegovu zalihu i
  /// otvorenu potrebu; kupljeno ostaje.
  Future<void> removeSource(String sourceId) => _db.transaction(() async {
    await _deleteSource(sourceId);
    await _reconcile();
  });

  /// Zbir celog plana po namirnici, iz nedeljnih lista (samo čitanje).
  Future<List<PlanTotal>> planTotals(String planId) async {
    final lists =
        await (_db.select(_db.shoppingLists)..where(
              (t) =>
                  t.mealPlanId.equals(planId) &
                  t.householdId.equals(_scope.householdId) &
                  t.periodStart.isNotNull(),
            ))
            .get();
    final items =
        await (_db.select(_db.shoppingItems)..where(
              (t) =>
                  t.listId.isIn([for (final l in lists) l.id]) &
                  t.householdId.equals(_scope.householdId),
            ))
            .get();
    final groups = <(String, String), List<ShoppingItemRow>>{};
    for (final i in items) {
      final unit = normalizeUnit(i.unit);
      final group = i.quantity == null ? unknownGroup : unit.group;
      groups.putIfAbsent((ingredientKey(i.name), group), () => []).add(i);
    }
    int micros(ShoppingItemRow i) => i.quantity == null
        ? 0
        : toMicros(i.quantity!) * normalizeUnit(i.unit).factor;
    return [
      for (final MapEntry(key: (ingredient, group), value: rows)
          in groups.entries)
        PlanTotal(
          ingredient: ingredient,
          unitGroup: group,
          name: rows.first.name,
          category: rows.first.category,
          baseUnit: normalizeUnit(rows.first.unit).base,
          openMicros: rows
              .where((r) => !r.isBought)
              .fold(0, (sum, r) => sum + micros(r)),
          boughtMicros: rows
              .where((r) => r.isBought)
              .fold(0, (sum, r) => sum + micros(r)),
          hasUnknown: rows.any((r) => !r.isBought && r.quantity == null),
          itemIds: [for (final r in rows) r.id],
          listIds: {for (final r in rows) r.listId}.toList(),
        ),
    ];
  }

  /// Briše izvor i njegovu decu (deca pre roditelja, i u outbox-u).
  Future<void> _deleteSource(String sourceId) async {
    final contributions = await (_db.select(
      _db.shoppingContributions,
    )..where((t) => t.sourceId.equals(sourceId))).get();
    for (final c in contributions) {
      await _deleteContribution(c.id);
    }
    await (_db.delete(
      _db.shoppingSources,
    )..where((t) => t.id.equals(sourceId))).go();
    await _writer.delete(_source, sourceId);
  }

  /// Stavke čiji su doprinosi obrisani u ovoj transakciji: posle
  /// usklađivanja se brišu ako ih više ništa ne traži.
  final _released = <String>{};

  Future<void> _deleteContribution(String id) async {
    final row = await (_db.select(
      _db.shoppingContributions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row?.shoppingItemId case final itemId?) _released.add(itemId);
    final allocations = await (_db.select(
      _db.supplyAllocations,
    )..where((t) => t.contributionId.equals(id))).get();
    for (final a in allocations) {
      await (_db.delete(
        _db.supplyAllocations,
      )..where((t) => t.id.equals(a.id))).go();
      await _writer.delete(_allocation, a.id);
    }
    await (_db.delete(
      _db.shoppingContributions,
    )..where((t) => t.id.equals(id))).go();
    await _writer.delete(_contribution, id);
  }

  /// Potrebe izvora iz odobrenog recepta i porcija; prazno kad recept nije
  /// čitljiv.
  List<DemandLine> _demand(
    ShoppingSourceRow s,
    Map<String, MealPlanEntryRow> entries,
  ) {
    final entry = entries[s.planEntryId];
    final json = s.planEntryId == null
        ? s.recipeSnapshotJson
        : entry?.recipeSnapshotJson;
    if (json == null) return const [];
    final RecipeSnapshot snapshot;
    try {
      snapshot = RecipeSnapshot.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } on FormatException {
      return const [];
    }
    final servings = (s.planEntryId == null ? s.servings : entry?.servings);
    return demandFor(
      DemandSource(
        id: s.id,
        baseServings: snapshot.baseServings,
        servings: (servings ?? snapshot.baseServings).clamp(
          minServings,
          maxServings,
        ),
        ingredients: snapshot.ingredients,
      ),
    );
  }

  /// Celo domaćinstvo: doprinosi otvorenih izvora prate odobrene recepte,
  /// potvrđena zaliha se raspoređuje hronološki, a otvorene stavke
  /// pokazuju samo ono što preostaje. Kupljene, ručne i stare stavke se ne
  /// menjaju.
  Future<void> _reconcile() async {
    final hid = _scope.householdId;
    final now = _clock().toUtc();
    final sources = await (_db.select(
      _db.shoppingSources,
    )..where((t) => t.householdId.equals(hid))).get();
    final entries = {
      for (final e
          in await (_db.select(_db.mealPlanEntries)..where(
                (t) => t.id.isIn([for (final s in sources) ?s.planEntryId]),
              ))
              .get())
        e.id: e,
    };

    // 1. Doprinosi: jedan po izvoru + sastojku + grupi jedinica. Zatvoreni i
    // zamenjeni izvori se ne preračunavaju.
    final contributions = <String, ShoppingContributionRow>{
      for (final c in await (_db.select(
        _db.shoppingContributions,
      )..where((t) => t.householdId.equals(hid))).get())
        c.id: c,
    };
    final changed = <String>{};
    for (final s in sources) {
      if (s.closedAt != null || s.supersededAt != null) continue;
      final existing = {
        for (final c in contributions.values)
          if (c.sourceId == s.id) (c.ingredientKey, c.unitGroup): c,
      };
      for (final line in _demand(s, entries)) {
        final key = (line.key.ingredient, line.key.unitGroup);
        final prev = existing.remove(key);
        final notes = jsonEncode(line.notes);
        if (prev != null &&
            prev.micros == line.micros &&
            prev.name == line.name &&
            prev.category == line.category &&
            prev.baseUnit == line.baseUnit &&
            prev.notesJson == notes) {
          continue;
        }
        final row = ShoppingContributionsCompanion(
          id: Value(prev?.id ?? newId()),
          householdId: Value(hid),
          shoppingItemId: Value(prev?.shoppingItemId),
          sourceId: Value(s.id),
          ingredientKey: Value(line.key.ingredient),
          unitGroup: Value(line.key.unitGroup),
          baseUnit: Value(line.baseUnit),
          micros: Value(line.micros),
          name: Value(line.name),
          category: Value(line.category),
          notesJson: Value(notes),
        );
        await _db.into(_db.shoppingContributions).insertOnConflictUpdate(row);
        contributions[row.id.value] = await (_db.select(
          _db.shoppingContributions,
        )..where((t) => t.id.equals(row.id.value))).getSingle();
        changed.add(row.id.value);
      }
      for (final gone in existing.values) {
        await _deleteContribution(gone.id);
        contributions.remove(gone.id);
      }
    }

    // 2. Zaliha: potvrđena ostava (koja nije istekla) i kupljene stavke.
    // Prijem kupovine u ostavu je ista zaliha kao ta kupovina.
    final supplies = <Supply>[];
    for (final p
        in await (_db.select(_db.pantryItems)..where(
              (t) =>
                  t.householdId.equals(hid) &
                  t.confirmedAt.isNotNull() &
                  t.quantity.isNotNull(),
            ))
            .get()) {
      if (p.expiresAt case final e? when e.isBefore(now)) continue;
      final unit = normalizeUnit(p.unit);
      supplies.add(
        Supply(
          id: p.id,
          origin: SupplyOrigin.pantry,
          ingredient: ingredientKey(p.name),
          unitGroup: unit.group,
          micros: toMicros(p.quantity!) * unit.factor,
          samePhysicalAs: p.sourceShoppingItemId,
        ),
      );
    }
    for (final i
        in await (_db.select(_db.shoppingItems)..where(
              (t) =>
                  t.householdId.equals(hid) &
                  t.isBought.equals(true) &
                  t.quantity.isNotNull(),
            ))
            .get()) {
      final unit = normalizeUnit(i.unit);
      supplies.add(
        Supply(
          id: i.id,
          origin: SupplyOrigin.purchase,
          ingredient: ingredientKey(i.name),
          unitGroup: unit.group,
          micros: toMicros(i.quantity!) * unit.factor,
        ),
      );
    }
    final capacity = <String, Supply>{};
    for (final s in supplies) {
      final prev = capacity[s.canonicalId];
      if (prev == null || s.samePhysicalAs != null) capacity[s.canonicalId] = s;
    }

    // 3. Postojeća raspodela: zadržava se, ali ne preko potrebe doprinosa
    // ni preko zalihe (kasniji obroci prvi gube).
    final sourceById = {for (final s in sources) s.id: s};
    DemandOrder orderOf(ShoppingContributionRow c) {
      final s = sourceById[c.sourceId];
      final e = entries[s?.planEntryId];
      return e == null
          ? const DemandOrder()
          : DemandOrder(
              date: CivilDate.fromWire(e.date).toWire(),
              mealOrder: mealOrder(e.mealType),
            );
    }

    int compareContributions(
      ShoppingContributionRow a,
      ShoppingContributionRow b,
    ) {
      final oa = orderOf(a), ob = orderOf(b);
      if (oa.date != ob.date) {
        if (oa.date == null) return 1;
        if (ob.date == null) return -1;
        final c = oa.date!.compareTo(ob.date!);
        if (c != 0) return c;
      }
      final m = oa.mealOrder.compareTo(ob.mealOrder);
      return m != 0 ? m : a.sourceId.compareTo(b.sourceId);
    }

    final allocations = await (_db.select(
      _db.supplyAllocations,
    )..where((t) => t.householdId.equals(hid))).get();
    final kept = <SupplyAllocationRow>[];
    final latestFirst = [...allocations]
      ..sort((a, b) {
        final ca = contributions[a.contributionId];
        final cb = contributions[b.contributionId];
        if (ca == null || cb == null) return 0;
        return compareContributions(cb, ca);
      });
    final used = <String, int>{};
    final perContribution = <String, int>{};
    // Prvo po hronologiji: raniji obroci zadržavaju zalihu.
    for (final a in latestFirst.reversed) {
      final c = contributions[a.contributionId];
      final supply = capacity[a.supplyId];
      if (c == null) continue;
      if (a.coversWholeUnknown) {
        kept.add(a);
        continue;
      }
      final cap = supply?.micros ?? 0;
      final room = cap - (used[a.supplyId] ?? 0);
      final need = (c.micros ?? 0) - (perContribution[c.id] ?? 0);
      final keep = [a.micros ?? 0, room, need].reduce((x, y) => x < y ? x : y);
      if (keep <= 0) {
        await (_db.delete(
          _db.supplyAllocations,
        )..where((t) => t.id.equals(a.id))).go();
        await _writer.delete(_allocation, a.id);
        continue;
      }
      if (keep != a.micros) {
        await (_db.update(_db.supplyAllocations)
              ..where((t) => t.id.equals(a.id)))
            .write(SupplyAllocationsCompanion(micros: Value(keep)));
        await _writer.upsertLast(_allocation, a.id);
      }
      used[a.supplyId] = (used[a.supplyId] ?? 0) + keep;
      perContribution[c.id] = (perContribution[c.id] ?? 0) + keep;
      kept.add(a);
    }

    // 4. Nova raspodela za ono što preostaje otvorenim izvorima.
    bool isOpen(ShoppingContributionRow c) =>
        sourceById[c.sourceId]?.closedAt == null;
    final requests = [
      for (final c in contributions.values)
        if (isOpen(c) && c.micros != null)
          DemandRequest(
            DemandLine(
              key: (
                sourceId: c.id,
                ingredient: c.ingredientKey,
                unitGroup: c.unitGroup,
              ),
              name: c.name,
              category: c.category,
              micros: c.micros! - (perContribution[c.id] ?? 0),
              baseUnit: c.baseUnit,
            ),
            orderOf(c),
          ),
    ];
    final result = allocateSupply(requests, [
      for (final s in capacity.values)
        Supply(
          id: s.canonicalId,
          origin: s.origin,
          ingredient: s.ingredient,
          unitGroup: s.unitGroup,
          micros: (s.micros ?? 0) - (used[s.canonicalId] ?? 0),
        ),
    ]);
    final purchases = {
      for (final s in supplies)
        if (s.origin == SupplyOrigin.purchase) s.id,
    };
    for (final a in result.allocations) {
      final contributionId = a.demand.sourceId;
      final same = kept
          .where(
            (k) =>
                k.contributionId == contributionId && k.supplyId == a.supplyId,
          )
          .firstOrNull;
      if (same != null) {
        final micros = (same.micros ?? 0) + a.micros;
        await (_db.update(_db.supplyAllocations)
              ..where((t) => t.id.equals(same.id)))
            .write(SupplyAllocationsCompanion(micros: Value(micros)));
        await _writer.upsertLast(_allocation, same.id);
      } else {
        final id = newId();
        final purchase = purchases.contains(a.supplyId);
        await _db
            .into(_db.supplyAllocations)
            .insert(
              SupplyAllocationsCompanion.insert(
                id: id,
                contributionId: contributionId,
                pantryItemId: Value(purchase ? null : a.supplyId),
                purchasedShoppingItemId: Value(purchase ? a.supplyId : null),
                micros: Value(a.micros),
                createdAt: now,
                householdId: Value(hid),
              ),
            );
        await _writer.upsertLast(_allocation, id);
      }
      perContribution[contributionId] =
          (perContribution[contributionId] ?? 0) + a.micros;
    }

    // 5. Otvorene stavke: po listi i grupi, zbir onoga što preostaje.
    final wholeUnknown = {
      for (final a in kept)
        if (a.coversWholeUnknown) a.contributionId,
    };
    int? remaining(ShoppingContributionRow c) => c.micros == null
        ? (wholeUnknown.contains(c.id) ? 0 : null)
        : c.micros! - (perContribution[c.id] ?? 0);

    final items = {
      for (final i in await (_db.select(
        _db.shoppingItems,
      )..where((t) => t.householdId.equals(hid))).get())
        i.id: i,
    };
    final groups = <(String, String, String), List<ShoppingContributionRow>>{};
    for (final c in contributions.values) {
      final s = sourceById[c.sourceId];
      if (s == null) continue;
      groups
          .putIfAbsent((s.listId, c.ingredientKey, c.unitGroup), () => [])
          .add(c);
    }
    final pointed = <String, String?>{};
    final liveItems = <String>{};
    for (final MapEntry(key: (listId, _, group), value: cs) in groups.entries) {
      cs.sort(compareContributions);
      final open = [
        for (final c in cs)
          if (isOpen(c) && remaining(c) != 0) c,
      ];
      // Postojeća otvorena stavka ove grupe (ne kupljena, ne ručna).
      final current = [
        for (final c in cs)
          if (items[c.shoppingItemId] case final i?
              when !i.isBought && !i.isManual && i.listId == listId)
            i,
      ].firstOrNull;
      if (open.isEmpty) {
        for (final c in cs) {
          pointed[c.id] = null;
        }
        continue;
      }
      final unknown = open.any((c) => remaining(c) == null);
      final total = unknown
          ? null
          : open.fold<int>(0, (sum, c) => sum + remaining(c)!);
      final amount = total == null
          ? null
          : displayAmount(total, open.first.baseUnit);
      final recipeIds = <String>{
        for (final c in open)
          if (sourceById[c.sourceId] case final s?)
            ?(s.recipeId ?? entries[s.planEntryId]?.recipeId),
      }.toList();
      // Ime i kategorija od najranijeg obroka grupe, da se ne menjaju kad
      // se raspodela pomeri.
      final row = ShoppingItemsCompanion(
        name: Value(cs.first.name),
        quantity: Value(amount?.quantity),
        unit: Value(group == unknownGroup ? null : amount?.unit),
        category: Value(cs.first.category),
        fromRecipeIdsJson: Value(jsonEncode(recipeIds)),
      );
      String itemId;
      if (current == null) {
        itemId = newId();
        await _db
            .into(_db.shoppingItems)
            .insert(
              row.copyWith(
                id: Value(itemId),
                listId: Value(listId),
                householdId: Value(hid),
              ),
            );
        await _writer.upsert(_shoppingItem, itemId);
      } else {
        itemId = current.id;
        if (current.name != row.name.value ||
            current.quantity != row.quantity.value ||
            current.unit != row.unit.value ||
            current.category != row.category.value ||
            current.fromRecipeIdsJson != row.fromRecipeIdsJson.value) {
          await (_db.update(
            _db.shoppingItems,
          )..where((t) => t.id.equals(itemId))).write(row);
          await _writer.upsert(_shoppingItem, itemId);
        }
      }
      liveItems.add(itemId);
      for (final c in cs) {
        pointed[c.id] = open.contains(c) ? itemId : null;
      }
    }
    // Doprinos na novu stavku ide posle nje u outbox-u.
    for (final MapEntry(key: id, value: itemId) in pointed.entries) {
      final c = contributions[id]!;
      if (c.shoppingItemId == itemId && !changed.contains(id)) continue;
      if (c.shoppingItemId != itemId) {
        await (_db.update(
          _db.shoppingContributions,
        )..where((t) => t.id.equals(id))).write(
          ShoppingContributionsCompanion(shoppingItemId: Value(itemId)),
        );
      }
      await _writer.upsertLast(_contribution, id);
      for (final a in await (_db.select(
        _db.supplyAllocations,
      )..where((t) => t.contributionId.equals(id))).get()) {
        await _writer.upsertLast(_allocation, a.id);
      }
    }
    // Otvorene stavke koje više ništa ne traži se brišu.
    final candidates = {
      ..._released,
      for (final c in contributions.values) ?c.shoppingItemId,
    };
    _released.clear();
    for (final id in candidates) {
      final old = items[id];
      if (old == null || old.isBought || old.isManual) continue;
      if (liveItems.contains(id)) continue;
      await (_db.delete(_db.shoppingItems)..where((t) => t.id.equals(id))).go();
      await _writer.delete(_shoppingItem, id);
      items.remove(id);
    }
  }
}
