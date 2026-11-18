import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/features/shopping/shopping_providers.dart';
import 'package:tavli/features/shopping/shopping_screen.dart';

void main() {
  group('effectiveMode', () {
    test('bez izbora: po receptu samo kad nema plana a ima stavki', () {
      const view = ShoppingView();
      expect(
        view.effectiveMode(hasPlan: false, hasRecipeItems: true),
        ShoppingMode.recipe,
      );
      expect(
        view.effectiveMode(hasPlan: true, hasRecipeItems: true),
        ShoppingMode.plan,
      );
      expect(
        view.effectiveMode(hasPlan: false, hasRecipeItems: false),
        ShoppingMode.plan,
      );
    });

    test('izbor korisnika uvek važi', () {
      const view = ShoppingView(mode: ShoppingMode.plan);
      expect(
        view.effectiveMode(hasPlan: false, hasRecipeItems: true),
        ShoppingMode.plan,
      );
    });
  });

  test('itemsCount: padeži za stavke', () {
    expect(itemsCount(1), '1 stavka');
    expect(itemsCount(2), '2 stavke');
    expect(itemsCount(5), '5 stavki');
    expect(itemsCount(11), '11 stavki');
    expect(itemsCount(12), '12 stavki');
    expect(itemsCount(21), '21 stavka');
    expect(itemsCount(23), '23 stavke');
  });
}
