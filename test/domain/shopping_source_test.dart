import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/shopping_source.dart';

void main() {
  test('poreklo kupovine: obrok i priprema u oba smera', () {
    final sources = [
      ItemSource(
        title: 'Sarma',
        kind: ShoppingSourceKind.planEntry,
        servings: 4,
        date: CivilDate(2026, 11, 2),
        mealType: 'lunch',
      ),
      const ItemSource(
        title: 'Musaka',
        kind: ShoppingSourceKind.recipePreparation,
        servings: 2,
      ),
    ];
    final back = provenanceSources(provenanceJson(sources));
    expect(back.map((s) => s.title), ['Sarma', 'Musaka']);
    expect(back.first.date, CivilDate(2026, 11, 2));
    expect(back.first.mealType, 'lunch');
    expect(back.first.kind, ShoppingSourceKind.planEntry);
    expect(back.last.kind, ShoppingSourceKind.recipePreparation);
    expect(back.last.date, isNull);
  });

  test('raniji zapis (samo nazivi) i pokvaren zapis', () {
    expect(provenanceSources('{"sources":["Sarma"]}').single.title, 'Sarma');
    expect(provenanceSources(null), isEmpty);
    expect(provenanceSources('nije json'), isEmpty);
    expect(provenanceSources('{"sources":[42]}'), isEmpty);
  });

  test('zamrznut recept pripreme čuva samo sastojke koji fale', () {
    const recipe = RecipeSnapshot(
      title: 'Sarma',
      baseServings: 4,
      ingredients: [
        Ingredient(name: 'Kupus', quantity: 1, unit: 'kg'),
        Ingredient(name: 'Luk', quantity: 2, unit: 'kom'),
      ],
    );
    final missing = recipe.withIngredients([recipe.ingredients.first]);
    expect(missing.title, 'Sarma');
    expect(missing.baseServings, 4);
    expect(missing.ingredients.single.name, 'Kupus');
    final json = RecipeSnapshot.fromJson(missing.toJson());
    expect(json.ingredients.single.name, 'Kupus');
  });
}
