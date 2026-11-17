import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/shopping_demand.dart';

DemandSource source(
  String id,
  List<Ingredient> ingredients, {
  int baseServings = 2,
  int servings = 2,
  bool kitchenMeasures = false,
}) => DemandSource(
  id: id,
  baseServings: baseServings,
  servings: servings,
  ingredients: ingredients,
  kitchenMeasures: kitchenMeasures,
);

void main() {
  group('fiksna preciznost', () {
    test('šest decimala, bez grešaka zaokruživanja', () {
      expect(toMicros(0.1) + toMicros(0.2), toMicros(0.3));
      expect(toMicros(1.0000004), 1000000);
      expect(fromMicros(1500000), 1.5);
    });

    test('odbija negativne i nekonačne vrednosti', () {
      expect(() => toMicros(-1), throwsArgumentError);
      expect(() => toMicros(double.nan), throwsArgumentError);
      expect(() => toMicros(double.infinity), throwsArgumentError);
    });
  });

  group('jedinice', () {
    test('g/kg, ml/l i kom su uporedive grupe', () {
      expect(normalizeUnit('kg'), (group: 'mass', base: 'g', factor: 1000));
      expect(normalizeUnit(' G '), (group: 'mass', base: 'g', factor: 1));
      expect(normalizeUnit('l'), (group: 'volume', base: 'ml', factor: 1000));
      expect(normalizeUnit('ml'), (group: 'volume', base: 'ml', factor: 1));
      expect(normalizeUnit('kom'), (
        group: 'count:kom',
        base: 'kom',
        factor: 1,
      ));
    });

    test('ostale jedinice su uporedive samo kad su iste', () {
      expect(normalizeUnit('Kašika'), (
        group: 'unit:kašika',
        base: 'kašika',
        factor: 1,
      ));
      expect(normalizeUnit('kašika'), normalizeUnit('KAŠIKA'));
      expect(normalizeUnit('kašika') == normalizeUnit('kasika'), isFalse);
      expect(normalizeUnit(null), (group: 'unit:', base: '', factor: 1));
    });
  });

  group('kuhinjske mere — opciono računanje', () {
    test('dve kašike i kašičica su približno 35 ml', () {
      final lines = demandFor(
        source('e1', kitchenMeasures: true, [
          const Ingredient(name: 'ulje', quantity: 2, unit: 'kašika'),
          const Ingredient(name: 'ulje', quantity: 1, unit: 'kašičica'),
        ]),
      );
      expect(lines, hasLength(1));
      expect(lines.single.micros, toMicros(35));
      expect(lines.single.baseUnit, 'ml');
      expect(lines.single.approximate, isTrue);
      expect(summarize(lines).single.approximate, isTrue);
    });

    test('podrazumevane mere i oblici naziva', () {
      for (final (unit, expected) in [
        ('čaša', 200),
        ('casa', 200),
        ('šolja', 250),
        ('solje', 250),
        ('kašike', 15),
        ('kasika', 15),
        ('kašičice', 5),
        ('kasicica', 5),
      ]) {
        final lines = demandFor(
          source('e1', kitchenMeasures: true, [
            Ingredient(name: 'mleko', quantity: 1, unit: unit),
          ]),
        );
        expect(
          lines.single.micros,
          toMicros(expected.toDouble()),
          reason: unit,
        );
        expect(lines.single.approximate, isTrue, reason: unit);
      }
    });

    test('podrazumevano ponašanje i nepoznata gustina ostaju bezbedni', () {
      const ingredients = [
        Ingredient(name: 'brašno', quantity: 1, unit: 'šolja'),
        Ingredient(name: 'brašno', quantity: 100, unit: 'g'),
        Ingredient(name: 'so', unit: 'kašika'),
      ];
      final legacy = demandFor(source('e1', ingredients));
      expect(legacy.first.baseUnit, 'šolja');
      expect(legacy.first.approximate, isFalse);
      final proposed = demandFor(
        source('e1', kitchenMeasures: true, ingredients),
      );
      expect(proposed, hasLength(3));
      expect(proposed[0].micros, toMicros(250));
      expect(proposed[0].baseUnit, 'ml');
      expect(proposed[1].micros, toMicros(100));
      expect(proposed[1].baseUnit, 'g');
      expect(proposed[2].micros, isNull);
      expect(proposed[2].needsReview, isTrue);
    });

    test('prstohvat ostaje zasebna mera i traži proveru', () {
      const ingredients = [
        Ingredient(name: 'so', quantity: 1, unit: 'prstohvat'),
        Ingredient(name: 'so', quantity: 5, unit: 'g'),
      ];
      final legacy = demandFor(source('e1', ingredients));
      expect(legacy.first.needsReview, isFalse);

      final lines = demandFor(source('e1', kitchenMeasures: true, ingredients));
      expect(lines, hasLength(2));
      expect(lines.first.baseUnit, 'prstohvat');
      expect(lines.first.micros, toMicros(1));
      expect(lines.first.needsReview, isTrue);
      expect(lines.last.needsReview, isFalse);
      expect(summarize(lines).first.needsReview, isTrue);
    });

    test('zbir više izvora čuva oznaku približne mere', () {
      final needs = summarize([
        ...demandFor(
          source('prvi', kitchenMeasures: true, [
            const Ingredient(name: 'mleko', quantity: 1, unit: 'l'),
          ]),
        ),
        ...demandFor(
          source('drugi', kitchenMeasures: true, [
            const Ingredient(name: 'mleko', quantity: 1, unit: 'šolja'),
          ]),
        ),
      ]);
      expect(needs.single.micros, toMicros(1250));
      expect(needs.single.baseUnit, 'ml');
      expect(needs.single.approximate, isTrue);
      expect(needs.single.sourceIds, ['prvi', 'drugi']);
      expect(
        summarize(
          demandFor(
            source('treći', kitchenMeasures: true, [
              const Ingredient(name: 'mleko', quantity: 1, unit: 'l'),
            ]),
          ),
        ).single.approximate,
        isFalse,
      );
    });
  });

  group('skaliranje porcija', () {
    test('količina prati porcije unosa u odnosu na osnovne', () {
      expect(scaleQuantity(300, baseServings: 2, servings: 4), 600);
      expect(
        scaleQuantity(1, baseServings: 3, servings: 1),
        closeTo(1 / 3, 1e-9),
      );
      expect(scaleQuantity(null, baseServings: 2, servings: 4), isNull);
    });

    test('porcije van 1–20 nisu dozvoljene', () {
      expect(
        () => scaleQuantity(1, baseServings: 0, servings: 2),
        throwsArgumentError,
      );
      expect(
        () => scaleQuantity(1, baseServings: 2, servings: 21),
        throwsArgumentError,
      );
    });
  });

  group('potražnja jednog izvora', () {
    test('skalira i spaja uporedive redove istog sastojka', () {
      final lines = demandFor(
        source('e1', servings: 4, [
          const Ingredient(name: 'Brašno', quantity: 0.5, unit: 'kg'),
          const Ingredient(name: ' brašno ', quantity: 100, unit: 'g'),
          const Ingredient(name: 'Mleko', quantity: 1, unit: 'l'),
        ]),
      );
      expect(lines, hasLength(2));
      final flour = lines.firstWhere((l) => l.key.ingredient == 'brašno');
      expect(flour.micros, toMicros(1200));
      expect(flour.baseUnit, 'g');
      expect(flour.key.sourceId, 'e1');
      final milk = lines.firstWhere((l) => l.key.ingredient == 'mleko');
      expect(milk.micros, toMicros(2000));
      expect(milk.baseUnit, 'ml');
    });

    test('neuporedive jedinice ostaju odvojene', () {
      final lines = demandFor(
        source('e1', [
          const Ingredient(name: 'jaja', quantity: 2, unit: 'kom'),
          const Ingredient(name: 'jaja', quantity: 100, unit: 'g'),
        ]),
      );
      expect(lines.map((l) => l.key.unitGroup), ['count:kom', 'mass']);
    });

    test('nepoznata količina ostaje za proveru i ne izmišlja se', () {
      final lines = demandFor(
        source('e1', [
          const Ingredient(name: 'so', note: 'po ukusu'),
          const Ingredient(name: 'biber', quantity: double.nan, unit: 'g'),
          const Ingredient(name: 'so', quantity: 5, unit: 'g'),
        ]),
      );
      final salt = lines.where((l) => l.key.ingredient == 'so').toList();
      expect(salt, hasLength(2));
      expect(salt.firstWhere((l) => l.isUnknown).key.unitGroup, unknownGroup);
      expect(salt.firstWhere((l) => !l.isUnknown).micros, toMicros(5));
      final pepper = lines.singleWhere((l) => l.key.ingredient == 'biber');
      expect(pepper.isUnknown, isTrue);
      expect(pepper.needsReview, isTrue);
    });

    test('naziv se ne spaja po sinonimima ni bez kvačica', () {
      final lines = demandFor(
        source('e1', [
          const Ingredient(name: 'šećer', quantity: 10, unit: 'g'),
          const Ingredient(name: 'secer', quantity: 10, unit: 'g'),
        ]),
      );
      expect(lines, hasLength(2));
    });
  });

  group('identitet potražnje po unosu', () {
    test('dve pojave istog recepta imaju odvojene potrebe', () {
      const ingredients = [
        Ingredient(name: 'pirinač', quantity: 200, unit: 'g'),
      ];
      final monday = demandFor(source('pon', ingredients));
      final friday = demandFor(source('pet', ingredients, servings: 4));
      expect(monday.single.key == friday.single.key, isFalse);
      expect(monday.single.micros, toMicros(200));
      expect(friday.single.micros, toMicros(400));
    });

    test('ponovno računanje istog izvora daje isti ključ', () {
      const ingredients = [
        Ingredient(name: 'pirinač', quantity: 200, unit: 'g'),
      ];
      expect(
        demandFor(source('pon', ingredients)).single.key,
        demandFor(source('pon', ingredients, servings: 3)).single.key,
      );
    });
  });

  group('zbir za listu', () {
    test('sabira uporedive potrebe i pamti izvore', () {
      final needs = summarize([
        ...demandFor(
          source('pon', [
            const Ingredient(name: 'mleko', quantity: 0.5, unit: 'l'),
          ]),
        ),
        ...demandFor(
          source('pet', [
            const Ingredient(name: 'Mleko', quantity: 250, unit: 'ml'),
          ]),
        ),
        ...demandFor(source('sre', [const Ingredient(name: 'mleko')])),
      ]);
      expect(needs, hasLength(2));
      final known = needs.firstWhere((n) => !n.isUnknown);
      expect(known.micros, toMicros(750));
      expect(known.sourceIds, ['pon', 'pet']);
      final unknown = needs.firstWhere((n) => n.isUnknown);
      expect(unknown.sourceIds, ['sre']);
    });
  });

  group('prikaz', () {
    test('veće količine u kg i l', () {
      expect(displayAmount(toMicros(1500), 'g'), (quantity: 1.5, unit: 'kg'));
      expect(displayAmount(toMicros(750), 'ml'), (quantity: 750.0, unit: 'ml'));
      expect(displayAmount(toMicros(2000), 'ml'), (quantity: 2.0, unit: 'l'));
      expect(displayAmount(toMicros(3), 'kom'), (quantity: 3.0, unit: 'kom'));
    });
  });
}
