import 'package:drift/drift.dart';

import '../account/auth_controller.dart';
import '../domain/cooked_event.dart';
import '../domain/food_matcher.dart';
import '../domain/ids.dart';
import '../domain/meal_plan.dart' show MealType;
import '../domain/plan_calendar.dart';
import '../domain/shopping_demand.dart' show normalizeUnit;
import '../sync/synced_writer.dart';
import 'cooking_repository.dart' show cookedEventFromRow;
import 'database.dart';

/// Ostava domaćinstva; svaka izmena ima outbox u istoj transakciji.
class PantryRepository {
  PantryRepository(
    this._db, {
    required this._scope,
    required this._writer,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final AccountScope _scope;
  final SyncedWriter _writer;
  final DateTime Function() _clock;

  static const _pantryItem = 'pantry_item';
  static const _consumption = 'pantry_consumption';

  /// Prima kupljene stavke u ostavu kao potvrđenu zalihu. Prijem je ista
  /// zaliha kao kupovina (ne nova), pa se ne računa dvaput; ponovljen prijem
  /// ne pravi drugi zapis. Obrok skuvan pre prijema odmah troši svoj deo
  /// kupovine. Vraća broj novih prijema.
  Future<int> receivePurchases(Iterable<String> itemIds) =>
      _db.transaction(() async {
        var received = 0;
        final now = _clock().toUtc();
        for (final itemId in itemIds.toSet()) {
          final item =
              await (_db.select(_db.shoppingItems)..where(
                    (t) =>
                        t.id.equals(itemId) &
                        t.householdId.equals(_scope.householdId),
                  ))
                  .getSingleOrNull();
          if (item == null || !item.isBought) continue;
          final existing =
              await (_db.select(_db.pantryItems)
                    ..where((t) => t.sourceShoppingItemId.equals(itemId)))
                  .getSingleOrNull();
          if (existing != null) continue;
          final id = newId();
          await _db
              .into(_db.pantryItems)
              .insert(
                PantryItemsCompanion.insert(
                  id: id,
                  name: item.name,
                  quantity: Value(item.quantity),
                  unit: Value(item.unit),
                  category: item.category,
                  addedAt: now,
                  confirmedAt: Value(now),
                  sourceShoppingItemId: Value(itemId),
                  householdId: Value(_scope.householdId),
                ),
              );
          await _writer.upsert(_pantryItem, id);
          await _consumeForCookedMeals(item, id, now);
          received++;
        }
        return received;
      });

  /// Kupovina dodeljena obroku koji je skuvan pre prijema: potrošnja se
  /// upisuje sada, za važeći zapis kuvanja tog obroka (ugovor obroka:
  /// raspodela iz kupovine se računa kad je kupovina primljena). Samo
  /// poznata količina iste grupe jedinica; ključ (zapis, stavka) sprečava
  /// dupli red.
  Future<void> _consumeForCookedMeals(
    ShoppingItemRow item,
    String pantryItemId,
    DateTime now,
  ) async {
    if (item.quantity == null) return;
    final hid = _scope.householdId;
    final unit = normalizeUnit(item.unit);
    final allocations =
        await (_db.select(_db.supplyAllocations)..where(
              (t) =>
                  t.purchasedShoppingItemId.equals(item.id) &
                  t.householdId.equals(hid) &
                  t.micros.isNotNull() &
                  t.coversWholeUnknown.equals(false),
            ))
            .get();
    final perEvent = <String, int>{};
    for (final a in allocations) {
      final contribution =
          await (_db.select(_db.shoppingContributions)..where(
                (t) =>
                    t.id.equals(a.contributionId) & t.householdId.equals(hid),
              ))
              .getSingleOrNull();
      if (contribution == null || contribution.unitGroup != unit.group) {
        continue;
      }
      final source =
          await (_db.select(_db.shoppingSources)..where(
                (t) =>
                    t.id.equals(contribution.sourceId) &
                    t.householdId.equals(hid),
              ))
              .getSingleOrNull();
      final entryId = source?.planEntryId;
      if (entryId == null) continue;
      final event = activeEvent([
        for (final r
            in await (_db.select(_db.cookedEvents)..where(
                  (t) =>
                      t.planEntryId.equals(entryId) & t.householdId.equals(hid),
                ))
                .get())
          cookedEventFromRow(r),
      ]);
      if (event == null) continue;
      perEvent[event.id] = (perEvent[event.id] ?? 0) + a.micros!;
    }
    for (final MapEntry(key: eventId, value: micros) in perEvent.entries) {
      final id = newId();
      await _db
          .into(_db.pantryConsumptions)
          .insert(
            PantryConsumptionsCompanion.insert(
              id: id,
              householdId: Value(hid),
              eventId: eventId,
              pantryItemId: pantryItemId,
              baseUnit: unit.base,
              micros: micros,
              createdAt: now,
            ),
          );
      await _writer.upsert(_consumption, id);
    }
  }

  /// Namirnice u ostavi domaćinstva, uživo, po nazivu: raspoloživa
  /// količina (upisana minus kuvanje, nikad ispod nule) ili `null` kad
  /// količina nije poznata. Prisustvo u ostavi znači „imam“.
  Stream<List<PantryEntry>> watchEntries() {
    final hid = _scope.householdId;
    return watchAvailable().asyncMap((available) async {
      final rows =
          await (_db.select(_db.pantryItems)
                ..where((t) => t.householdId.equals(hid))
                ..orderBy([(t) => OrderingTerm.asc(t.addedAt)]))
              .get();
      return pantryEntriesFrom(rows, available);
    });
  }

  /// Upit „šta imam“ (nabavka, predlozi recepata): namirnice koje
  /// domaćinstvo sada ima, sa raspoloživom količinom i id-jem iz kataloga
  /// kad naziv odgovara namirnici ili aliasu iz kataloga ([matcher]).
  /// Namirnica bez poklapanja ima `foodId == null` i ostaje po nazivu.
  Future<List<PantryStock>> whatIHave(FoodMatcher matcher) async {
    final scope = FoodLookupScope(householdId: _scope.householdId);
    return [
      for (final e in await watchEntries().first)
        PantryStock(
          name: e.name,
          foodId: switch (await matcher.findByName(
            originalText: e.name,
            scope: scope,
          )) {
            Matched(:final food) => food.id,
            _ => null,
          },
          quantity: e.quantity,
          unit: e.unit,
        ),
    ];
  }

  /// Dodaje namirnicu u ostavu (potvrđena zaliha, bez porekla u nabavci).
  /// Ako ista namirnica (isti naziv, bez obzira na velika slova) već ima red:
  /// količina se dodaje na postojeću kad je jedinica ista, upisuje kad red
  /// nije imao količinu, a kad je jedinica druga, pravi se poseban red.
  /// Bez količine ništa se ne menja na postojećem redu. Vraća id reda.
  Future<String> add(
    String name, {
    double? quantity,
    String? unit,
    String category = 'ostalo',
  }) => _db.transaction(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name');
    if (quantity != null && (!quantity.isFinite || quantity <= 0)) {
      throw ArgumentError.value(quantity, 'quantity');
    }
    final hid = _scope.householdId;
    final now = _clock().toUtc();
    final cleanUnit = quantity == null || (unit?.trim().isEmpty ?? true)
        ? null
        : unit!.trim();
    final same = [
      for (final r in await (_db.select(
        _db.pantryItems,
      )..where((t) => t.householdId.equals(hid))).get())
        if (r.name.trim().toLowerCase() == trimmed.toLowerCase()) r,
    ];
    for (final r in same) {
      if (quantity == null) {
        // Uklonjena primljena kupovina (količina 0) ponovo je prisutna.
        if (r.quantity == 0) await _setRow(r.id, null, null, now);
        return r.id;
      }
      if (r.quantity == null) {
        await (_db.update(
          _db.pantryItems,
        )..where((t) => t.id.equals(r.id))).write(
          PantryItemsCompanion(
            quantity: Value(quantity),
            unit: Value(cleanUnit),
            quantitySetAt: Value(now),
          ),
        );
        await _writer.upsert(_pantryItem, r.id);
        return r.id;
      }
      if ((r.unit ?? '') == (cleanUnit ?? '')) {
        // Dodaje se na raspoloživo, pa se brojanje postavlja na taj zbir.
        final available = (await watchAvailable().first)[r.id] ?? r.quantity!;
        await (_db.update(
          _db.pantryItems,
        )..where((t) => t.id.equals(r.id))).write(
          PantryItemsCompanion(
            quantity: Value(available + quantity),
            quantitySetAt: Value(now),
          ),
        );
        await _writer.upsert(_pantryItem, r.id);
        return r.id;
      }
    }
    final id = newId();
    await _db
        .into(_db.pantryItems)
        .insert(
          PantryItemsCompanion.insert(
            id: id,
            name: trimmed,
            quantity: Value(quantity),
            unit: Value(cleanUnit),
            category: category,
            addedAt: now,
            confirmedAt: Value(now),
            quantitySetAt: Value(quantity == null ? null : now),
            householdId: Value(hid),
          ),
        );
    await _writer.upsert(_pantryItem, id);
    return id;
  });

  /// Uklanja namirnicu iz ostave (potrošena je), sa svim njenim redovima.
  Future<void> removeEntry(PantryEntry entry) => _db.transaction(() async {
    for (final id in entry.ids) {
      await remove(id);
    }
  });

  /// Ručno brojanje cele namirnice: prvi red dobija upisanu količinu, a
  /// ostali redovi iste namirnice se uklanjaju, da zbir bude tačno upisan.
  Future<void> setEntryQuantity(
    PantryEntry entry,
    double? quantity, {
    String? unit,
  }) => _db.transaction(() async {
    await setQuantity(entry.id, quantity, unit: unit, changeUnit: true);
    for (final id in entry.ids.skip(1)) {
      await remove(id);
    }
  });

  /// Uklanja jedan red ostave. Primljena kupovina se ne briše nego dobija
  /// količinu 0 (skrivena je): red je dokaz prijema, pa bi bez njega ista
  /// kupovina opet čekala „Prebaci u ostavu“ i ušla dvaput. Ostali redovi se
  /// brišu; server briše i njihovu potrošnju i raspodelu (kaskadno), a
  /// lokalno se brišu isto, da se raspoloživo odmah preračuna.
  Future<void> remove(String itemId) => _db.transaction(() async {
    final hid = _scope.householdId;
    final row =
        await (_db.select(_db.pantryItems)
              ..where((t) => t.id.equals(itemId) & t.householdId.equals(hid)))
            .getSingleOrNull();
    if (row == null) return;
    if (row.sourceShoppingItemId != null) {
      await _setRow(itemId, 0, row.unit, _clock().toUtc());
      return;
    }
    final deleted = await (_db.delete(
      _db.pantryItems,
    )..where((t) => t.id.equals(itemId) & t.householdId.equals(hid))).go();
    if (deleted == 0) return;
    await (_db.delete(_db.pantryConsumptions)..where(
          (t) => t.pantryItemId.equals(itemId) & t.householdId.equals(hid),
        ))
        .go();
    await (_db.delete(_db.supplyAllocations)..where(
          (t) => t.pantryItemId.equals(itemId) & t.householdId.equals(hid),
        ))
        .go();
    await _writer.delete(_pantryItem, itemId);
  });

  Future<void> _setRow(
    String itemId,
    double? quantity,
    String? unit,
    DateTime at,
  ) async {
    await (_db.update(
      _db.pantryItems,
    )..where((t) => t.id.equals(itemId))).write(
      PantryItemsCompanion(
        quantity: Value(quantity),
        unit: Value(quantity == null ? null : unit),
        quantitySetAt: Value(at),
      ),
    );
    await _writer.upsert(_pantryItem, itemId);
  }

  /// Kupljene stavke koje su već primljene u ostavu, uživo.
  Stream<Set<String>> watchReceivedItemIds() =>
      (_db.select(_db.pantryItems)..where(
            (t) =>
                t.householdId.equals(_scope.householdId) &
                t.sourceShoppingItemId.isNotNull(),
          ))
          .watch()
          .map((rows) => {for (final r in rows) r.sourceShoppingItemId!});

  /// Ručno brojanje: upisana količina je novo stanje, pa se kuvanje pre ovog
  /// trenutka više ne oduzima (ni kad se kasnije poništi). null = nepoznata.
  /// [unit] se menja samo uz [changeUnit]; bez količine jedinica se briše.
  Future<void> setQuantity(
    String itemId,
    double? quantity, {
    String? unit,
    bool changeUnit = false,
  }) => _db.transaction(() async {
    if (quantity != null && (!quantity.isFinite || quantity < 0)) {
      throw ArgumentError.value(quantity, 'quantity');
    }
    final changed =
        await (_db.update(_db.pantryItems)..where(
              (t) =>
                  t.id.equals(itemId) &
                  t.householdId.equals(_scope.householdId),
            ))
            .write(
              PantryItemsCompanion(
                quantity: Value(quantity),
                quantitySetAt: Value(_clock().toUtc()),
                unit: changeUnit
                    ? Value(quantity == null ? null : unit)
                    : const Value.absent(),
              ),
            );
    if (changed > 0) await _writer.upsert(_pantryItem, itemId);
  });

  /// Dodaje više namirnica odjednom (npr. sa slike), jedna transakcija.
  /// Vraća broj obrađenih stavki.
  Future<int> addAll(
    Iterable<({String name, double? quantity, String? unit, String category})>
    items,
  ) => _db.transaction(() async {
    var n = 0;
    for (final i in items) {
      await add(
        i.name,
        quantity: i.quantity,
        unit: i.unit,
        category: i.category,
      );
      n++;
    }
    return n;
  });

  /// Raspoloživa količina svake stavke ostave (u njenoj jedinici), uživo:
  /// upisana količina minus važeće kuvanje posle poslednjeg brojanja, nikad
  /// ispod nule; null kad količina nije poznata.
  Stream<Map<String, double?>> watchAvailable() {
    final hid = _scope.householdId;
    // Okida se na promenu bilo koje od tri tabele: kuvanje i poništavanje ne
    // menjaju stavke ostave, a menjaju raspoloživu količinu.
    final changes = _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.pantryItems,
            _db.cookedEvents,
            _db.pantryConsumptions,
          },
        )
        .watch();
    return changes.asyncMap((_) async {
      final rows = await (_db.select(
        _db.pantryItems,
      )..where((t) => t.householdId.equals(hid))).get();
      final events = await (_db.select(
        _db.cookedEvents,
      )..where((t) => t.householdId.equals(hid))).get();
      final byEntry = <String, List<CookedEvent>>{};
      for (final e in events) {
        byEntry
            .putIfAbsent(e.planEntryId, () => [])
            .add(
              CookedEvent(
                id: e.id,
                planEntryId: e.planEntryId,
                mealDate: CivilDate.fromWire(e.mealDate),
                mealType: MealType.tryParse(e.mealType) ?? MealType.lunch,
                actorUserId: e.actorUserId,
                servings: e.servings,
                cookedAt: e.cookedAt,
                undoneAt: e.undoneAt,
              ),
            );
      }
      final counted = {
        for (final list in byEntry.values) ?activeEvent(list)?.id,
      };
      final cookedAt = {for (final e in events) e.id: e.cookedAt};
      final consumptions = <String, List<Consumption>>{};
      for (final c in await (_db.select(
        _db.pantryConsumptions,
      )..where((t) => t.householdId.equals(hid))).get()) {
        consumptions.putIfAbsent(c.pantryItemId, () => []).add((
          eventId: c.eventId,
          pantryItemId: c.pantryItemId,
          baseUnit: c.baseUnit,
          micros: c.micros,
        ));
      }
      return {
        for (final r in rows)
          r.id: availableQuantity(
            quantity: r.quantity,
            unit: r.unit,
            quantitySetAt: r.quantitySetAt,
            consumptions: consumptions[r.id] ?? const [],
            counted: counted,
            cookedAt: cookedAt,
          ),
      };
    });
  }
}

/// Red ostave za prikaz: naziv i raspoloživa količina (ili samo naziv).
/// Jedna namirnica iz upita „šta imam“.
class PantryStock {
  const PantryStock({
    required this.name,
    this.foodId,
    this.quantity,
    this.unit,
  });

  final String name;

  /// Id namirnice iz kataloga, ili `null` kad naziv nije u katalogu.
  final String? foodId;

  /// Raspoloživo u jedinici [unit] (može biti 0 posle kuvanja); `null` kad
  /// količina nije poznata, a namirnica je ipak tu.
  final double? quantity;
  final String? unit;
}

class PantryEntry {
  const PantryEntry({
    required this.id,
    required this.name,
    this.quantity,
    this.unit,
    List<String>? ids,
  }) : ids = ids ?? const [];

  /// Red koji dobija ručno brojanje (prvi red namirnice).
  final String id;
  final String name;

  /// Raspoloživo u jedinici [unit]; `null` kad količina nije poznata.
  final double? quantity;
  final String? unit;

  /// Svi redovi ostave koji čine ovu namirnicu, počev od [id].
  final List<String> ids;

  /// Abecedno, bez obzira na velika slova; isti naziv po id-u, da redosled
  /// bude stalan.
  static int byName(PantryEntry a, PantryEntry b) {
    final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return c != 0 ? c : a.id.compareTo(b.id);
  }
}

/// Spaja redove ostave u namirnice kako ih osoba vidi: isti naziv (bez
/// obzira na velika slova) i ista jedinica su jedna namirnica sa zbirom
/// raspoloživog. Red bez količine ulazi u namirnicu istog naziva koja ima
/// količinu; red sa upisanom količinom 0 (uklonjena kupovina) se ne vidi.
/// [rows] su po redosledu dodavanja; [available] je iz `watchAvailable`.
List<PantryEntry> pantryEntriesFrom(
  List<PantryItemRow> rows,
  Map<String, double?> available,
) {
  String nameKey(PantryItemRow r) => r.name.trim().toLowerCase();
  final groups = <(String, String), List<PantryItemRow>>{};
  final presence = <String, List<PantryItemRow>>{};
  for (final r in rows) {
    if (r.quantity == 0) continue;
    if (r.quantity == null) {
      presence.putIfAbsent(nameKey(r), () => []).add(r);
    } else {
      groups.putIfAbsent((nameKey(r), r.unit ?? ''), () => []).add(r);
    }
  }
  final entries = <PantryEntry>[];
  final absorbed = <String>{};
  for (final MapEntry(key: (name, _), value: group) in groups.entries) {
    final extra = absorbed.add(name)
        ? presence[name] ?? const <PantryItemRow>[]
        : const <PantryItemRow>[];
    entries.add(
      PantryEntry(
        id: group.first.id,
        name: group.first.name.trim(),
        quantity: group.fold<double>(
          0,
          (sum, r) => sum + (available[r.id] ?? r.quantity!),
        ),
        unit: group.first.unit,
        ids: [for (final r in group) r.id, for (final r in extra) r.id],
      ),
    );
  }
  for (final MapEntry(key: name, value: group) in presence.entries) {
    if (absorbed.contains(name)) continue;
    entries.add(
      PantryEntry(
        id: group.first.id,
        name: group.first.name.trim(),
        ids: [for (final r in group) r.id],
      ),
    );
  }
  return entries..sort(PantryEntry.byName);
}
