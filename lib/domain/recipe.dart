import 'recipe_labels.dart';

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

/// Ko je postavio vezu sastojka sa namirnicom (ugovor #30).
enum LinkSource { matched, confirmed }

/// Veza sastojka sa namirnicom kataloga (ugovor #30). Važi dok je
/// `ingredientKey(name)` jednak [matchedKey] i namirnica nije povučena; to
/// proverava potrošač. Ovaj build vezu samo čuva, ništa je još ne upisuje.
final class IngredientLink {
  const IngredientLink({
    required this.foodId,
    required this.matchedKey,
    required this.linkSource,
  });

  final String foodId;
  final String matchedKey;
  final LinkSource linkSource;

  /// Blago čitanje sačuvanog sastojka: nepotpuna ili neispravna veza je
  /// `null`, a sastojak ostaje čitljiv.
  static IngredientLink? fromJson(Map<String, dynamic> json) {
    final foodId = json['foodId'];
    final matchedKey = json['matchedKey'];
    final source = LinkSource.values.asNameMap()[json['linkSource']];
    if (foodId is! String || foodId.trim().isEmpty) return null;
    if (matchedKey is! String || matchedKey.trim().isEmpty) return null;
    if (source == null) return null;
    return IngredientLink(
      foodId: foodId,
      matchedKey: matchedKey,
      linkSource: source,
    );
  }

  Map<String, Object?> toJson() => {
    'foodId': foodId,
    'matchedKey': matchedKey,
    'linkSource': linkSource.name,
  };

  @override
  bool operator ==(Object other) =>
      other is IngredientLink &&
      other.foodId == foodId &&
      other.matchedKey == matchedKey &&
      other.linkSource == linkSource;

  @override
  int get hashCode => Object.hash(foodId, matchedKey, linkSource);
}

class Ingredient {
  const Ingredient({
    required this.name,
    this.quantity,
    this.unit,
    this.category = 'ostalo',
    this.note,
    this.link,
  });

  final String name;
  final double? quantity;
  final String? unit;
  final String category;
  final String? note;

  /// Veza sa katalogom; `null` = nepovezan sastojak (važeće stanje).
  final IngredientLink? link;

  /// Izmena koja zadržava vezu. Ako se promeni naziv, veza prestaje da važi
  /// sama ([IngredientLink.matchedKey] se više ne poklapa).
  Ingredient copyWith({
    String? name,
    double? quantity,
    String? unit,
    String? category,
    String? note,
  }) => Ingredient(
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    category: category ?? this.category,
    note: note ?? this.note,
    link: link,
  );

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
      link: IngredientLink.fromJson(json),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'category': category,
    'note': note,
    ...?link?.toJson(),
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
    this.labels = RecipeLabels.none,
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

  /// Obrok, težina i vrsta jela. Nisu deo istorije verzija.
  final RecipeLabels labels;

  DetailLevel get detailLevel =>
      steps.isEmpty ? DetailLevel.summary : DetailLevel.full;

  /// Blago čita recept u obliku [toAiJson]: sačuvane verzije ([Recipe.fromJson])
  /// i stare zapise (prihvata "0,5" i "1/2", porcije podrazumevano 2).
  /// Baca [FormatException] samo bez naziva ili sastojaka. Novi AI
  /// odgovori idu kroz strogu proveru (`lib/ai/ai_response_validator.dart`).
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

  Recipe copyWith({
    String? title,
    int? servings,
    int? prepMinutes,
    bool clearPrepMinutes = false,
    List<Ingredient>? ingredients,
    List<String>? steps,
    String? imagePath,
    String? answeredBy,
    RecipeLabels? labels,
  }) => Recipe(
    id: id,
    title: title ?? this.title,
    servings: servings ?? this.servings,
    prepMinutes: clearPrepMinutes ? null : (prepMinutes ?? this.prepMinutes),
    ingredients: ingredients ?? this.ingredients,
    steps: steps ?? this.steps,
    source: source,
    imagePath: imagePath ?? this.imagePath,
    answeredBy: answeredBy ?? this.answeredBy,
    createdAt: createdAt,
    labels: labels ?? this.labels,
  );

  /// Ceo recept za čuvanje (npr. prethodne verzije u bazi).
  Map<String, dynamic> toJson() => {
    'id': id,
    ...toAiJson(),
    'source': source.name,
    'imagePath': imagePath,
    'answeredBy': answeredBy,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  /// Čita oblik iz [toJson]. Baca [FormatException] na pokvaren zapis.
  factory Recipe.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final source = RecipeSource.values.asNameMap()[json['source']];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (id is! String || source == null || createdAt == null) {
      throw const FormatException('Pokvaren zapis recepta');
    }
    return Recipe.fromAiJson(
      json,
      id: id,
      source: source,
      createdAt: createdAt,
      answeredBy: json['answeredBy'] as String?,
      imagePath: json['imagePath'] as String?,
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
