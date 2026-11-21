import 'meal_plan.dart';
import 'plan_calendar.dart';
import 'shopping_demand.dart' show fromMicros, normalizeUnit, toMicros;

/// Zašto je oznaka „skuvano“ poništena.
enum UndoReason {
  /// Osoba je pritisnula „Poništi“ / „Nije skuvano“.
  user,
}

/// Jedno označavanje obroka kao skuvanog. Poništavanje ne briše zapis nego
/// upisuje [undoneAt]; ponovno kuvanje pravi novi zapis sa novim id-jem, pa
/// svaki zapis prolazi najviše jedan prelaz (aktivan → poništen).
class CookedEvent {
  const CookedEvent({
    required this.id,
    required this.planEntryId,
    required this.mealDate,
    required this.mealType,
    required this.actorUserId,
    required this.servings,
    required this.cookedAt,
    this.undoneAt,
    this.undoReason,
  });

  /// Identitet operacije (UUID uređaja): ponovljeno slanje ga prepoznaje.
  final String id;
  final String planEntryId;
  final CivilDate mealDate;
  final MealType mealType;

  /// Ko je označio obrok; samo njemu se može automatski upisati unos.
  final String actorUserId;

  /// Porcije obroka u trenutku kuvanja (1–20).
  final int servings;

  /// UTC, sat uređaja.
  final DateTime cookedAt;
  final DateTime? undoneAt;
  final UndoReason? undoReason;

  bool get isActive => undoneAt == null;
}

/// Potrošač operacije (npr. dnevnik ishrane) koji pravi svoje redove. Poziva
/// se u istoj transakciji kao označavanje; greška vraća celu operaciju.
/// Mora biti idempotentan po [CookedEvent.id].
abstract interface class CookedEffect {
  Future<void> onCooked(CookedEvent event);
  Future<void> onUndone(CookedEvent event);
}

/// Važeći zapis obroka: najraniji (cookedAt, id) među neponištenim. Ako su
/// dva uređaja bez mreže označila isti obrok, svi klijenti biraju isti.
CookedEvent? activeEvent(Iterable<CookedEvent> events) {
  CookedEvent? best;
  for (final e in events) {
    if (!e.isActive) continue;
    if (best == null ||
        e.cookedAt.isBefore(best.cookedAt) ||
        (e.cookedAt == best.cookedAt && e.id.compareTo(best.id) < 0)) {
      best = e;
    }
  }
  return best;
}

/// Jedan red potrošnje: koliko je zapis `eventId` uzeo iz stavke ostave,
/// u milionitim delovima osnovne jedinice [baseUnit] (g, ml, kom…).
typedef Consumption = ({
  String eventId,
  String pantryItemId,
  String baseUnit,
  int micros,
});

/// Raspoloživa količina stavke ostave u njenoj jedinici: upisana količina
/// minus potrošnja važećih zapisa skuvanih posle poslednjeg ručnog brojanja
/// ([quantitySetAt]), nikad ispod nule. null kad količina nije poznata.
///
/// [counted] su id-jevi zapisa koji se računaju (važeći zapis svakog
/// obroka); [cookedAt] daje vreme kuvanja po id-ju zapisa. Red potrošnje
/// druge osnovne jedinice (stavci je u međuvremenu promenjena jedinica) se
/// ne oduzima.
double? availableQuantity({
  required double? quantity,
  required String? unit,
  required DateTime? quantitySetAt,
  required Iterable<Consumption> consumptions,
  required Set<String> counted,
  required Map<String, DateTime> cookedAt,
}) {
  if (quantity == null) return null;
  final normalized = normalizeUnit(unit);
  final factor = normalized.factor;
  var micros = toMicros(quantity) * factor;
  for (final c in consumptions) {
    if (!counted.contains(c.eventId)) continue;
    if (c.baseUnit != normalized.base) continue;
    final at = cookedAt[c.eventId];
    if (at == null) continue;
    if (quantitySetAt != null && !at.isAfter(quantitySetAt)) continue;
    micros -= c.micros;
  }
  if (micros <= 0) return 0;
  return fromMicros(micros) / factor;
}
