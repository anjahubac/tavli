/// Oznake recepta: za koji obrok je pogodan, težina i vrsta jela
/// (specs/019-meal-selection-rules/contracts/recipe-labels-contract.md).
library;

import 'meal_plan.dart' show MealType;

/// Za koji obrok je recept pogodan. `wire` je vrednost na serveru i u AI-ju.
enum MealSuitability {
  breakfast('breakfast', 'Doručak'),
  snack('snack', 'Užina'),
  lunch('lunch', 'Ručak'),
  dinner('dinner', 'Večera');

  const MealSuitability(this.wire, this.label);

  final String wire;
  final String label;

  static MealSuitability? tryParse(Object? v) =>
      _byWire(values, (e) => e.wire, v);
}

enum DishWeight {
  light('light', 'Lagan'),
  medium('medium', 'Srednji'),
  hearty('hearty', 'Jak');

  const DishWeight(this.wire, this.label);

  final String wire;
  final String label;

  static DishWeight? tryParse(Object? v) => _byWire(values, (e) => e.wire, v);
}

enum DishKind {
  soup('soup', 'Čorba ili supa'),
  cooked('cooked', 'Kuvano jelo'),
  bakedFried('baked_fried', 'Pečeno ili prženo'),
  pasta('pasta', 'Testenina'),
  salad('salad', 'Salata'),
  piePizzaSandwich('pie_pizza_sandwich', 'Pita, pica ili sendvič'),
  eggsBreakfast('eggs_breakfast', 'Jaja i doručak'),
  cold('cold', 'Hladno jelo'),
  sweet('sweet', 'Slatko');

  const DishKind(this.wire, this.label);

  final String wire;
  final String label;

  static DishKind? tryParse(Object? v) => _byWire(values, (e) => e.wire, v);
}

/// Ko je postavio oznake. AI nikad ne menja oznake korisnika.
enum LabelsSource { ai, user }

T? _byWire<T>(List<T> values, String Function(T) wire, Object? v) {
  if (v is! String) return null;
  final s = v.trim().toLowerCase();
  for (final e in values) {
    if (wire(e) == s) return e;
  }
  return null;
}

/// Obe užine u planu odgovaraju oznaci [MealSuitability.snack].
MealSuitability suitabilityFor(MealType type) => switch (type) {
  MealType.breakfast => MealSuitability.breakfast,
  MealType.morningSnack || MealType.afternoonSnack => MealSuitability.snack,
  MealType.lunch => MealSuitability.lunch,
  MealType.dinner => MealSuitability.dinner,
};

/// Oznake kako su sačuvane. Čuva se sirova vrednost sa servera, pa
/// vrednost koju ova verzija ne zna ostaje i šalje se nazad nepromenjena;
/// prikazuje se kao nepoznata.
class RecipeLabels {
  const RecipeLabels({this.meals, this.weight, this.dishKind, this.source});

  /// Recept koji još nije označen (stari, ručni ili bez AI oznaka).
  static const none = RecipeLabels();

  /// Oznake koje je izabrao korisnik.
  factory RecipeLabels.byUser({
    required Set<MealSuitability> meals,
    DishWeight? weight,
    DishKind? dishKind,
  }) => RecipeLabels(
    meals: meals.isEmpty
        ? null
        : [
            for (final m in MealSuitability.values)
              if (meals.contains(m)) m.wire,
          ],
    weight: weight?.wire,
    dishKind: dishKind?.wire,
    source: LabelsSource.user.name,
  );

  final List<String>? meals;
  final String? weight;
  final String? dishKind;
  final String? source;

  Set<MealSuitability> get mealSet => {
    for (final m in meals ?? const <String>[]) ?MealSuitability.tryParse(m),
  };
  DishWeight? get weightValue => DishWeight.tryParse(weight);
  DishKind? get dishKindValue => DishKind.tryParse(dishKind);
  LabelsSource? get sourceValue =>
      LabelsSource.values.asNameMap()[source ?? ''];

  bool get isUserSet => sourceValue == LabelsSource.user;

  /// Nijedna oznaka nije poznata ovoj verziji.
  bool get isEmpty =>
      mealSet.isEmpty && weightValue == null && dishKindValue == null;

  @override
  bool operator ==(Object other) =>
      other is RecipeLabels &&
      _sameList(other.meals, meals) &&
      other.weight == weight &&
      other.dishKind == dishKind &&
      other.source == source;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(meals ?? const []), weight, dishKind, source);
}

bool _sameList(List<String>? a, List<String>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
