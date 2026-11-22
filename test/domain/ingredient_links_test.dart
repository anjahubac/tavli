import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/ingredient_links.dart';
import 'package:tavli/domain/recipe.dart';

void main() {
  const eggs = IngredientLink(
    foodId: '00000000-0000-4000-8000-000000000001',
    matchedKey: 'jaja',
    linkSource: LinkSource.confirmed,
  );
  const milk = IngredientLink(
    foodId: '00000000-0000-4000-8000-000000000002',
    matchedKey: 'mleko',
    linkSource: LinkSource.matched,
  );

  test('veza prelazi na sastojak istog naziva', () {
    final out = carryIngredientLinks(
      from: const [Ingredient(name: 'jaja', quantity: 3, link: eggs)],
      to: const [
        Ingredient(name: ' Jaja ', quantity: 4),
        Ingredient(name: 'so'),
      ],
    );
    expect(out[0].link, eggs);
    expect(out[0].quantity, 4);
    expect(out[1].link, isNull);
  });

  test('preimenovan sastojak i nevažeća stara veza ne dobijaju vezu', () {
    final out = carryIngredientLinks(
      from: const [
        Ingredient(name: 'jaja', link: eggs),
        // Naziv je već promenjen pa veza više ne važi.
        Ingredient(name: 'pirinač', link: milk),
      ],
      to: const [
        Ingredient(name: 'jaja od patke'),
        Ingredient(name: 'pirinač'),
      ],
    );
    expect(out[0].link, isNull);
    expect(out[1].link, isNull);
  });

  test('dva različita izvora za isti naziv: bez veze', () {
    const otherEggs = IngredientLink(
      foodId: '00000000-0000-4000-8000-000000000003',
      matchedKey: 'jaja',
      linkSource: LinkSource.confirmed,
    );
    final out = carryIngredientLinks(
      from: const [
        Ingredient(name: 'jaja', link: eggs),
        Ingredient(name: 'jaja', link: otherEggs),
      ],
      to: const [Ingredient(name: 'jaja')],
    );
    expect(out.single.link, isNull);
  });
}
