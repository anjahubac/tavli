import '../domain/plan_calendar.dart';
import '../domain/shopping_source.dart';
import 'database.dart';

/// Zbir jedne namirnice u celom planu (mesec): samo za čitanje. Radnje idu
/// na nedeljne stavke iz [itemIds]; mesečna lista se ne čuva.
class PlanTotal {
  const PlanTotal({
    required this.ingredient,
    required this.unitGroup,
    required this.name,
    required this.category,
    required this.baseUnit,
    required this.openMicros,
    required this.boughtMicros,
    required this.hasUnknown,
    required this.itemIds,
    required this.listIds,
  });

  final String ingredient;
  final String unitGroup;
  final String name;
  final String category;
  final String baseUnit;

  /// Preostalo za kupovinu i već kupljeno, u milionitim delovima [baseUnit].
  final int openMicros;
  final int boughtMicros;

  /// Neka otvorena stavka nema poznatu količinu (traži proveru).
  final bool hasUnknown;
  final List<String> itemIds;
  final List<String> listIds;
}

/// Stavka nedeljne liste plana sa početkom te nedelje.
class PlanShoppingItem {
  const PlanShoppingItem({required this.weekStart, required this.item});

  final CivilDate weekStart;
  final ShoppingItemRow item;
}

/// Samostalna priprema recepta u nabavci: zamrznut recept sa sastojcima
/// koje osoba nema (ostale je označila sa "imam") i porcije.
class RecipePreparation {
  const RecipePreparation({
    required this.id,
    required this.snapshot,
    required this.servings,
    this.recipeId,
  });

  final String id;
  final RecipeSnapshot snapshot;
  final int servings;
  final String? recipeId;
}
