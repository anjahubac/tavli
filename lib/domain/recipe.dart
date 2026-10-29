enum RecipeSource { photo, ai, manual }

/// `summary` = naziv i sastojci (dovoljno za plan i listu za kupovinu),
/// `full` = i koraci pripreme.
enum DetailLevel { summary, full }

/// Kategorije redom kojim se obično ide kroz prodavnicu.
const ingredientCategories = [
  'voće i povrće',
  'meso i riba',
  'mlečni proizvodi i jaja',
  'pekara',
  'suvi proizvodi',
  'začini i sosovi',
  'konzerve i tegle',
  'zamrznuto',
  'pića',
  'ostalo',
];

class Ingredient {
  const Ingredient({
    required this.name,
    this.quantity,
    this.unit,
    this.category = 'ostalo',
    this.note,
  });

  final String name;
  final double? quantity;
  final String? unit;
  final String category;
  final String? note;

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) throw const FormatException('Sastojak bez naziva');
    final category = (json['category'] as String?)?.trim().toLowerCase();
    return Ingredient(
      name: name,
      quantity: _parseQuantity(json['quantity']),
      unit: _blankToNull(json['unit']),
      category: ingredientCategories.contains(category) ? category! : 'ostalo',
      note: _blankToNull(json['note']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'category': category,
    'note': note,
  };
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.servings,
    required this.ingredients,
    required this.source,
    required this.createdAt,
    this.steps = const [],
    this.prepMinutes,
    this.imagePath,
    this.answeredBy,
  });

  final String id;
  final String title;
  final int servings;
  final int? prepMinutes;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final RecipeSource source;
  final String? imagePath;

  /// Oznaka modela koji je napravio ili poslednji izmenio recept.
  final String? answeredBy;
  final DateTime createdAt;

  DetailLevel get detailLevel =>
      steps.isEmpty ? DetailLevel.summary : DetailLevel.full;

  /// Pravi recept iz AI odgovora. Baca [FormatException] kad odgovor
  /// ne odgovara šemi, pa router može da pita ponovo.
  factory Recipe.fromAiJson(
    Map<String, dynamic> json, {
    required String id,
    required RecipeSource source,
    required DateTime createdAt,
    String? answeredBy,
    String? imagePath,
  }) {
    final title = (json['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) throw const FormatException('Recept nema naziv');
    final rawIngredients = json['ingredients'];
    if (rawIngredients is! List || rawIngredients.isEmpty) {
      throw const FormatException('Recept nema sastojke');
    }
    final rawSteps = json['steps'];
    return Recipe(
      id: id,
      title: title,
      servings: _parseQuantity(json['servings'])?.round() ?? 2,
      prepMinutes: _parseQuantity(json['prepMinutes'])?.round(),
      ingredients: [
        for (final i in rawIngredients)
          Ingredient.fromJson(i as Map<String, dynamic>),
      ],
      steps: rawSteps is List
          ? [
              for (final s in rawSteps)
                if (s.toString().trim().isNotEmpty) s.toString().trim(),
            ]
          : const [],
      source: source,
      createdAt: createdAt,
      answeredBy: answeredBy,
      imagePath: imagePath,
    );
  }

  /// Oblik koji se šalje AI-ju pri izmenama recepta.
  Map<String, dynamic> toAiJson() => {
    'title': title,
    'servings': servings,
    'prepMinutes': prepMinutes,
    'ingredients': [for (final i in ingredients) i.toJson()],
    'steps': steps,
  };
}

double? _parseQuantity(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.trim().replaceAll(',', '.');
    final fraction = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(s);
    if (fraction != null) {
      final d = int.parse(fraction.group(2)!);
      return d == 0 ? null : int.parse(fraction.group(1)!) / d;
    }
    return double.tryParse(s);
  }
  return null;
}

String? _blankToNull(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}
