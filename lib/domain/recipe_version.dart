import 'recipe.dart';

/// Kakva izmena je zamenila sačuvanu verziju.
enum ChangeKind {
  ai('AI izmena'),
  manual('Ručna izmena'),
  restore('Vraćena verzija');

  const ChangeKind(this.label);

  final String label;
}

/// Stanje recepta pre jedne izmene, za poništavanje i vraćanje.
class RecipeVersion {
  const RecipeVersion({
    required this.id,
    required this.recipeId,
    required this.recipe,
    required this.kind,
    required this.createdAt,
    this.instruction,
    this.changedBy,
  });

  final String id;
  final String recipeId;

  /// Recept kakav je bio pre izmene.
  final Recipe recipe;
  final ChangeKind kind;

  /// Zahtev poslat AI-ju (samo za [ChangeKind.ai]).
  final String? instruction;

  /// Model koji je napravio izmenu (samo za [ChangeKind.ai]).
  final String? changedBy;

  /// Kada je izmena napravljena.
  final DateTime createdAt;
}
