import 'dart:convert';

import 'package:drift/drift.dart';

import '../account/auth_controller.dart';
import '../domain/cooked_event.dart';
import '../domain/ids.dart';
import '../domain/meal_plan.dart';
import '../domain/plan_calendar.dart';
import '../domain/shopping_demand.dart'
    show maxServings, minServings, normalizeUnit;
import '../domain/shopping_source.dart' show RecipeSnapshot;
import '../sync/synced_writer.dart';
import 'database.dart';
import 'meal_plan_repository.dart';

/// Jedino mesto za oznaku „skuvano“ i njeno poništavanje (Početna, Plan,
/// režim kuvanja). Jedna transakcija upisuje zapis kuvanja, oznaku obroka,
/// potrošnju iz ostave, usklađuje nabavku i poziva [CookedEffect]-e, sa
/// outbox-om. Ponovljeno označavanje ili poništavanje ništa ne menja.
class CookingRepository {
  CookingRepository(
    this._db, {
    required this._scope,
    required this._writer,
    required this._plans,
    this._effects = const [],
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final AccountScope _scope;
  final SyncedWriter _writer;
  final MealPlanRepository _plans;
  final List<CookedEffect> _effects;
  final DateTime Function() _clock;

  static const _event = 'cooked_event';
  static const _consumption = 'pantry_consumption';

  /// Označava obrok kao skuvan i vraća važeći zapis. Već skuvan obrok vraća
  /// postojeći zapis i ništa ne menja; obrok skuvan pre ove verzije (bez
  /// zapisa) vraća null i takođe ništa ne menja.
  Future<CookedEvent?> markCooked(String entryId) => _db.transaction(() async {
    final entry = await _findEntry(entryId);
    final current = activeEvent(await _events(entryId));
    if (current != null) {
      if (!entry.isCooked) {
        await _plans.setCooked(entryId, cooked: true);
      }
      return current;
    }
    if (entry.isCooked) return null;

    final now = _clock().toUtc();
    final event = CookedEvent(
      id: newId(),
      planEntryId: entryId,
      mealDate: CivilDate.fromWire(entry.date),
      mealType: MealType.tryParse(entry.mealType) ?? MealType.lunch,
      actorUserId: _scope.userId,
      // Server prima 1–20; porcije recepta (stari obrok bez porcija) nemaju
      // gornju granicu.
      servings: (entry.servings ?? _snapshotOf(entry)?.baseServings ?? 2).clamp(
        minServings,
        maxServings,
      ),
      cookedAt: now,
    );
    await _db
        .into(_db.cookedEvents)
        .insert(
          CookedEventsCompanion.insert(
            id: event.id,
            householdId: Value(_scope.householdId),
            planEntryId: entryId,
            mealDate: entry.date,
            mealType: entry.mealType,
            actorUserId: event.actorUserId,
            servings: event.servings,
            cookedAt: now,
          ),
        );
    await _writer.upsert(_event, event.id);

    // Potrošnja pre usklađivanja nabavke: raspodela zalihe za ovaj obrok
    // tada još pokazuje šta je obrok trebalo da uzme.
    for (final MapEntry(key: itemId, value: (baseUnit, micros))
        in (await _consumptionFor(entryId)).entries) {
      final id = newId();
      await _db
          .into(_db.pantryConsumptions)
          .insert(
            PantryConsumptionsCompanion.insert(
              id: id,
              householdId: Value(_scope.householdId),
              eventId: event.id,
              pantryItemId: itemId,
              baseUnit: baseUnit,
              micros: micros,
              createdAt: now,
            ),
          );
      await _writer.upsert(_consumption, id);
    }

    await _plans.setCooked(entryId, cooked: true);
    for (final effect in _effects) {
      await effect.onCooked(event);
    }
    return event;
  });

  /// Poništava oznaku: zapis dobija vreme poništavanja (ne briše se), njegova
  /// potrošnja prestaje da se računa, nabavka se ponovo otvara. Bez važećeg
  /// zapisa vraća null; obrok skuvan pre ove verzije samo gubi oznaku.
  Future<CookedEvent?> undoCooked(String entryId) => _db.transaction(() async {
    final entry = await _findEntry(entryId);
    final events = await _events(entryId);
    final current = activeEvent(events);
    if (current == null) {
      if (entry.isCooked) await _plans.setCooked(entryId, cooked: false);
      return null;
    }
    final now = _clock().toUtc();
    // I duplikati sa drugog uređaja se zatvaraju, da obrok ostane neskuvan.
    final closed = [
      current.id,
      for (final e in events)
        if (e.isActive && e.id != current.id) e.id,
    ];
    for (final id in closed) {
      await (_db.update(_db.cookedEvents)..where((t) => t.id.equals(id))).write(
        CookedEventsCompanion(
          undoneAt: Value(now),
          undoReason: Value(UndoReason.user.name),
        ),
      );
      await _writer.upsert(_event, id);
    }
    await _plans.setCooked(entryId, cooked: false);
    // Potrošači dobijaju svaki zatvoreni zapis (i duplikat), da ne ostane
    // npr. unos u dnevniku ishrane za zapis koji više ne važi.
    late CookedEvent undone;
    for (final id in closed) {
      final event = cookedEventFromRow(
        await (_db.select(
          _db.cookedEvents,
        )..where((t) => t.id.equals(id))).getSingle(),
      );
      if (id == current.id) undone = event;
      for (final effect in _effects) {
        await effect.onUndone(event);
      }
    }
    return undone;
  });

  /// Posle preuzimanja: oznaka obroka se ponovo izvodi iz zapisa kuvanja.
  /// Ceo red obroka se šalje i čuva po principu „poslednji upis pobeđuje“,
  /// pa zastareo red sa drugog uređaja može da vrati staru oznaku. Obrok bez
  /// ijednog zapisa (skuvan pre ove verzije) se ne dira. Vraća broj
  /// ispravljenih obroka; svaka ispravka usklađuje i nabavku i ide u outbox.
  Future<int> reconcileCookedFlags() => _db.transaction(() async {
    final hid = _scope.householdId;
    final byEntry = <String, List<CookedEvent>>{};
    for (final r in await (_db.select(
      _db.cookedEvents,
    )..where((t) => t.householdId.equals(hid))).get()) {
      byEntry.putIfAbsent(r.planEntryId, () => []).add(cookedEventFromRow(r));
    }
    if (byEntry.isEmpty) return 0;
    var fixed = 0;
    for (final entry
        in await (_db.select(_db.mealPlanEntries)..where(
              (t) => t.id.isIn(byEntry.keys) & t.householdId.equals(hid),
            ))
            .get()) {
      final cooked = activeEvent(byEntry[entry.id]!) != null;
      if (entry.isCooked == cooked) continue;
      await _plans.setCooked(entry.id, cooked: cooked);
      fixed++;
    }
    return fixed;
  });

  /// Važeći zapis obroka, uživo (null = nije skuvan).
  Stream<CookedEvent?> watchActive(String entryId) =>
      (_db.select(_db.cookedEvents)..where(
            (t) =>
                t.planEntryId.equals(entryId) &
                t.householdId.equals(_scope.householdId),
          ))
          .watch()
          .map((rows) => activeEvent(rows.map(cookedEventFromRow)));

  Future<List<CookedEvent>> _events(String entryId) async => [
    for (final r
        in await (_db.select(_db.cookedEvents)..where(
              (t) =>
                  t.planEntryId.equals(entryId) &
                  t.householdId.equals(_scope.householdId),
            ))
            .get())
      cookedEventFromRow(r),
  ];

  /// Koliko obrok uzima iz svake stavke ostave: zaliha koja je u nabavci već
  /// dodeljena tom obroku (iz ostave ili kupovina primljena u ostavu). Samo
  /// potvrđena stavka poznate količine iste grupe jedinica; bez raspodele
  /// nema potrošnje. Vraća id stavke → (osnovna jedinica, milioniti delovi).
  Future<Map<String, (String, int)>> _consumptionFor(String entryId) async {
    final hid = _scope.householdId;
    final sources =
        await (_db.select(_db.shoppingSources)..where(
              (t) => t.planEntryId.equals(entryId) & t.householdId.equals(hid),
            ))
            .get();
    if (sources.isEmpty) return const {};
    final contributions = {
      for (final c
          in await (_db.select(_db.shoppingContributions)..where(
                (t) =>
                    t.sourceId.isIn([for (final s in sources) s.id]) &
                    t.householdId.equals(hid),
              ))
              .get())
        c.id: c,
    };
    if (contributions.isEmpty) return const {};
    final allocations =
        await (_db.select(_db.supplyAllocations)..where(
              (t) =>
                  t.contributionId.isIn(contributions.keys) &
                  t.householdId.equals(hid) &
                  t.micros.isNotNull() &
                  t.coversWholeUnknown.equals(false),
            ))
            .get();
    final result = <String, (String, int)>{};
    for (final a in allocations) {
      final pantry = a.pantryItemId != null
          ? await (_db.select(_db.pantryItems)..where(
                  (t) =>
                      t.id.equals(a.pantryItemId!) & t.householdId.equals(hid),
                ))
                .getSingleOrNull()
          : await (_db.select(_db.pantryItems)..where(
                  (t) =>
                      t.sourceShoppingItemId.equals(
                        a.purchasedShoppingItemId!,
                      ) &
                      t.householdId.equals(hid),
                ))
                .getSingleOrNull();
      if (pantry == null ||
          pantry.quantity == null ||
          pantry.confirmedAt == null) {
        continue;
      }
      final unit = normalizeUnit(pantry.unit);
      if (contributions[a.contributionId]!.unitGroup != unit.group) continue;
      final (_, sum) = result[pantry.id] ?? (unit.base, 0);
      result[pantry.id] = (unit.base, sum + a.micros!);
    }
    return result;
  }

  Future<MealPlanEntryRow> _findEntry(String entryId) async {
    final e =
        await (_db.select(_db.mealPlanEntries)..where(
              (t) =>
                  t.id.equals(entryId) &
                  t.householdId.equals(_scope.householdId),
            ))
            .getSingleOrNull();
    if (e == null) throw const MealNotFoundException();
    return e;
  }

  static RecipeSnapshot? _snapshotOf(MealPlanEntryRow e) {
    final json = e.recipeSnapshotJson;
    if (json == null) return null;
    // Bilo kakva greška čitanja (i pogrešan tip polja, TypeError) znači
    // „nema upotrebljivog zapisa“: obrok se i tada može skuvati.
    try {
      return RecipeSnapshot.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }
}

/// Red baze → [CookedEvent].
CookedEvent cookedEventFromRow(CookedEventRow r) => CookedEvent(
  id: r.id,
  planEntryId: r.planEntryId,
  mealDate: CivilDate.fromWire(r.mealDate),
  mealType: MealType.tryParse(r.mealType) ?? MealType.lunch,
  actorUserId: r.actorUserId,
  servings: r.servings,
  cookedAt: r.cookedAt,
  undoneAt: r.undoneAt,
  undoReason: r.undoReason == null
      ? null
      : UndoReason.values.asNameMap()[r.undoReason] ?? UndoReason.user,
);
