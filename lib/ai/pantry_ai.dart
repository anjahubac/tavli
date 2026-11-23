import '../domain/recipe.dart' show ingredientCategories;
import 'ai_models.dart';
import 'ai_router.dart';
import 'ai_units.dart';
import 'prompts.dart' show ingredientNameRules;

/// Na slici nema prepoznatljivih namirnica.
class NoFoodOnPhotoException implements Exception {
  const NoFoodOnPhotoException();

  @override
  String toString() => 'Na slici nisu prepoznate namirnice.';
}

/// Jedna namirnica prepoznata na slici; osoba je pregleda pre dodavanja.
class PhotoFoodItem {
  const PhotoFoodItem({
    required this.name,
    this.quantity,
    this.unit,
    this.category = 'ostalo',
  });

  final String name;

  /// Veća od 0, ili `null` kad se sa slike ne vidi koliko.
  final double? quantity;

  /// Kanonska jedinica iz rečnika (`kg`, `kom`…), ili `null`.
  final String? unit;
  final String category;

  PhotoFoodItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    bool clearQuantity = false,
  }) => PhotoFoodItem(
    name: name ?? this.name,
    quantity: clearQuantity ? null : quantity ?? this.quantity,
    unit: clearQuantity ? null : unit ?? this.unit,
    category: category,
  );
}

/// Najviše namirnica koje se prihvata sa jedne slike.
const maxPhotoItems = 60;

final _photoSchema =
    '''
{
  "items": [                 // foods and drinks visible, 1–$maxPhotoItems
    {
      "name": string,            // basic name, e.g. "mleko", without brand or size
      "quantity": number | null, // a number > 0 only for clearly countable pieces; else null
      "unit": string | null,     // e.g. $aiUnitList
      "category": one of $_categories
    }
  ]
}''';

final _categories = ingredientCategories.map((c) => '"$c"').join(', ');

final _photoSystemPrompt =
    '''
You are the pantry assistant inside "Tavli", a recipe and shopping list app.
Always answer with ONE JSON object and nothing else.
All human-readable text must be in Serbian (Latin script).
$ingredientNameRules
Photo JSON schema:
$_photoSchema''';

const _photoPrompt = '''
List the food and drink you can see in this photo (one food, a shelf, an open
fridge or a pantry cupboard), in the photo JSON schema.
- Use the plain food name, without brand or package size ("jogurt", "jaje",
  "paradajz").
- Skip things that are not food or drink, empty containers and anything you
  cannot recognise with reasonable confidence.
- Give quantity only for clearly countable whole pieces you can see (3 eggs
  -> quantity 3, unit "kom"); otherwise quantity and unit are null. Never
  guess weights or volumes.
- The same food seen several times is one item.
If there is no recognisable food or drink, return {"error": "no_food"}.''';

/// Funkcije ostave koje koriste AI preko [AIRouter]-a.
class PantryAI {
  PantryAI(this._router);

  final AIRouter _router;

  Future<AIResult<List<PhotoFoodItem>>> fromPhoto(
    AIImage image, {
    AICancellation? cancel,
  }) => _router.run(
    AIRequest(
      task: AITask.pantryFromPhoto,
      system: _photoSystemPrompt,
      prompt: _photoPrompt,
      images: [image],
      temperature: 0.1,
    ),
    photoItemsFromAiResponse,
    cancel: cancel,
  );
}

/// Proverava odgovor AI-ja: nevažeće stavke se preskaču, a bez ijedne
/// ispravne stavke router traži ispravku (`FormatException`).
List<PhotoFoodItem> photoItemsFromAiResponse(Map<String, dynamic> json) {
  if (json['error'] == 'no_food') throw const NoFoodOnPhotoException();
  final raw = json['items'];
  if (raw is! List<Object?>) {
    throw const FormatException('Namirnice sa slike moraju biti lista.');
  }
  final items = <PhotoFoodItem>[];
  for (final entry in raw.take(maxPhotoItems)) {
    if (entry is! Map<String, dynamic>) continue;
    final name = switch (entry['name']) {
      final String n => n.trim(),
      _ => '',
    };
    if (name.isEmpty || name.length > 120) continue;
    final q = entry['quantity'];
    final quantity = q is num && q.isFinite && q > 0 && q <= 100000
        ? q.toDouble()
        : null;
    // Jedinica bez poznate količine nema smisla; nepoznata jedinica se
    // ne pamti, pa količina ostaje bez nje.
    final unit = quantity == null || entry['unit'] is! String
        ? null
        : canonicalUnit(entry['unit'] as String);
    final category = entry['category'];
    items.add(
      PhotoFoodItem(
        name: name,
        quantity: quantity,
        unit: unit,
        category: category is String && ingredientCategories.contains(category)
            ? category
            : 'ostalo',
      ),
    );
  }
  if (items.isEmpty) {
    throw const FormatException('Na slici nema nijedne ispravne namirnice.');
  }
  return items;
}
