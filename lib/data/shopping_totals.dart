import '../domain/shopping_demand.dart';
import '../domain/shopping_sync.dart';
import 'database.dart';
import 'shopping_models.dart';

/// Grupiše nedeljne stavke za prikaz zbira celog plana.
List<PlanTotal> shoppingTotalsOf(List<ShoppingItemRow> items) {
  final groups = <(String, String), List<ShoppingItemRow>>{};
  for (final item in items) {
    final unit = normalizeUnit(item.unit, kitchenMeasures: true);
    final group = item.quantity == null ? unknownGroup : unit.group;
    groups.putIfAbsent((ingredientKey(item.name), group), () => []).add(item);
  }

  return [
    for (final MapEntry(key: (ingredient, group), value: rows)
        in groups.entries)
      _totalFor(ingredient, group, rows),
  ];
}

PlanTotal _totalFor(
  String ingredient,
  String group,
  List<ShoppingItemRow> rows,
) {
  final first = rows.first;
  final originalBase = normalizeUnit(first.unit).base;
  final convertKitchenMeasures =
      group == 'volume' &&
      rows.any((row) => normalizeUnit(row.unit).base != originalBase);

  var openMicros = 0;
  var boughtMicros = 0;
  var openApproximate = false;
  var boughtApproximate = false;
  for (final row in rows) {
    final quantity = row.quantity;
    if (quantity == null) continue;
    final unit = normalizeUnit(
      row.unit,
      kitchenMeasures: convertKitchenMeasures,
    );
    final micros = toMicros(quantity) * unit.factor;
    final approximate =
        convertKitchenMeasures &&
        micros > 0 &&
        isApproximateKitchenMeasure(row.unit);
    if (row.isBought) {
      boughtMicros += micros;
      boughtApproximate |= approximate;
    } else {
      openMicros += micros;
      openApproximate |= approximate;
    }
  }

  return PlanTotal(
    ingredient: ingredient,
    unitGroup: group,
    name: first.name,
    category: first.category,
    baseUnit: convertKitchenMeasures ? 'ml' : originalBase,
    openMicros: openMicros,
    boughtMicros: boughtMicros,
    hasUnknown: rows.any((row) => !row.isBought && row.quantity == null),
    itemIds: [for (final row in rows) row.id],
    listIds: {for (final row in rows) row.listId}.toList(),
    openApproximate: openApproximate,
    boughtApproximate: boughtApproximate,
  );
}
