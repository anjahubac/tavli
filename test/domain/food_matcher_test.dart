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
}) => AliasFoodMatcher(entries).findByName(originalText: text, scope: scope);

void main() {
  final jaje = food('jaje', 'jaje');

  group('shared aliases', () {
    test('confirmed alias jaja returns Matched jaje', () async {
      final r = await find([alias(jaje, 'jaja')], 'jaja');
      expect(r, isA<Matched>());
      expect((r as Matched).food.id, 'jaje');
    });

    test('canonical name matches without an alias row', () async {
      final r = await find([alias(jaje, 'jaja')], 'jaje');
      expect(r, isA<Matched>());
      expect((r as Matched).food.id, 'jaje');
    });

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

    test('diacritics are not folded', () async {
      final luk = food('cesnjak', 'češnjak');
      final r = await find([alias(luk, 'češnjak')], 'cesnjak');
      expect(r, isA<Unresolved>());
    });

    test('same alias twice for one food is one match', () async {
      final r = await find([alias(jaje, 'jaja'), alias(jaje, 'jaja')], 'jaja');
      expect(r, isA<Matched>());
    });

    test('same shared alias for two foods is Unresolved', () async {
      final prepelica = food('jaje-prepelica', 'jaje od prepelice');
      final r = await find([
        alias(jaje, 'jaja'),
        alias(prepelica, 'jaja'),
      ], 'jaja');
      expect(r, isA<Unresolved>());
    });
  });
}
