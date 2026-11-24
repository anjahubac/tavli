import '../ai/ai_units.dart';
import 'recipe.dart';
import 'shopping_sync.dart';

/// Količine se porede u fiksnoj preciznosti od šest decimala: kao ceo broj
/// milionitih delova osnovne jedinice (g, ml, kom...).
const microsPerUnit = 1000000;

/// Porcije unosa plana i pripreme su 1–20, kao pri pravljenju recepta.
const minServings = 1;
const maxServings = 20;

/// Grupa jedinica za sastojak bez poznate količine; uvek ide na proveru.
const unknownGroup = 'unknown';

/// Pretvara količinu u milionite delove. Negativna i nekonačna vrednost nije
/// potvrđena količina, pa baca [ArgumentError].
int toMicros(double quantity) {
  if (!quantity.isFinite || quantity < 0) {
    throw ArgumentError.value(quantity, 'quantity', 'Neispravna količina');
  }
  return (quantity * microsPerUnit).round();
}

double fromMicros(int micros) => micros / microsPerUnit;

typedef NormalizedUnit = ({String group, String base, int factor});

const _units = <String, NormalizedUnit>{
  'g': (group: 'mass', base: 'g', factor: 1),
  'dkg': (group: 'mass', base: 'g', factor: 10),
  'kg': (group: 'mass', base: 'g', factor: 1000),
  'ml': (group: 'volume', base: 'ml', factor: 1),
  'dl': (group: 'volume', base: 'ml', factor: 100),
  'l': (group: 'volume', base: 'ml', factor: 1000),
  'kom': (group: 'count:kom', base: 'kom', factor: 1),
};

/// Predložene podrazumevane zapremine; uobičajene mere su približne.
const _kitchenVolume = <String, int>{
  'čaša': 200,
  'šolja': 250,
  'kašika': 15,
  'kašičica': 5,
};

/// Da li je jedinica jedna od približnih kuhinjskih mera iz specifikacije 017.
bool isApproximateKitchenMeasure(String? unit) =>
    _kitchenVolume.containsKey(canonicalUnit(unit));

String _unitText(String? unit) =>
    (unit ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Jedinica se prepoznaje preko zajedničkog rečnika (`canonicalUnit`), pa
/// "gr", "dag", "kasika" i "čaše" imaju isti ključ kao i njihov kanonski
/// oblik. Nepoznata jedinica ostaje svoja grupa, tačno kako je napisana.
///
/// Kuhinjske mere su isključene dok se ne obezbedi verzionisanje podataka.
NormalizedUnit normalizeUnit(String? unit, {bool kitchenMeasures = false}) {
  final u = canonicalUnit(unit) ?? _unitText(unit);
  final kitchenFactor = kitchenMeasures ? _kitchenVolume[u] : null;
  if (kitchenFactor != null) {
    return (group: 'volume', base: 'ml', factor: kitchenFactor);
  }
  return _units[u] ?? (group: 'unit:$u', base: u, factor: 1);
}

void _checkServings(int value, String name, {bool upper = true}) {
  if (value < minServings || (upper && value > maxServings)) {
    throw ArgumentError.value(value, name, 'Porcije van opsega');
  }
}

/// Količina sastojka za [servings] porcija recepta pravljenog za
/// [baseServings]. Nepoznata količina ostaje nepoznata.
double? scaleQuantity(
  double? quantity, {
  required int baseServings,
  required int servings,
}) {
  _checkServings(baseServings, 'baseServings', upper: false);
  _checkServings(servings, 'servings');
  return quantity == null ? null : quantity * servings / baseServings;
}

/// Jedan izvor potražnje: planirani obrok ili samostalna priprema recepta,
/// sa odobrenim sastojcima i porcijama.
class DemandSource {
  const DemandSource({
    required this.id,
    required this.baseServings,
    required this.servings,
    required this.ingredients,
    this.kitchenMeasures = false,
  });

  final String id;
  final int baseServings;
  final int servings;
  final List<Ingredient> ingredients;

  /// Ne uključivati u sačuvanim izvorima bez kompatibilnog zapisa konverzije.
  final bool kitchenMeasures;
}

/// Identitet potražnje: izvor + sastojak + grupa uporedivih jedinica. Isti
/// recept dva puta u planu ima dva izvora, pa i dve odvojene potrebe.
typedef DemandKey = ({String sourceId, String ingredient, String unitGroup});

class DemandLine {
  const DemandLine({
    required this.key,
    required this.name,
    required this.category,
    required this.micros,
    required this.baseUnit,
    this.notes = const [],
    this.approximate = false,
    this.unsupportedUnit = false,
  });

  final DemandKey key;
  final String name;
  final String category;

  /// Potrebna količina u [baseUnit]; `null` kad količina nije poznata.
  final int? micros;
  final String baseUnit;
  final List<String> notes;
  final bool approximate;
  final bool unsupportedUnit;

  bool get isUnknown => micros == null;

  /// Nepoznata količina ili nepodržana jedinica traže proveru.
  bool get needsReview => isUnknown || unsupportedUnit;
}

/// Potrebe jednog izvora, skalirane na njegove porcije. Redovi istog sastojka
/// se spajaju samo kad su jedinice uporedive.
List<DemandLine> demandFor(DemandSource source) {
  _checkServings(source.baseServings, 'baseServings', upper: false);
  _checkServings(source.servings, 'servings');
  final merged = <DemandKey, DemandLine>{};
  for (final i in source.ingredients) {
    final unit = normalizeUnit(i.unit, kitchenMeasures: source.kitchenMeasures);
    final q = i.quantity;
    final known = q != null && q.isFinite && q >= 0;
    final key = (
      sourceId: source.id,
      ingredient: ingredientKey(i.name),
      unitGroup: known ? unit.group : unknownGroup,
    );
    final micros = known
        ? _scale(
            toMicros(q) * unit.factor,
            source.servings,
            source.baseServings,
          )
        : null;
    final prev = merged[key];
    merged[key] = DemandLine(
      key: key,
      name: prev?.name ?? i.name.trim(),
      category: prev?.category ?? i.category,
      micros: prev == null
          ? micros
          : (micros == null ? null : prev.micros! + micros),
      baseUnit: prev?.baseUnit ?? unit.base,
      notes: [...?prev?.notes, if (i.note != null) i.note!],
      unsupportedUnit:
          (prev?.unsupportedUnit ?? false) ||
          (source.kitchenMeasures &&
              unit.base.isNotEmpty &&
              unit.group.startsWith('unit:')),
      approximate:
          (prev?.approximate ?? false) ||
          (known &&
              source.kitchenMeasures &&
              _kitchenVolume.containsKey(canonicalUnit(i.unit))),
    );
  }
  return merged.values.toList();
}

int _scale(int micros, int servings, int base) =>
    (micros * servings + base ~/ 2) ~/ base;

/// Zbir istih sastojaka iz više izvora za prikaz liste. Izvori ostaju
/// vidljivi; nepoznate količine se ne sabiraju sa poznatim.
class ShoppingNeed {
  const ShoppingNeed({
    required this.ingredient,
    required this.unitGroup,
    required this.name,
    required this.category,
    required this.micros,
    required this.baseUnit,
    required this.sourceIds,
    this.approximate = false,
    this.unsupportedUnit = false,
  });

  final String ingredient;
  final String unitGroup;
  final String name;
  final String category;
  final int? micros;
  final String baseUnit;
  final List<String> sourceIds;
  final bool approximate;
  final bool unsupportedUnit;

  bool get isUnknown => micros == null;
  bool get needsReview => isUnknown || unsupportedUnit;
}

List<ShoppingNeed> summarize(Iterable<DemandLine> lines) {
  final groups = <(String, String), List<DemandLine>>{};
  for (final l in lines) {
    groups.putIfAbsent((l.key.ingredient, l.key.unitGroup), () => []).add(l);
  }
  return [
    for (final MapEntry(key: (ingredient, group), value: ls) in groups.entries)
      ShoppingNeed(
        ingredient: ingredient,
        unitGroup: group,
        name: ls.first.name,
        category: ls.first.category,
        micros: group == unknownGroup
            ? null
            : ls.fold<int>(0, (sum, l) => sum + l.micros!),
        baseUnit: ls.first.baseUnit,
        sourceIds: {for (final l in ls) l.key.sourceId}.toList(),
        approximate: ls.any((l) => l.approximate),
        unsupportedUnit: ls.any((l) => l.unsupportedUnit),
      ),
  ];
}

/// Količina za prikaz: od 1000 g/ml naviše u kg/l.
({double quantity, String unit}) displayAmount(int micros, String baseUnit) {
  final q = fromMicros(micros);
  if (q >= 1000 && baseUnit == 'g') return (quantity: q / 1000, unit: 'kg');
  if (q >= 1000 && baseUnit == 'ml') return (quantity: q / 1000, unit: 'l');
  return (quantity: q, unit: baseUnit);
}
