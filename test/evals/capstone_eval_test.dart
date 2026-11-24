import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_errors.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/ai_router.dart';
import 'package:tavli/ai/chain_config.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/ai/meal_plan_ai.dart';
import 'package:tavli/ai/model_status_store.dart';
import 'package:tavli/ai/recipe_ai.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/shopping_totals.dart';
import 'package:tavli/domain/food_matcher.dart';
import 'package:tavli/domain/meal_plan.dart';
import 'package:tavli/domain/plan_calendar.dart';

import '../ai/ai_router_test.dart' show FakeClient, geminiPro, groqText;

// Capstone evaluacija (CAP-05): 16 fiksnih slučajeva u
// evals/capstone/cases.jsonl. Deterministični slučajevi se izvršavaju ovde nad
// pravim kodom (RecipeAI, AIRouter, AliasFoodMatcher) sa lažnim modelom.
// Slučajevi sa modom `live` traže pravi model i beleže se ručno u results.md.

const casesPath = 'evals/capstone/cases.jsonl';
ShoppingItemRow row(
  String id,
  String name,
  double? quantity,
  String? unit, {
  bool bought = false,
}) => ShoppingItemRow(
  id: id,
  listId: 'l1',
  name: name,
  quantity: quantity,
  unit: unit,
  category: 'ostalo',
  isBought: bought,
  isManual: false,
  fromRecipeIdsJson: '[]',
);

const chain = ChainConfig(
  vision: [geminiPro, groqText],
  text: [geminiPro, groqText],
);

List<Map<String, dynamic>> loadCases() => [
  for (final l in File(casesPath).readAsLinesSync())
    if (l.trim().isNotEmpty) jsonDecode(l) as Map<String, dynamic>,
];

void main() {
  final cases = loadCases();
  Map<String, dynamic> byId(String id) =>
      cases.firstWhere((c) => c['id'] == id);

  late FakeClient client;
  late RecipeAI ai;

  setUp(() {
    client = FakeClient();
    final router = AIRouter(
      config: () => chain,
      client: client,
      keys: OwnKeySource(
        InMemoryKeyStore({AIProvider.gemini: 'g', AIProvider.groq: 'q'}),
      ),
      status: InMemoryModelStatusStore(),
      clock: () => DateTime.utc(2026, 11, 21, 12),
    );
    ai = RecipeAI(router, clock: () => DateTime.utc(2026, 11, 21, 12));
  });

  group('registar slučajeva', () {
    test('ima tačno EV-01 do EV-16, svaki sa obaveznim poljima', () {
      expect(cases.map((c) => c['id']), [
        for (var i = 1; i <= 16; i++) 'EV-${i.toString().padLeft(2, '0')}',
      ]);
      for (final c in cases) {
        for (final k in ['title', 'mode', 'input', 'expected', 'why']) {
          expect(c[k], isNotNull, reason: '${c['id']} nema $k');
        }
        expect(c['mode'], anyOf('deterministic', 'live'), reason: '${c['id']}');
      }
    });

    test(
      'EV-11 do EV-16 su deterministični, EV-01 do EV-10 mogu biti live',
      () {
        for (final c in cases.skip(10)) {
          expect(c['mode'], 'deterministic', reason: c['id'] as String);
        }
      },
    );
  });

  group('deterministični slučajevi', () {
    test(
      'EV-05 nema poklapanja: nepoznata namirnica ostaje Unresolved',
      () async {
        expect(byId('EV-05')['mode'], 'deterministic');
        final matcher = AliasFoodMatcher(
          const [],
          foods: [
            const CatalogFood(
              FoodIdentity(
                id: 'f-luk',
                slug: 'crni-luk',
                name: 'crni luk',
                category: 'Povrće',
                baseUnit: FoodBaseUnit.gram,
              ),
            ),
          ],
        );
        final r = await matcher.findByName(
          originalText: 'domaća mešavina',
          scope: const FoodLookupScope(householdId: 'h1'),
        );
        expect(r, isA<Unresolved>());
      },
    );

    test(
      'EV-13 povučena namirnica (nedostupan izvor) nikad nije Matched',
      () async {
        expect(byId('EV-13')['mode'], 'deterministic');
        const luk = FoodIdentity(
          id: 'f-luk',
          slug: 'crni-luk',
          name: 'crni luk',
          category: 'Povrće',
          baseUnit: FoodBaseUnit.gram,
        );
        final matcher = AliasFoodMatcher(
          const [],
          foods: [const CatalogFood(luk, withdrawn: true)],
        );
        final r = await matcher.findByName(
          originalText: 'crni luk',
          scope: const FoodLookupScope(householdId: 'h1'),
        );
        expect(r, isA<Unresolved>());
      },
    );

    test('EV-08 slika bez recepta: kontrolisana greška, bez recepta', () async {
      expect(byId('EV-08')['mode'], 'deterministic');
      client.script(geminiPro, ['{"error":"not_a_recipe"}']);
      await expectLater(
        ai.fromImage(AIImage(Uint8List.fromList([1, 2, 3]))),
        throwsA(isA<NotARecipeException>()),
      );
      // Odgovor „nije recept“ je konačan: ne prelazi se na drugi model.
      expect(client.calls, ['gemini/pro']);
    });

    test('EV-11 nevalidan zahtev (4xx): po jedan poziv po modelu, pa greška bez petlje', () async {
      expect(byId('EV-11')['mode'], 'deterministic');
      for (final m in [geminiPro, groqText]) {
        client.script(m, [const BadRequestError('loš zahtev')]);
      }
      await expectLater(
        ai.fromDishName('gulaš'),
        throwsA(isA<AllModelsExhausted>()),
      );
      expect(client.calls, ['gemini/pro', 'groq/text']);
    });

    test(
      'EV-12 nevalidan izlaz modela: jedna popravka, pa greška bez recepta',
      () async {
        expect(byId('EV-12')['mode'], 'deterministic');
        const bad =
            '{"title":"Gulaš","servings":0,"ingredients":[],"steps":[]}';
        for (final m in [geminiPro, groqText]) {
          client.script(m, [bad, bad]);
        }
        await expectLater(
          ai.fromDishName('gulaš'),
          throwsA(isA<AllModelsExhausted>()),
        );
        // Jedna popravka istom modelu, pa stop bez ostatka lanca (#69).
        // Pre #69 ovde su bila 4 poziva (ceo lanac), vidi
        // ev12_repair_before_after_test.dart.
        expect(client.calls, ['gemini/pro', 'gemini/pro']);
      },
    );

    test('EV-15 limit kod svih modela: ograničen broj poziva i vreme ponovnog pokušaja', () async {
      expect(byId('EV-15')['mode'], 'deterministic');
      for (final m in [geminiPro, groqText]) {
        client.script(m, [const RateLimitError('limit')]);
      }
      await expectLater(
        ai.fromDishName('gulaš'),
        throwsA(
          isA<AllModelsExhausted>()
              .having((e) => e.attempts.length, 'pokušaja', 2)
              .having((e) => e.invalidOutput, 'invalidOutput', isFalse)
              .having(
                (e) => e.nextAvailableAt,
                'nextAvailableAt',
                DateTime.utc(2026, 11, 21, 12, 1),
              ),
        ),
      );
      expect(client.calls, ['gemini/pro', 'groq/text']);
    });

    test('EV-04 alat: obračun sabira g i kg iste namirnice u jednu stavku', () {
      expect(byId('EV-04')['mode'], 'deterministic');
      final totals = shoppingTotalsOf([
        row('a', 'brašno', 200, 'g'),
        row('b', 'Brašno', 0.5, 'kg'),
      ]);
      expect(totals, hasLength(1));
      expect(totals.single.openMicros, 700 * 1000000);
      expect(totals.single.hasUnknown, isFalse);
    });

    test(
      'EV-16 greška alata: nepoznata količina se označava, bez izuzetka',
      () {
        expect(byId('EV-16')['mode'], 'deterministic');
        final totals = shoppingTotalsOf([
          row('a', 'so', null, null),
          row('b', 'so', 5, 'g'),
          row('c', 'mleko', 1, 'xyz'),
        ]);
        final salt = totals.where((t) => t.ingredient == 'so').toList();
        expect(salt.any((t) => t.hasUnknown), isTrue);
        expect(totals.map((t) => t.ingredient), containsAll(['so', 'mleko']));
      },
    );

    test('EV-14 van opsega: plan sa ID-jem recepta kojeg nema u biblioteci se odbija', () {
      expect(byId('EV-14')['mode'], 'deterministic');
      expect(
        () => parseOutline(
          {
            'meals': [
              {
                'date': '2026-11-17',
                'meal': 'lunch',
                'recipeId': 'r-999',
                'title': 'Musaka',
              },
            ],
          },
          slots: [MealSlot(CivilDate.parse('2026-11-17'), MealType.lunch)],
          library: {'r-123': 'Sarma'},
        ),
        throwsFormatException,
      );
    });
  });
}
