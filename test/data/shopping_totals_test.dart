import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/shopping_totals.dart';
import 'package:tavli/domain/shopping_demand.dart';

ShoppingItemRow item(
  String id,
  double? quantity,
  String unit, {
  bool bought = false,
}) => ShoppingItemRow(
  id: id,
  listId: 'week',
  name: 'ulje',
  quantity: quantity,
  unit: unit,
  category: 'ostalo',
  isBought: bought,
  isManual: false,
  fromRecipeIdsJson: '[]',
);

void main() {
  test('jedna šolja ostaje u originalnoj meri', () {
    final total = shoppingTotalsOf([item('a', 1, 'šolja')]).single;

    expect(total.baseUnit, 'šolja');
    expect(total.openMicros, toMicros(1));
    expect(total.openApproximate, isFalse);
  });

  test('iste kuhinjske mere se sabiraju u originalnoj jedinici', () {
    final total = shoppingTotalsOf([
      item('a', 2, 'kašike'),
      item('b', 1, 'kašika'),
    ]).single;

    expect(total.baseUnit, 'kašika');
    expect(total.openMicros, toMicros(3));
    expect(total.openApproximate, isFalse);
  });

  test('različite kuhinjske mere daju približan zbir u ml', () {
    final total = shoppingTotalsOf([
      item('a', 2, 'kašike'),
      item('b', 1, 'kašičica'),
    ]).single;

    expect(total.baseUnit, 'ml');
    expect(total.openMicros, toMicros(35));
    expect(total.openApproximate, isTrue);
  });

  test('oznaka približne količine važi samo za pretvoreni zbir', () {
    final total = shoppingTotalsOf([
      item('a', 100, 'ml'),
      item('b', 2, 'kašike', bought: true),
    ]).single;

    expect(total.baseUnit, 'ml');
    expect(total.openMicros, toMicros(100));
    expect(total.openApproximate, isFalse);
    expect(total.boughtMicros, toMicros(30));
    expect(total.boughtApproximate, isTrue);
  });

  test('nepoznata kuhinjska količina ostaje vidljiva za proveru', () {
    final total = shoppingTotalsOf([item('a', null, 'šolja')]).single;

    expect(total.hasUnknown, isTrue);
    expect(total.openMicros, 0);
    expect(total.openApproximate, isFalse);
  });
}
