import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/cooking_steps.dart';
import 'package:tavli/domain/recipe.dart';

void main() {
  const ingredients = [
    Ingredient(name: 'Crni luk', quantity: 2, unit: 'kom'),
    Ingredient(name: 'Mleveno meso', quantity: 500, unit: 'g'),
    Ingredient(name: 'Krompir', quantity: 1.5, unit: 'kg'),
    Ingredient(name: 'Jaja', quantity: 3, unit: 'kom'),
    Ingredient(name: 'So'),
  ];

  List<String> names(String step) => [
    for (final i in ingredientsInStep(step, ingredients)) i.name,
  ];

  test('nalazi sastojke po nazivu i korenu reči, redom iz recepta', () {
    expect(
      names('Na ulju propržite crni luk, pa dodajte meso i pržite 10 minuta.'),
      ['Crni luk', 'Mleveno meso'],
    );
    expect(names('Ređajte krompire u pleh.'), ['Krompir']);
  });

  test('bez obzira na velika slova i kvačice', () {
    expect(names('JAJA umutiti.'), ['Jaja']);
  });

  test('kratke reči se ne traže po korenu', () {
    // „So“ ima samo dva slova: nalazi se samo kao cela reč.
    expect(names('Posolite po ukusu.'), isEmpty);
    expect(names('Dodajte so.'), ['So']);
  });

  test('korak bez sastojaka daje praznu listu', () {
    expect(names('Ostavite 10 minuta da odstoji.'), isEmpty);
  });
}
