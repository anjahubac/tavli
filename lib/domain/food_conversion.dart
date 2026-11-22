import '../ai/ai_units.dart';
import 'food_matcher.dart';
import 'shopping_demand.dart';

/// Pretvaranje količine u osnovnu jedinicu namirnice (D1-010, predlog u
/// specs/018-ingredient-catalog/unit-conversion-proposal.md). Čista funkcija:
/// bez baze i mreže, isti ulaz daje isti rezultat.

/// Zašto količina ne može da se pretvori i ostaje za "Proveri količinu".
enum ConversionReview {
  /// Nema količine ili nije pozitivan konačan broj.
  unknownQuantity,

  /// Jedinica nije u rečniku ili se ne pretvara (npr. prstohvat); kuhinjske
  /// mere takođe, dok izvor nije uključio.
  unsupportedUnit,

  /// Pretvaranje traži gustinu ili težinu komada koje namirnica nema.
  missingFactor,

  /// "Pakovanje" bez izričito izabranog i poznatog pakovanja.
  unverifiedPackage,

  /// Količina ili zbir ne staje u celobrojne milionite delove; ne ograničava
  /// se tiho nego ide na proveru.
  outOfRange,
}

/// Najveća količina u milionitim delovima (ispod granice 64-bitnog celog
/// broja, da zaokruživanje i sabiranje ostanu tačni).
const maxConvertedMicros = 9000000000000000000;

sealed class UnitConversion {
  const UnitConversion();
}

/// Količina u celobrojnim milionitim delovima osnovne jedinice.
/// [approximate] je istina kad je korišćen faktor namirnice ili kuhinjska mera
/// (prikaz sa "~").
final class Converted extends UnitConversion {
  const Converted(this.micros, this.base, {required this.approximate});

  final int micros;
  final FoodBaseUnit base;
  final bool approximate;
}

/// Originalna količina i jedinica ostaju neizmenjene; ništa se ne računa kao
/// nula ni kao izmišljen ekvivalent.
final class NeedsReview extends UnitConversion {
  const NeedsReview(this.reason);

  final ConversionReview reason;
}

/// Neto sadržaj jednog pakovanja, npr. 400 g.
final class PackageAmount {
  const PackageAmount(this.quantity, this.unit);

  final double quantity;
  final String unit;
}

/// Faktori jedne namirnice, već razrešeni (zajednički ili domaćinstva).
/// Faktor koji nije pozitivan i konačan važi kao da ga nema.
final class FoodConversionFactors {
  const FoodConversionFactors({
    this.densityGPerMl,
    this.pieceWeightG,
    this.packages = const {},
  });

  /// Grama po mililitru.
  final double? densityGPerMl;

  /// Grama po komadu.
  final double? pieceWeightG;

  /// Pakovanja po identifikatoru (izričit izbor, ne nagađanje).
  final Map<String, PackageAmount> packages;

  double? get _density => _valid(densityGPerMl);
  double? get _pieceWeight => _valid(pieceWeightG);

  static double? _valid(double? v) =>
      v != null && v.isFinite && v > 0 ? v : null;
}

enum _Kind { mass, volume, count }

/// Neto sadržaj pakovanja je pozitivan konačan broj mase, zapremine ili
/// komada; kuhinjska mera, prstohvat ili "pakovanje" to nisu.
bool _validNet(PackageAmount p) {
  if (!p.quantity.isFinite || p.quantity <= 0) return false;
  final group = normalizeUnit(p.unit).group;
  return group == 'mass' || group == 'volume' || group == 'count:kom';
}

/// Pretvara [quantity] u [unit] u osnovnu jedinicu [target].
///
/// Jedinice iste dimenzije se pretvaraju tačno; ostalo traži faktor namirnice
/// i daje približan rezultat. Zaokruživanje na celobrojne milionite delove je
/// jednom, na kraju. [packageId] mora da bude izričito izabrano pakovanje.
UnitConversion convertQuantity({
  required double? quantity,
  required String? unit,
  required FoodBaseUnit target,
  FoodConversionFactors factors = const FoodConversionFactors(),
  bool kitchenMeasures = false,
  String? packageId,
}) {
  if (quantity == null || !quantity.isFinite || quantity <= 0) {
    return const NeedsReview(ConversionReview.unknownQuantity);
  }
  if (canonicalUnit(unit) == 'pakovanje') {
    final pack = packageId == null ? null : factors.packages[packageId];
    if (pack == null || !_validNet(pack)) {
      return const NeedsReview(ConversionReview.unverifiedPackage);
    }
    final inner = convertQuantity(
      quantity: quantity * pack.quantity,
      unit: pack.unit,
      target: target,
      factors: FoodConversionFactors(
        densityGPerMl: factors.densityGPerMl,
        pieceWeightG: factors.pieceWeightG,
      ),
      // Kuhinjske procene važe za izvornu količinu, ne za neto pakovanja.
    );
    // Neto sadržaj je procena proizvođača, pa je rezultat približan.
    return inner is Converted
        ? Converted(inner.micros, inner.base, approximate: true)
        : inner;
  }

  final normalized = normalizeUnit(unit, kitchenMeasures: kitchenMeasures);
  final kind = switch (normalized.group) {
    'mass' => _Kind.mass,
    'volume' => _Kind.volume,
    'count:kom' => _Kind.count,
    _ => null,
  };
  if (kind == null) {
    return const NeedsReview(ConversionReview.unsupportedUnit);
  }
  // Kuhinjska mera (čaša, kašika...) je približna i kad se ne koristi faktor.
  final kitchenUsed =
      kitchenMeasures && normalizeUnit(unit).group.startsWith('unit:');
  final amount = quantity * normalized.factor;
  final density = factors._density;
  final pieceWeight = factors._pieceWeight;

  double? value;
  var usedFactor = false;
  switch ((target, kind)) {
    case (FoodBaseUnit.gram, _Kind.mass) ||
        (FoodBaseUnit.milliliter, _Kind.volume) ||
        (FoodBaseUnit.piece, _Kind.count):
      value = amount;
    case (FoodBaseUnit.gram, _Kind.volume):
      if (density != null) value = amount * density;
      usedFactor = true;
    case (FoodBaseUnit.gram, _Kind.count):
      if (pieceWeight != null) value = amount * pieceWeight;
      usedFactor = true;
    case (FoodBaseUnit.milliliter, _Kind.mass):
      if (density != null) value = amount / density;
      usedFactor = true;
    case (FoodBaseUnit.milliliter, _Kind.count):
      if (density != null && pieceWeight != null) {
        value = amount * pieceWeight / density;
      }
      usedFactor = true;
    case (FoodBaseUnit.piece, _Kind.mass):
      if (pieceWeight != null) value = amount / pieceWeight;
      usedFactor = true;
    case (FoodBaseUnit.piece, _Kind.volume):
      if (density != null && pieceWeight != null) {
        value = amount * density / pieceWeight;
      }
      usedFactor = true;
  }
  if (value == null) return const NeedsReview(ConversionReview.missingFactor);
  final scaled = value * microsPerUnit;
  if (!scaled.isFinite || scaled > maxConvertedMicros) {
    return const NeedsReview(ConversionReview.outOfRange);
  }
  return Converted(
    scaled.round(),
    target,
    approximate: usedFactor || kitchenUsed,
  );
}

/// Zbir pretvorenih količina iste namirnice u istoj osnovnoj jedinici. Ono što
/// ne može da se pretvori ne ulazi u zbir nego u [review].
final class ConversionTotal {
  const ConversionTotal(this.micros, this.base, this.approximate, this.review);

  final int micros;
  final FoodBaseUnit? base;
  final bool approximate;
  final List<NeedsReview> review;
}

ConversionTotal totalOf(Iterable<UnitConversion> parts) {
  var micros = 0;
  var approximate = false;
  FoodBaseUnit? base;
  final review = <NeedsReview>[];
  for (final part in parts) {
    switch (part) {
      case Converted():
        if (base != null && base != part.base) {
          throw ArgumentError('Zbir traži istu osnovnu jedinicu');
        }
        if (part.micros > maxConvertedMicros - micros) {
          review.add(const NeedsReview(ConversionReview.outOfRange));
          continue;
        }
        base = part.base;
        micros += part.micros;
        approximate = approximate || part.approximate;
      case NeedsReview():
        review.add(part);
    }
  }
  return ConversionTotal(micros, base, approximate, review);
}
