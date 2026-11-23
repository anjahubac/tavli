part of 'shopping_repository.dart';

/// Usklađivanje doprinosa, raspodele zalihe i otvorenih stavki domaćinstva.
mixin _ShoppingReconcile on _ShoppingBase {
  /// Celo domaćinstvo: doprinosi otvorenih izvora prate odobrene recepte,
  /// potvrđena zaliha se raspoređuje hronološki, a otvorene stavke
  /// pokazuju samo ono što preostaje. Kupljene, ručne i stare stavke se ne
  /// menjaju.
  @override
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
    await _migrateLegacyUnits(sources, contributions);
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
    // I received purchase belongs to the pantry lifecycle from this point on,
    // even if its quantity is later cleared. Keep its original bought row
    // from restoring stale numeric supply while the linked pantry row is
    // unknown or expired.
    final receivedPurchaseIds = {
      for (final p
          in await (_db.select(_db.pantryItems)..where(
                (t) =>
                    t.householdId.equals(hid) &
                    t.sourceShoppingItemId.isNotNull(),
              ))
              .get())
        p.sourceShoppingItemId!,
    };
    for (final i
        in await (_db.select(_db.shoppingItems)..where(
              (t) =>
                  t.householdId.equals(hid) &
                  t.isBought.equals(true) &
                  t.quantity.isNotNull(),
            ))
            .get()) {
      if (receivedPurchaseIds.contains(i.id)) continue;
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
    for (final MapEntry(key: (listId, ingredient, group), value: cs)
        in groups.entries) {
      cs.sort(compareContributions);
      final open = [
        for (final c in cs)
          if (isOpen(c) && remaining(c) != 0) c,
      ];
      // Postojeća otvorena stavka ove grupe (ne kupljena, ne ručna), ili
      // upravo poništena kupovina iste grupe.
      final current =
          [
            for (final c in cs)
              if (items[c.shoppingItemId] case final i?
                  when !i.isBought && !i.isManual && i.listId == listId)
                i,
          ].firstOrNull ??
          [
            for (final id in _reopened)
              if (items[id] case final i?
                  when !i.isBought &&
                      i.listId == listId &&
                      ingredientKey(i.name) == ingredient &&
                      (i.quantity == null
                              ? unknownGroup
                              : normalizeUnit(i.unit).group) ==
                          group &&
                      !liveItems.contains(id))
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
      ..._reopened,
      for (final c in contributions.values) ?c.shoppingItemId,
    };
    _released.clear();
    _reopened.clear();
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
