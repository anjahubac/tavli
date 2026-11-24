import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/ingredient_links.dart';
import 'package:tavli/domain/recipe.dart';

Ingredient ingredient(String name, String id, LinkSource source) => Ingredient(
  name: name,
  link: IngredientLink(foodId: id, matchedKey: 'jaja', linkSource: source),
);

void main() {
  const matched = 'matched-food';
  const confirmed = 'confirmed-food';

  test('server confirmed link replaces local matched link', () {
    final merged = mergeIngredientLinks(
      local: [ingredient('Jaja', matched, LinkSource.matched)],
      server: [ingredient('jaja', confirmed, LinkSource.confirmed)],
    );

    expect(merged.single.name, 'Jaja');
    expect(merged.single.link?.foodId, confirmed);
    expect(merged.single.link?.linkSource, LinkSource.confirmed);
  });

  test('local confirmed link stays over a different server link', () {
    final merged = mergeIngredientLinks(
      local: [ingredient('Jaja', confirmed, LinkSource.confirmed)],
      server: [ingredient('jaja', matched, LinkSource.matched)],
    );
    expect(merged.single.link?.foodId, confirmed);
  });

  test('explicit unlink suppresses server link', () {
    final merged = mergeIngredientLinks(
      local: [const Ingredient(name: 'Jaja').unlink()],
      server: [ingredient('jaja', confirmed, LinkSource.confirmed)],
    );
    expect(merged.single.link, isNull);
    expect(merged.single.unlinkedKey, 'jaja');
  });

  test('renamed ingredient does not inherit a stale server link', () {
    final merged = mergeIngredientLinks(
      local: [const Ingredient(name: 'Belance')],
      server: [ingredient('Jaja', confirmed, LinkSource.confirmed)],
    );
    expect(merged.single.name, 'Belance');
    expect(merged.single.link, isNull);
  });

  test('ambiguous duplicate server links are not carried', () {
    final merged = mergeIngredientLinks(
      local: const [Ingredient(name: 'jaja')],
      server: [
        ingredient('Jaja', confirmed, LinkSource.confirmed),
        ingredient('jaja', matched, LinkSource.matched),
      ],
    );
    expect(merged.single.link, isNull);
  });

  test('ingredient unlink intent survives recipe edit carry-forward', () {
    final carried = carryIngredientLinks(
      from: [const Ingredient(name: 'Jaja').unlink()],
      to: const [Ingredient(name: 'jaja')],
    );

    expect(carried.single.unlinkedKey, 'jaja');
    expect(
      mergeIngredientLinks(
        local: carried,
        server: [ingredient('Jaja', confirmed, LinkSource.confirmed)],
      ).single.link,
      isNull,
    );
  });
}
