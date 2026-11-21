import '../domain/recipe.dart';
import '../domain/recipe_labels.dart';

/// Stroga provera AI odgovora po ugovoru `recipe.v1` i
/// `recipe-summary.v1` (specs/014-ai-response-contracts/contracts/).
///
/// Važi samo na granici sa AI-jem. Sačuvani recepti, snimci u nabavci i
/// ručni unos i dalje idu kroz blage čitače ([Recipe.fromAiJson],
/// [Ingredient.fromJson]) da stari zapisi ostanu čitljivi.
///
/// Svako odbijanje je [FormatException] sa oznakom pravila (npr. `R2`),
/// bez sadržaja odgovora; router tada pita ponovo ili sledeći model.

const maxTitleLength = 120;
const maxRecipeServings = 99;
const maxIngredients = 60;
const maxIngredientNameLength = 80;
const maxUnitLength = 30;
const maxNoteLength = 200;
const maxSteps = 40;
const maxStepLength = 1000;

/// R6: najmanja i najveća količina. Nabavka računa u milionitim delovima
/// (`toMicros`), pa manja vrednost postaje 0, a besmisleno velika kvari zbir.
const minQuantity = 0.001;
const maxQuantity = 100000;

/// R3: duže od 30 dana nije vreme pripreme (kiseli kupus staje u granicu).
const maxPrepMinutes = 30 * 24 * 60;

Never _reject(String rule) => throw FormatException(rule);

/// C3: tekst bez razmaka sa krajeva; prazan postaje `null`.
/// Pogrešan tip ili predugačak tekst se odbija.
String? _optionalText(Object? v, int maxLength, String rule) {
  if (v == null) return null;
  if (v is! String) _reject(rule);
  final s = v.trim();
  if (s.isEmpty) return null;
  if (s.length > maxLength) _reject(rule);
  return s;
}

String _requiredText(Object? v, int maxLength, String rule) =>
    _optionalText(v, maxLength, rule) ?? _reject(rule);

/// C4: ceo broj je JSON broj bez decimala (`4` i `4.0`, ne `4.5` ni `"4"`).
int? _integer(Object? v) =>
    v is num && v.isFinite && v == v.roundToDouble() ? v.toInt() : null;

/// R1 / P5: naziv recepta ili jela, 1–120 znakova.
String aiTitle(Object? v) => _requiredText(v, maxTitleLength, 'R1');

/// R2 (1–99) i S2 (1–20): porcije su ceo broj u granicama, obavezne.
int aiServings(Object? v, {required int max, String rule = 'R2'}) {
  final n = _integer(v);
  if (n == null || n < 1 || n > max) _reject(rule);
  return n;
}

/// R3: broj veći od nule i najviše [maxPrepMinutes], zaokružen; sve ostalo
/// postaje `null`.
int? aiPrepMinutes(Object? v) {
  if (v is! num || !v.isFinite || v <= 0 || v > maxPrepMinutes) return null;
  final n = v.round();
  return n > 0 ? n : null;
}

/// R4–R9: lista od 1–60 sastojaka.
List<Ingredient> aiIngredients(Object? v) {
  if (v is! List || v.isEmpty || v.length > maxIngredients) _reject('R4');
  return [for (final i in v) aiIngredient(i)];
}

/// R5–R9: jedan sastojak.
Ingredient aiIngredient(Object? v) {
  if (v is! Map<String, dynamic>) _reject('R4');
  final name = _requiredText(v['name'], maxIngredientNameLength, 'R5');
  final quantity = v['quantity'];
  if (quantity != null &&
      (quantity is! num ||
          !quantity.isFinite ||
          quantity < minQuantity ||
          quantity > maxQuantity)) {
    _reject('R6');
  }
  final category = v['category'];
  final normalized = category is String ? category.trim().toLowerCase() : null;
  final (base, note) = _moveParenthesisToNote(
    name,
    _optionalText(v['note'], maxNoteLength, 'R9'),
  );
  return Ingredient(
    name: base,
    quantity: (quantity as num?)?.toDouble(),
    unit: _optionalText(v['unit'], maxUnitLength, 'R7'),
    category: ingredientCategories.contains(normalized)
        ? normalized!
        : 'ostalo',
    note: note,
  );
}

final _trailingParenthesis = RegExp(r'^(.+?)\s*\(([^()]+)\)$');

/// „paradajz (oljušten)“ → naziv „paradajz“, napomena „oljušten“, da bi se
/// sastojak povezao sa katalogom (TRELLO-40). Ništa pametnije od zagrade:
/// „kiselo mleko“ je namirnica, ne „mleko“ uz pripremu. Ako napomena ne bi
/// stala u [maxNoteLength], naziv ostaje kakav je.
(String, String?) _moveParenthesisToNote(String name, String? note) {
  final m = _trailingParenthesis.firstMatch(name);
  if (m == null) return (name, note);
  final inside = m.group(2)!.trim();
  final joined = note == null ? inside : '$inside, $note';
  if (inside.isEmpty || joined.length > maxNoteLength) return (name, note);
  return (m.group(1)!.trim(), joined);
}

/// R10: koraci bez praznih; nedostaju → prazna lista (sažetak).
List<String> aiSteps(Object? v) {
  if (v == null) return const [];
  if (v is! List) _reject('R10');
  final steps = <String>[];
  for (final s in v) {
    final step = _optionalText(s, maxStepLength, 'R10');
    if (step != null) steps.add(step);
  }
  if (steps.length > maxSteps) _reject('R10');
  return steps;
}

/// L1–L3: oznake su blage i nikad ne odbijaju recept. Nepoznata vrednost
/// postaje prazna; izvor je `ai` samo ako je bar jedna oznaka poznata.
RecipeLabels aiLabels(Map<String, dynamic> json) {
  final rawMeals = json['meals'];
  final meals = <MealSuitability>{
    if (rawMeals is List)
      for (final m in rawMeals) ?MealSuitability.tryParse(m),
  };
  final weight = DishWeight.tryParse(json['weight']);
  final dishKind = DishKind.tryParse(json['dishKind']);
  if (meals.isEmpty && weight == null && dishKind == null) {
    return RecipeLabels.none;
  }
  return RecipeLabels(
    meals: meals.isEmpty
        ? null
        : [
            for (final m in MealSuitability.values)
              if (meals.contains(m)) m.wire,
          ],
    weight: weight?.wire,
    dishKind: dishKind?.wire,
    source: LabelsSource.ai.name,
  );
}

/// Ceo recept iz AI odgovora (`recipe.v1`, R1–R10, L1–L3). Odgovor
/// `{"error": "not_a_recipe"}` (R11) obrađuje pozivalac pre ovoga.
Recipe recipeFromAiResponse(
  Map<String, dynamic> json, {
  required String id,
  required RecipeSource source,
  required DateTime createdAt,
  String? imagePath,
}) => Recipe(
  id: id,
  title: aiTitle(json['title']),
  servings: aiServings(json['servings'], max: maxRecipeServings),
  prepMinutes: aiPrepMinutes(json['prepMinutes']),
  ingredients: aiIngredients(json['ingredients']),
  steps: aiSteps(json['steps']),
  source: source,
  createdAt: createdAt,
  imagePath: imagePath,
  labels: aiLabels(json),
);
