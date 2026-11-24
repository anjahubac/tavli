part of 'shopping_repository.dart';

/// Izvori nabavke (obroci plana i samostalni recepti) i njihovo brisanje.
mixin _ShoppingSources on _ShoppingBase {
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
    // Obrok može imati više izvora (npr. drugi uređaj ga je stavio u drugu
    // nedelju): zadržava se jedan, ostali se brišu na kraju.
    final allSources =
        await (_db.select(_db.shoppingSources)..where(
              (t) =>
                  t.householdId.equals(_scope.householdId) &
                  t.kind.equals(ShoppingSourceKind.planEntry.name) &
                  t.listId.isIn(planLists),
            ))
            .get();
    final sourcesByEntry = <String, List<ShoppingSourceRow>>{};
    for (final s in allSources) {
      (sourcesByEntry[s.planEntryId!] ??= []).add(s);
    }
    final now = _clock().toUtc();
    final kept = <String>{};
    final deleted = <String>{};
    for (final e in entries) {
      final period = periodFor(range, CivilDate.fromWire(e.date));
      if (e.recipeSnapshotJson == null || period == null) continue;
      final listId = await weekList(planId, period);
      final candidates = sourcesByEntry[e.id] ?? const <ShoppingSourceRow>[];
      var source =
          candidates.where((c) => c.listId == listId).firstOrNull ??
          candidates.firstOrNull;
      if (source != null && source.listId != listId) {
        // Obrok premešten u drugu nedelju: stari izvor oslobađa zalihu.
        await _deleteSource(source.id);
        deleted.add(source.id);
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
    for (final s in allSources) {
      if (!kept.contains(s.id) && !deleted.contains(s.id)) {
        await _deleteSource(s.id);
      }
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

  /// Tekuća (nezamenjena, otvorena) priprema istog porekla, ili null.
  Future<RecipePreparation?> currentPreparation(String originKey) async {
    final row =
        await (_db.select(_db.shoppingSources)
              ..where(
                (t) => _activePreparation(t) & t.originKey.equals(originKey),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _preparation(row);
  }

  /// Tekuće samostalne pripreme, novije prve, uživo.
  Stream<List<RecipePreparation>> watchPreparations() =>
      (_db.select(_db.shoppingSources)
            ..where(_activePreparation)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch()
          .map((rows) => [for (final r in rows) ?_preparation(r)]);

  Expression<bool> _activePreparation($ShoppingSourcesTable t) =>
      t.householdId.equals(_scope.householdId) &
      t.kind.equals(ShoppingSourceKind.recipePreparation.name) &
      t.supersededAt.isNull() &
      t.closedAt.isNull();

  static RecipePreparation? _preparation(ShoppingSourceRow row) {
    final json = row.recipeSnapshotJson;
    if (json == null) return null;
    try {
      final snapshot = RecipeSnapshot.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      return RecipePreparation(
        id: row.id,
        snapshot: snapshot,
        servings: row.servings ?? snapshot.baseServings,
        recipeId: row.recipeId,
      );
    } on FormatException {
      return null;
    }
  }

  /// Recept je u nekom planu kao obrok koji još nije skuvan.
  Future<bool> isPlanned(String recipeId) async =>
      await (_db.select(_db.mealPlanEntries)
            ..where(
              (t) =>
                  t.householdId.equals(_scope.householdId) &
                  t.recipeId.equals(recipeId) &
                  t.isCooked.equals(false),
            )
            ..limit(1))
          .getSingleOrNull() !=
      null;

  /// Uklanja izvor (npr. samostalnu pripremu): oslobađa njegovu zalihu i
  /// otvorenu potrebu; kupljeno ostaje.
  Future<void> removeSource(String sourceId) => _db.transaction(() async {
    await _deleteSource(sourceId);
    await _reconcile();
  });

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

  @override
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
  ///
  /// Vraća `null` kad se postojeći doprinosi izvora moraju ostaviti kakvi
  /// jesu: katalog trenutno nije čitljiv, a izvor ima verodostojne veze. Ključ
  /// se tada ne vraća na tekst, pa privremena greška ne cepa „Maslac“ na
  /// „maslac domaći“ i „putar“ niti gubi stanje kupljeno/izmenjeno.
  @override
  Future<List<DemandLine>?> _demand(
    ShoppingSourceRow s,
    Map<String, MealPlanEntryRow> entries, {
    required CatalogStatus catalogStatus,
    required bool hasContributions,
  }) async {
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
    final validLinks = <String>{
      for (final ingredient in snapshot.ingredients)
        if (ingredient.link case final link?
            when link.matchedKey == ingredientKey(ingredient.name))
          link.foodId,
    };
    final visibleFoods = <String, FoodIdentity>{};
    // Dok pravilo uvođenja nije otvoreno, stariji klijenti ključaju po tekstu;
    // isti domaćinstvo ne sme da dobije drugačije ključeve.
    final readable =
        catalogStatus == CatalogStatus.available ||
        catalogStatus == CatalogStatus.accessDenied;
    if (_recipeLinkRollout.enabled &&
        validLinks.isNotEmpty &&
        hasContributions &&
        !readable) {
      return null;
    }
    for (final foodId in _recipeLinkRollout.enabled ? validLinks : <String>{}) {
      final food = await _catalogReader.visibleFoodById(
        FoodLookupScope(householdId: _scope.householdId),
        foodId,
        status: catalogStatus,
      );
      if (food != null) visibleFoods[food.id] = food;
    }
    return demandFor(
      DemandSource(
        id: s.id,
        baseServings: snapshot.baseServings,
        servings: (servings ?? snapshot.baseServings).clamp(
          minServings,
          maxServings,
        ),
        ingredients: snapshot.ingredients,
        visibleFoods: visibleFoods,
      ),
    );
  }

  /// Zatvoreni i zamenjeni izvori se ne preračunavaju, pa njihovi stari
  /// doprinosi ostaju u grupi koju je jedinica imala pre zajedničkog rečnika
  /// (npr. `unit:dl` ili `unit:dag`). Zaliha se sada računa u osnovnoj
  /// jedinici (ml, g), pa se doprinos i njegova raspodela prebacuju u nju;
  /// inače bi se već raspoređena zaliha vratila kao slobodna. Otvoreni izvori
  /// se preračunavaju sami. Idempotentno: posle prelaska grupa se poklapa.
  @override
  Future<void> _migrateLegacyUnits(
    List<ShoppingSourceRow> sources,
    Map<String, ShoppingContributionRow> contributions,
  ) async {
    final inactive = {
      for (final s in sources)
        if (s.closedAt != null || s.supersededAt != null) s.id,
    };
    for (final c in [...contributions.values]) {
      if (!inactive.contains(c.sourceId) || !c.unitGroup.startsWith('unit:')) {
        continue;
      }
      final unit = normalizeUnit(c.baseUnit);
      if (unit.group == c.unitGroup) continue;

      final allocations = await (_db.select(
        _db.supplyAllocations,
      )..where((t) => t.contributionId.equals(c.id))).get();
      final micros = c.micros == null ? null : c.micros! * unit.factor;
      final target = contributions.values
          .where(
            (o) =>
                o.id != c.id &&
                o.sourceId == c.sourceId &&
                o.ingredientKey == c.ingredientKey &&
                o.unitGroup == unit.group,
          )
          .firstOrNull;

      // Isti sastojak je u tom izvoru već u novoj grupi: spoji doprinose.
      final targetId = target?.id ?? c.id;
      if (target != null) {
        final sum = (target.micros ?? 0) + (micros ?? 0);
        await (_db.update(
          _db.shoppingContributions,
        )..where((t) => t.id.equals(target.id))).write(
          ShoppingContributionsCompanion(
            micros: Value(target.micros == null && micros == null ? null : sum),
          ),
        );
      } else {
        await (_db.update(
          _db.shoppingContributions,
        )..where((t) => t.id.equals(c.id))).write(
          ShoppingContributionsCompanion(
            unitGroup: Value(unit.group),
            baseUnit: Value(unit.base),
            micros: Value(micros),
          ),
        );
      }
      await _writer.upsertLast(_contribution, targetId);
      for (final a in allocations) {
        final moved = a.coversWholeUnknown || a.micros == null
            ? a.micros
            : a.micros! * unit.factor;
        // Cilj već ima raspodelu iz iste zalihe: saberi u nju, jer je
        // (doprinos, zaliha) jedinstveno.
        final existing = target == null
            ? null
            : await (_db.select(_db.supplyAllocations)..where(
                    (t) =>
                        t.contributionId.equals(targetId) &
                        t.supplyId.equals(a.supplyId),
                  ))
                  .getSingleOrNull();
        if (existing != null) {
          await (_db.update(
            _db.supplyAllocations,
          )..where((t) => t.id.equals(existing.id))).write(
            SupplyAllocationsCompanion(
              micros: Value(
                _mergedMicros(existing, a.coversWholeUnknown, moved),
              ),
              // Cela nepoznata količina ostaje samo ako su obe takve; inače
              // se broji poznata količina, da se ista zaliha ne troši dvaput.
              coversWholeUnknown: Value(
                existing.coversWholeUnknown && a.coversWholeUnknown,
              ),
            ),
          );
          await _writer.upsertLast(_allocation, existing.id);
          await (_db.delete(
            _db.supplyAllocations,
          )..where((t) => t.id.equals(a.id))).go();
          await _writer.delete(_allocation, a.id);
          continue;
        }
        await (_db.update(
          _db.supplyAllocations,
        )..where((t) => t.id.equals(a.id))).write(
          SupplyAllocationsCompanion(
            contributionId: Value(targetId),
            micros: Value(moved),
          ),
        );
        await _writer.upsertLast(_allocation, a.id);
      }
      if (target != null) {
        await (_db.delete(
          _db.shoppingContributions,
        )..where((t) => t.id.equals(c.id))).go();
        await _writer.delete(_contribution, c.id);
        contributions.remove(c.id);
      }
      contributions[targetId] = await (_db.select(
        _db.shoppingContributions,
      )..where((t) => t.id.equals(targetId))).getSingle();
    }
  }

  /// Količina spojene raspodele iste zalihe: zbir poznatih količina; kad su
  /// obe raspodele cela nepoznata količina, ostaje njihov zapis.
  static int? _mergedMicros(
    SupplyAllocationRow existing,
    bool movedWhole,
    int? moved,
  ) {
    if (existing.coversWholeUnknown && movedWhole) {
      return existing.micros == null && moved == null
          ? null
          : (existing.micros ?? 0) + (moved ?? 0);
    }
    final known = [
      if (!existing.coversWholeUnknown) existing.micros,
      if (!movedWhole) moved,
    ].nonNulls;
    return known.isEmpty ? null : known.reduce((x, y) => x + y);
  }
}
