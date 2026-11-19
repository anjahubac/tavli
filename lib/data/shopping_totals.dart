import '../domain/shopping_demand.dart';
import '../domain/shopping_sync.dart';
import 'database.dart';
import 'shopping_models.dart';

/// Grupiše nedeljne stavke za prikaz zbira celog plana.
List<PlanTotal> shoppingTotalsOf(List<ShoppingItemRow> items) {
  final groups = <(String, String), List<ShoppingItemRow>>{};
  for (final item in items) {
    final unit = normalizeUnit(item.unit);
    final group = item.quantity == null ? unknownGroup : unit.group;
    groups.putIfAbsent((ingredientKey(item.name), group), () => []).add(item);
  }

  int micros(ShoppingItemRow item) => item.quantity == null
      ? 0
      : toMicros(item.quantity!) * normalizeUnit(item.unit).factor;

  return [
    for (final MapEntry(key: (ingredient, group), value: rows)
        in groups.entries)
      PlanTotal(
        ingredient: ingredient,
        unitGroup: group,
        name: rows.first.name,
        category: rows.first.category,
        baseUnit: normalizeUnit(rows.first.unit).base,
        openMicros: rows
            .where((row) => !row.isBought)
            .fold(0, (sum, row) => sum + micros(row)),
        boughtMicros: rows
            .where((row) => row.isBought)
            .fold(0, (sum, row) => sum + micros(row)),
        hasUnknown: rows.any((row) => !row.isBought && row.quantity == null),
        itemIds: [for (final row in rows) row.id],
        listIds: {for (final row in rows) row.listId}.toList(),
      ),
  ];
}
