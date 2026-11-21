import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/food_matcher.dart';

FoodIdentity food(String id, String name) => FoodIdentity(
  id: id,
  slug: id,
  name: name,
  category: 'Ostalo',
  baseUnit: FoodBaseUnit.piece,
);

AliasEntry alias(FoodIdentity f, String normalized, {String? householdId}) =>
    AliasEntry(food: f, aliasNormalized: normalized, householdId: householdId);

const scopeA = FoodLookupScope(householdId: 'A');

Future<FoodMatchResult> find(
  List<AliasEntry> entries,
  String text, {
  FoodLookupScope scope = scopeA,
  List<CatalogFood> foods = const [],
}) => AliasFoodMatcher(
  entries,
  foods: foods,
).findByName(originalText: text, scope: scope);

void main() {
  final jaje = food('jaje', 'jaje');

  group('shared aliases', () {
    test('confirmed alias jaja returns Matched jaje', () async {
      final r = await find([alias(jaje, 'jaja')], 'jaja');
      expect(r, isA<Matched>());
      expect((r as Matched).food.id, 'jaje');
    });

    test('canonical name matches without an alias row', () async {
      final mleko = food('mleko', 'mleko');
      final r = await find(
        [alias(jaje, 'jaja')],
        'mleko',
        foods: [CatalogFood(jaje), CatalogFood(mleko)],
      );
      expect((r as Matched).food.id, 'mleko');
    });

    test('shared canonical name is visible when only A has an alias', () async {
      final b = await find(
        [alias(jaje, 'jajce', householdId: 'A')],
        'jaje',
        scope: const FoodLookupScope(householdId: 'B'),
        foods: [CatalogFood(jaje)],
      );
      expect((b as Matched).food.id, 'jaje');
    });

    test(
      'unrelated household alias does not promote a canonical name',
      () async {
        final prepelica = food('jaje-prepelica', 'jaje od prepelice');
        final entries = [
          alias(jaje, 'jaja'),
          alias(prepelica, 'jaje'),
          alias(jaje, 'jajce', householdId: 'A'),
        ];
        final r = await find(
          entries,
          'jaje',
          foods: [CatalogFood(jaje), CatalogFood(prepelica)],
        );
        expect(r, isA<Unresolved>());
      },
    );

    test('unknown zmajevo voće is Unresolved', () async {
      final r = await find([alias(jaje, 'jaja')], 'zmajevo voće');
      expect(r, isA<Unresolved>());
    });

    test(
      'similar but different jogurt vs kiselo mleko is Unresolved',
      () async {
        final kiselo = food('kiselo-mleko', 'kiselo mleko');
        final r = await find([alias(kiselo, 'kiselo mleko')], 'jogurt');
        expect(r, isA<Unresolved>());
      },
    );

    test('empty and whitespace-only input is Unresolved', () async {
      final entries = [alias(jaje, 'jaja')];
      expect(await find(entries, ''), isA<Unresolved>());
      expect(await find(entries, '   \t '), isA<Unresolved>());
    });

    test('matching ignores case and extra whitespace', () async {
      final cevapi = food('cevapi', 'ćevapi');
      final kajmak = food('kajmak', 'sir kajmak');
      final entries = [alias(cevapi, 'ćevapi'), alias(kajmak, 'sir kajmak')];
      expect(await find(entries, 'Ćevapi'), isA<Matched>());
      expect(await find(entries, '  sir   kajmak '), isA<Matched>());
    });

    test('alias given with case and spaces still matches', () async {
      final r = await find([alias(jaje, ' Jaja ')], 'jaja');
      expect((r as Matched).food.id, 'jaje');
    });

    test('diacritics are not folded', () async {
      final luk = food('cesnjak', 'češnjak');
      final r = await find([alias(luk, 'češnjak')], 'cesnjak');
      expect(r, isA<Unresolved>());
    });

    test('same alias twice for one food is one match', () async {
      final r = await find([alias(jaje, 'jaja'), alias(jaje, 'jaja')], 'jaja');
      expect(r, isA<Matched>());
    });

    test(
      'household A override wins over shared alias; B keeps shared',
      () async {
        final prepelica = food('jaje-prepelica', 'jaje od prepelice');
        final entries = [
          alias(jaje, 'jaja'),
          alias(prepelica, 'jaja', householdId: 'A'),
        ];
        final a = await find(entries, 'jaja');
        final b = await find(
          entries,
          'jaja',
          scope: const FoodLookupScope(householdId: 'B'),
        );
        expect((a as Matched).food.id, 'jaje-prepelica');
        expect((b as Matched).food.id, 'jaje');
      },
    );

    test('custom food of household A is invisible to household B', () async {
      final tajna = food('tajna', 'tajni sastojak');
      final entries = [alias(tajna, 'tajni', householdId: 'A')];
      expect(await find(entries, 'tajni'), isA<Matched>());
      final b = await find(
        entries,
        'tajni',
        scope: const FoodLookupScope(householdId: 'B'),
      );
      expect(b, isA<Unresolved>());
    });

    test('custom food name matches only in its own household', () async {
      final tajna = food('tajna', 'tajni sastojak');
      final entries = [alias(tajna, 'tajni', householdId: 'A')];
      final foods = [CatalogFood(tajna, householdId: 'A')];
      final b = await find(
        entries,
        'tajni sastojak',
        scope: const FoodLookupScope(householdId: 'B'),
        foods: foods,
      );
      expect(b, isA<Unresolved>());
      expect(
        await find(entries, 'tajni sastojak', foods: foods),
        isA<Matched>(),
      );
    });

    test('two disagreeing household mappings are Unresolved', () async {
      final prepelica = food('jaje-prepelica', 'jaje od prepelice');
      final r = await find([
        alias(jaje, 'jaja', householdId: 'A'),
        alias(prepelica, 'jaja', householdId: 'A'),
      ], 'jaja');
      expect(r, isA<Unresolved>());
    });

    test('household alias to the same food as shared is one match', () async {
      final r = await find([
        alias(jaje, 'jaja'),
        alias(jaje, 'jaja', householdId: 'A'),
      ], 'jaja');
      expect((r as Matched).food.id, 'jaje');
    });
  });

  group('shared conflicts', () {
    test('same shared alias for two foods is Unresolved', () async {
      final prepelica = food('jaje-prepelica', 'jaje od prepelice');
      final r = await find([
        alias(jaje, 'jaja'),
        alias(prepelica, 'jaja'),
      ], 'jaja');
      expect(r, isA<Unresolved>());
    });
  });

  group('withdrawn shared entries', () {
    test('withdrawn shared food is never Matched by its alias', () async {
      final r = await find(
        [alias(jaje, 'jaja')],
        'jaja',
        foods: [CatalogFood(jaje, withdrawn: true)],
      );
      expect(r, isA<Unresolved>());
    });

    test('withdrawn shared food is never Matched by its name', () async {
      final r = await find(
        const [],
        'jaje',
        foods: [CatalogFood(jaje, withdrawn: true)],
      );
      expect(r, isA<Unresolved>());
    });

    test('household alias to a withdrawn food is ignored', () async {
      final r = await find(
        [alias(jaje, 'jaja', householdId: 'A')],
        'jaja',
        foods: [CatalogFood(jaje, withdrawn: true)],
      );
      expect(r, isA<Unresolved>());
    });

    test('withdrawn shared alias gives way to its replacement', () async {
      final kokosje = food('jaje-kokosje', 'kokošje jaje');
      final r = await find([
        AliasEntry(food: jaje, aliasNormalized: 'jaja', withdrawn: true),
        alias(kokosje, 'jaja'),
      ], 'jaja');
      expect((r as Matched).food.id, 'jaje-kokosje');
    });

    test('withdrawn shared alias alone is Unresolved', () async {
      final r = await find([
        AliasEntry(food: jaje, aliasNormalized: 'jaja', withdrawn: true),
      ], 'jaja');
      expect(r, isA<Unresolved>());
    });
  });
}
