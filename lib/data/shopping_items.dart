part of 'shopping_repository.dart';

/// Čitanje stavki, ručne stavke, kupovina i zbirovi plana.
mixin _ShoppingItems on _ShoppingBase {
  /// Stavke jedne liste, uživo (UI čita iz lokalnog keša).
  Stream<List<ShoppingItemRow>> watchListItems(String listId) =>
      (_db.select(_db.shoppingItems)
            ..where(
              (t) =>
                  t.listId.equals(listId) &
                  t.householdId.equals(_scope.householdId),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  /// Sve stavke nedeljnih lista plana, uživo, uz početak nedelje.
  Stream<List<PlanShoppingItem>> watchPlanItems(String planId) {
    final q =
        _db.select(_db.shoppingItems).join([
            innerJoin(
              _db.shoppingLists,
              _db.shoppingLists.id.equalsExp(_db.shoppingItems.listId),
            ),
          ])
          ..where(
            _db.shoppingLists.mealPlanId.equals(planId) &
                _db.shoppingLists.periodStart.isNotNull() &
                _db.shoppingItems.householdId.equals(_scope.householdId),
          )
          ..orderBy([OrderingTerm.asc(_db.shoppingItems.name)]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          PlanShoppingItem(
            weekStart: CivilDate.fromWire(
              r.readTable(_db.shoppingLists).periodStart!,
            ),
            item: r.readTable(_db.shoppingItems),
          ),
      ],
    );
  }

  /// Stavke liste bez plana (recepti i ručne stavke), uživo. Ne pravi listu.
  Stream<List<ShoppingItemRow>> watchRecipeItems() {
    final q =
        _db.select(_db.shoppingItems).join([
            innerJoin(
              _db.shoppingLists,
              _db.shoppingLists.id.equalsExp(_db.shoppingItems.listId),
            ),
          ])
          ..where(
            _db.shoppingLists.mealPlanId.isNull() &
                _db.shoppingItems.householdId.equals(_scope.householdId),
          )
          ..orderBy([OrderingTerm.asc(_db.shoppingItems.name)]);
    return q.watch().map(
      (rows) => [for (final r in rows) r.readTable(_db.shoppingItems)],
    );
  }

  /// Brza ručna stavka u listi; usklađivanje je nikad ne menja.
  Future<String> addManual(
    String listId,
    String name, {
    double? quantity,
    String? unit,
    String category = 'ostalo',
  }) => _db.transaction(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'Prazno ime');
    final id = newId();
    await _db
        .into(_db.shoppingItems)
        .insert(
          ShoppingItemsCompanion.insert(
            id: id,
            listId: listId,
            name: trimmed,
            quantity: Value(quantity),
            unit: Value(unit),
            category: category,
            isManual: const Value(true),
            householdId: Value(_scope.householdId),
          ),
        );
    await _writer.upsert(_shoppingItem, id);
    return id;
  });

  /// Rezolucija liste i dodavanje su jedna transakcija. Sync može da
  /// zameni lokalni ID liste dok je ekran otvoren.
  Future<String> addManualToList(
    Future<String> Function() resolveList,
    String name, {
    double? quantity,
    String? unit,
    String category = 'ostalo',
  }) => _db.transaction(() async {
    return addManual(
      await resolveList(),
      name,
      quantity: quantity,
      unit: unit,
      category: category,
    );
  });

  /// Briše ručnu stavku koja nije kupljena; ostale stavke se ne brišu ovde.
  Future<bool> deleteManual(String itemId) => _db.transaction(() async {
    final item = await _item(itemId);
    if (item == null || !item.isManual || item.isBought) return false;
    await (_db.delete(
      _db.shoppingItems,
    )..where((t) => t.id.equals(itemId))).go();
    await _writer.delete(_shoppingItem, itemId);
    return true;
  });

  Future<ShoppingItemRow?> _item(String id) =>
      (_db.select(_db.shoppingItems)..where(
            (t) => t.id.equals(id) & t.householdId.equals(_scope.householdId),
          ))
          .getSingleOrNull();

  /// Obroci i pripreme za koje je stavka: za otvorenu iz tekućih doprinosa,
  /// za kupljenu iz zamrznutog porekla kupovine.
  Future<List<ItemSource>> itemSources(String itemId) async {
    final item = await _item(itemId);
    if (item == null) return const [];
    if (item.isBought) return provenanceSources(item.purchaseProvenanceJson);
    return _currentSources(itemId);
  }

  Future<List<ItemSource>> _currentSources(String itemId) async {
    final contributions =
        await (_db.select(_db.shoppingContributions)..where(
              (t) =>
                  t.shoppingItemId.equals(itemId) &
                  t.householdId.equals(_scope.householdId),
            ))
            .get();
    final sources =
        await (_db.select(_db.shoppingSources)..where(
              (t) => t.id.isIn({for (final c in contributions) c.sourceId}),
            ))
            .get();
    final entries = {
      for (final e
          in await (_db.select(_db.mealPlanEntries)..where(
                (t) => t.id.isIn([for (final s in sources) ?s.planEntryId]),
              ))
              .get())
        e.id: e,
    };
    final result = <(DemandOrder, ItemSource)>[];
    for (final s in sources) {
      final entry = entries[s.planEntryId];
      final json = entry?.recipeSnapshotJson ?? s.recipeSnapshotJson;
      if (json == null) continue;
      final RecipeSnapshot snapshot;
      try {
        snapshot = RecipeSnapshot.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
      } on FormatException {
        continue;
      }
      final date = entry == null ? null : CivilDate.fromWire(entry.date);
      result.add((
        DemandOrder(
          date: date?.toWire(),
          mealOrder: entry == null
              ? unplannedMealOrder
              : mealOrder(entry.mealType),
        ),
        ItemSource(
          title: snapshot.title,
          kind: ShoppingSourceKind.values.asNameMap()[s.kind],
          servings:
              (entry == null ? s.servings : entry.servings) ??
              snapshot.baseServings,
          date: date,
          mealType: entry?.mealType,
        ),
      ));
    }
    result.sort((a, b) {
      final (da, db) = (a.$1.date, b.$1.date);
      if (da != db) {
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      }
      return a.$1.mealOrder.compareTo(b.$1.mealOrder);
    });
    return [for (final (_, s) in result) s];
  }

  /// Kupljeno ili poništeno, cela stavka odjednom. Kupovina zamrzava izvore
  /// i pokriva baš one obroke za koje je stavka bila; poništavanje vraća
  /// istu stavku u nabavku. Stavka primljena u ostavu se ne poništava (ista
  /// zaliha je već u ostavi). Ponovljen poziv ne menja ništa. Vraća broj
  /// promenjenih stavki.
  Future<int> setBought(Iterable<String> itemIds, {required bool bought}) =>
      _db.transaction(() async {
        var changed = 0;
        for (final id in itemIds.toSet()) {
          final item = await _item(id);
          if (item == null || item.isBought == bought) continue;
          if (bought) {
            await _buy(item);
          } else {
            if (await _isReceived(id)) continue;
            await _unbuy(item);
          }
          changed++;
        }
        if (changed > 0) await _reconcile();
        return changed;
      });

  Future<bool> _isReceived(String itemId) async =>
      await (_db.select(_db.pantryItems)..where(
            (t) =>
                t.sourceShoppingItemId.equals(itemId) &
                t.householdId.equals(_scope.householdId),
          ))
          .getSingleOrNull() !=
      null;

  Future<void> _buy(ShoppingItemRow item) async {
    final hid = _scope.householdId;
    final now = _clock().toUtc();
    final contributions =
        await (_db.select(_db.shoppingContributions)..where(
              (t) =>
                  t.shoppingItemId.equals(item.id) & t.householdId.equals(hid),
            ))
            .get();
    var quantity = item.quantity;
    var unit = item.unit;
    if (contributions.isNotEmpty) {
      // Stavka pokriva tačno ono što je preostalo njenim obrocima: zaliha
      // ide njima, ne nekom ranijem obroku iste namirnice.
      final allocated = <String, int>{};
      for (final a
          in await (_db.select(_db.supplyAllocations)..where(
                (t) => t.contributionId.isIn([
                  for (final c in contributions) c.id,
                ]),
              ))
              .get()) {
        allocated[a.contributionId] =
            (allocated[a.contributionId] ?? 0) + (a.micros ?? 0);
      }
      var total = 0;
      for (final c in contributions) {
        final micros = c.micros == null
            ? null
            : c.micros! - (allocated[c.id] ?? 0);
        if (micros != null && micros <= 0) continue;
        total += micros ?? 0;
        final id = newId();
        await _db
            .into(_db.supplyAllocations)
            .insert(
              SupplyAllocationsCompanion.insert(
                id: id,
                contributionId: c.id,
                purchasedShoppingItemId: Value(item.id),
                micros: Value(micros),
                coversWholeUnknown: Value(micros == null),
                createdAt: now,
                householdId: Value(hid),
              ),
            );
        await _writer.upsertLast(_allocation, id);
      }
      // Prikaz u kg/l može da zaokruži; kupovina čuva tačan zbir.
      final known = contributions.first.micros != null;
      if (known &&
          (item.quantity == null ||
              toMicros(item.quantity!) * normalizeUnit(item.unit).factor !=
                  total)) {
        quantity = fromMicros(total);
        unit = contributions.first.baseUnit;
      }
    }
    await (_db.update(
      _db.shoppingItems,
    )..where((t) => t.id.equals(item.id))).write(
      ShoppingItemsCompanion(
        isBought: const Value(true),
        quantity: Value(quantity),
        unit: Value(unit),
        purchaseProvenanceJson: Value(
          contributions.isEmpty
              ? null
              : provenanceJson(await _currentSources(item.id)),
        ),
      ),
    );
    await _writer.upsert(_shoppingItem, item.id);
  }

  Future<void> _unbuy(ShoppingItemRow item) async {
    for (final a
        in await (_db.select(_db.supplyAllocations)..where(
              (t) =>
                  t.purchasedShoppingItemId.equals(item.id) &
                  t.householdId.equals(_scope.householdId),
            ))
            .get()) {
      await (_db.delete(
        _db.supplyAllocations,
      )..where((t) => t.id.equals(a.id))).go();
      await _writer.delete(_allocation, a.id);
    }
    await (_db.update(
      _db.shoppingItems,
    )..where((t) => t.id.equals(item.id))).write(
      const ShoppingItemsCompanion(
        isBought: Value(false),
        purchaseProvenanceJson: Value(null),
      ),
    );
    await _writer.upsert(_shoppingItem, item.id);
    // Stavka iz obroka se vraća kao ta ista otvorena stavka (ili briše ako je
    // u međuvremenu sve pokriveno); ručna i stara ostaju kakve jesu.
    if (provenanceSources(item.purchaseProvenanceJson).isNotEmpty &&
        !item.isManual) {
      _reopened.add(item.id);
    }
  }

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
    return ShoppingRepository.totalsOf(items);
  }
}
