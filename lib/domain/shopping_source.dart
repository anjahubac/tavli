import 'recipe.dart';
import 'shopping_demand.dart';

/// Odakle dolazi potražnja u kupovini.
enum ShoppingSourceKind {
  /// Planirani obrok: recept i porcije čita iz unosa plana.
  planEntry,

  /// Samostalna priprema recepta bez plana: ima svoj zamrznut recept.
  recipePreparation,
}

/// Recept kakav je odobren za obrok ili pripremu. Izmena recepta u
/// biblioteci ga ne menja; sažetak može biti bez koraka.
class RecipeSnapshot {
  const RecipeSnapshot({
    required this.title,
    required this.baseServings,
    required this.ingredients,
    this.steps = const [],
    this.prepMinutes,
    this.imagePath,
  });

  factory RecipeSnapshot.fromRecipe(Recipe r) => RecipeSnapshot(
    title: r.title,
    baseServings: r.servings,
    ingredients: r.ingredients,
    steps: r.steps,
    prepMinutes: r.prepMinutes,
    imagePath: r.imagePath,
  );

  /// Čita oblik iz [toJson]. Baca [FormatException] na pokvaren zapis.
  factory RecipeSnapshot.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) throw const FormatException('Obrok nema naziv');
    final servings = json['servings'];
    if (servings is! int || servings < minServings) {
      throw const FormatException('Obrok nema porcije');
    }
    final ingredients = json['ingredients'] ?? const <Object?>[];
    final steps = json['steps'] ?? const <Object?>[];
    if (ingredients is! List || steps is! List) {
      throw const FormatException('Pokvaren zapis obroka');
    }
    return RecipeSnapshot(
      title: title,
      baseServings: servings,
      ingredients: [
        for (final i in ingredients)
          Ingredient.fromJson(i as Map<String, dynamic>),
      ],
      steps: [for (final s in steps) s.toString()],
      prepMinutes: json['prepMinutes'] as int?,
      imagePath: json['imagePath'] as String?,
    );
  }

  final String title;
  final int baseServings;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final int? prepMinutes;
  final String? imagePath;

  /// Isti ključevi kao recept u bazi (`Recipe.toAiJson`) i kao zapis koji
  /// migracija v5 pravi od postojećih obroka.
  Map<String, dynamic> toJson() => {
    'title': title,
    'servings': baseServings,
    'prepMinutes': prepMinutes,
    'ingredients': [for (final i in ingredients) i.toJson()],
    'steps': steps,
    'imagePath': imagePath,
  };
}

/// Redosled vrsta obroka u danu (za raspodelu zalihe).
int mealOrder(String mealType) => switch (mealType) {
  'breakfast' => 0,
  'lunch' => 1,
  'dinner' => 2,
  _ => 3,
};
