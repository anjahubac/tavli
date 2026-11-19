import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/features/shopping/shopping_providers.dart';
import 'package:tavli/features/shopping/shopping_screen.dart';

void main() {
  test(
    'početni izbor je stabilan, ručni ima prednost; drugi nalog ga resetuje',
    () {
      final container = ProviderContainer(
        overrides: [
          accountScopeProvider.overrideWithValue(
            const AccountScope(userId: 'user-a', householdId: 'home-a'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(shoppingViewProvider.notifier);
      controller.initializeMode(hasPlan: false, hasRecipeItems: true);
      controller.initializeMode(hasPlan: true, hasRecipeItems: true);
      expect(container.read(shoppingViewProvider).mode, ShoppingMode.recipe);
      controller.setMode(ShoppingMode.plan);
      controller.initializeMode(hasPlan: false, hasRecipeItems: true);
      expect(container.read(shoppingViewProvider).mode, ShoppingMode.plan);
      container.updateOverrides([
        accountScopeProvider.overrideWithValue(
          const AccountScope(userId: 'user-b', householdId: 'home-b'),
        ),
      ]);
      expect(container.read(shoppingViewProvider).mode, isNull);
      container
          .read(shoppingViewProvider.notifier)
          .initializeMode(hasPlan: true, hasRecipeItems: false);
      expect(container.read(shoppingViewProvider).mode, ShoppingMode.plan);
    },
  );

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
