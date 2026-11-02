import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/shopping_demand.dart';
import 'package:tavli/domain/supply_allocation.dart';

DemandLine flour(String sourceId, double grams) => demandFor(
  DemandSource(
    id: sourceId,
    baseServings: 2,
    servings: 2,
    ingredients: [Ingredient(name: 'brašno', quantity: grams, unit: 'g')],
  ),
).single;

Supply flourSupply(
  String id,
  double? grams, {
  String? samePhysicalAs,
  SupplyOrigin origin = SupplyOrigin.pantry,
}) => Supply(
  id: id,
  origin: origin,
  ingredient: 'brašno',
  unitGroup: 'mass',
  micros: grams == null ? null : toMicros(grams),
  samePhysicalAs: samePhysicalAs,
);

DemandOrder at(int day, {int meal = 1}) =>
    DemandOrder(date: DateTime.utc(2026, 11, day), mealOrder: meal);

void main() {
  test(
    '300/100/200/400: kupljeno i prenos u ostavu nisu dvostruko pokriće',
    () {
      final pantry = flourSupply('ostava', 100);
      final purchase = flourSupply(
        'kupljeno',
        200,
        origin: SupplyOrigin.purchase,
      );
      final receipt = flourSupply('prijem', 200, samePhysicalAs: 'kupljeno');

      final need300 = DemandRequest(flour('e1', 300), at(2));
      final before = allocateSupply([need300], [pantry, purchase]);
      expect(before.remaining(need300.line.key), 0);

      // Prenos kupljenog u ostavu je ista zaliha, ne još 200 g.
      final after = allocateSupply([need300], [pantry, purchase, receipt]);
      expect(after.remaining(need300.line.key), 0);
      expect(after.allocatedTotal, toMicros(300));

      // Potreba poraste na 400 g: ostaje 100 g za nabavku.
      final need400 = DemandRequest(flour('e1', 400), at(2));
      final grown = allocateSupply([need400], [pantry, purchase, receipt]);
      expect(grown.remaining(need400.line.key), toMicros(100));
    },
  );

  test('potvrđena zaliha se koristi jednom kroz ceo plan, hronološki', () {
    final week1 = DemandRequest(flour('e-pon', 300), at(2));
    final week2 = DemandRequest(flour('e-pon2', 300), at(9));
    final result = allocateSupply([week2, week1], [flourSupply('ostava', 400)]);
    expect(result.remaining(week1.line.key), 0);
    expect(result.remaining(week2.line.key), toMicros(200));
    expect(result.allocatedTotal, toMicros(400));
  });

  test('isti dan: redosled obroka pa id unosa', () {
    final dinner = DemandRequest(flour('a', 100), at(2, meal: 2));
    final lunchB = DemandRequest(flour('b', 100), at(2));
    final lunchA = DemandRequest(flour('a2', 100), at(2));
    final result = allocateSupply(
      [dinner, lunchB, lunchA],
      [flourSupply('ostava', 150)],
    );
    expect(result.remaining(lunchA.line.key), 0);
    expect(result.remaining(lunchB.line.key), toMicros(50));
    expect(result.remaining(dinner.line.key), toMicros(100));
  });

  test('samostalna priprema ide posle planiranih obroka', () {
    final recipe = DemandRequest(flour('priprema', 100), const DemandOrder());
    final planned = DemandRequest(flour('e1', 100), at(20));
    final result = allocateSupply([recipe, planned], [flourSupply('o', 100)]);
    expect(result.remaining(planned.line.key), 0);
    expect(result.remaining(recipe.line.key), toMicros(100));
  });

  test('isti rezultat bez obzira na redosled ulaza', () {
    final demands = [
      DemandRequest(flour('x', 120), at(3)),
      DemandRequest(flour('y', 80), at(1)),
      DemandRequest(flour('z', 50), at(3, meal: 0)),
    ];
    final supplies = [flourSupply('s2', 60), flourSupply('s1', 100)];
    final a = allocateSupply(demands, supplies);
    final b = allocateSupply(
      demands.reversed.toList(),
      supplies.reversed.toList(),
    );
    expect(a.allocations, b.allocations);
  });

  test('nepoznata zaliha ne pokriva brojčanu potrebu', () {
    final need = DemandRequest(flour('e1', 300), at(2));
    final result = allocateSupply([need], [flourSupply('ostava', null)]);
    expect(result.remaining(need.line.key), toMicros(300));
    expect(result.allocations, isEmpty);
  });

  test('nepoznata potreba traži proveru dok se izričito ne potvrdi', () {
    final salt = DemandRequest(
      demandFor(
        const DemandSource(
          id: 'e1',
          baseServings: 2,
          servings: 2,
          ingredients: [Ingredient(name: 'so', note: 'po ukusu')],
        ),
      ).single,
      at(2),
    );
    final open = allocateSupply([salt], const []);
    expect(open.remaining(salt.line.key), isNull);
    expect(open.isCovered(salt.line.key), isFalse);

    final confirmed = allocateSupply(
      [salt],
      const [],
      confirmedWhole: {salt.line.key},
    );
    expect(confirmed.isCovered(salt.line.key), isTrue);
  });

  test('"imam celu stavku" pokriva samo potvrđeni unos', () {
    final a = DemandRequest(flour('a', 300), at(2));
    final b = DemandRequest(flour('b', 300), at(3));
    final result = allocateSupply(
      [a, b],
      const [],
      confirmedWhole: {a.line.key},
    );
    expect(result.isCovered(a.line.key), isTrue);
    expect(result.remaining(b.line.key), toMicros(300));
  });

  test('druga namirnica ili neuporediva jedinica ne pokriva potrebu', () {
    final need = DemandRequest(flour('e1', 300), at(2));
    final result = allocateSupply(
      [need],
      [
        const Supply(
          id: 'kukuruzno',
          origin: SupplyOrigin.pantry,
          ingredient: 'kukuruzno brašno',
          unitGroup: 'mass',
          micros: 1000000000,
        ),
        Supply(
          id: 'kesice',
          origin: SupplyOrigin.pantry,
          ingredient: 'brašno',
          unitGroup: 'count:kom',
          micros: toMicros(5),
        ),
      ],
    );
    expect(result.remaining(need.line.key), toMicros(300));
  });

  test('prijem bez kupljene stavke u ulazu je sopstvena zaliha', () {
    final need = DemandRequest(flour('e1', 300), at(2));
    final result = allocateSupply(
      [need],
      [flourSupply('prijem', 200, samePhysicalAs: 'nepoznata-kupovina')],
    );
    expect(result.remaining(need.line.key), toMicros(100));
  });
}
