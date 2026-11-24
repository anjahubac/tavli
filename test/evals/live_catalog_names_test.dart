import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_errors.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/ai_router.dart';
import 'package:tavli/ai/chain_config.dart';
import 'package:tavli/ai/chat_client.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/ai/model_status_store.dart';
import 'package:tavli/ai/recipe_ai.dart';
import 'package:tavli/domain/food_matcher.dart';

// Merenje „nazivi sastojaka spremni za katalog“ (CAP-05): 30 fiksnih jela kroz
// pravi model, svaki sastojak se proverava matcherom nad legacy referencom.
// Pokreće se samo ručno:
//   flutter test test/evals/live_catalog_names_test.dart \
//     --dart-define=EVAL_LABEL=before --dart-define=EVAL_COMMIT=<sha>
// GEMINI_API_KEY se prosleđuje kroz okruženje procesa za ručnu evaluaciju.
// Bez EVAL_LABEL se preskače, pa `flutter test` ostaje bez mreže.

const label = String.fromEnvironment('EVAL_LABEL');
const commit = String.fromEnvironment('EVAL_COMMIT');
const dishesPath = 'evals/capstone/dishes.json';
const referencePath =
    'specs/018-ingredient-catalog/research/legacy-food-reference.csv';

AliasFoodMatcher referenceMatcher() {
  final foods = <CatalogFood>[];
  final aliases = <AliasEntry>[];
  for (final line in File(referencePath).readAsLinesSync().skip(1)) {
    if (line.trim().isEmpty) continue;
    final parts = line.split(',');
    final name = parts.first.trim();
    final food = FoodIdentity(
      id: name,
      slug: name,
      name: name,
      category: parts.length > 1 ? parts[1].trim() : 'ostalo',
      baseUnit: FoodBaseUnit.gram,
    );
    foods.add(CatalogFood(food));
    final raw = parts.length > 2 ? parts.sublist(2).join(',') : '';
    for (final a in raw.split('|')) {
      if (a.trim().isNotEmpty) {
        aliases.add(AliasEntry(food: food, aliasNormalized: a.trim()));
      }
    }
  }
  return AliasFoodMatcher(aliases, foods: foods);
}

void main() {
  test(
    'catalog names: $label',
    () async {
      HttpOverrides.global = null;
      final dishes =
          (jsonDecode(File(dishesPath).readAsStringSync())
                  as Map<String, dynamic>)['dishes']
              as List<dynamic>;
      final matcher = referenceMatcher();
      final key = Platform.environment['GEMINI_API_KEY']?.trim();
      if (key == null || key.isEmpty) {
        throw StateError('GEMINI_API_KEY nije podešen za ručnu evaluaciju.');
      }
      final ai = RecipeAI(
        AIRouter(
          config: () => ChainConfig.defaults,
          client: OpenAICompatibleClient(),
          keys: OwnKeySource(InMemoryKeyStore({AIProvider.gemini: key})),
          status: InMemoryModelStatusStore(),
        ),
      );
      const scope = FoodLookupScope(householdId: 'eval');

      Future<Map<String, Object?>> one(String dish) async {
        try {
          final r = await ai.fromDishName(dish);
          final items = <Map<String, Object?>>[];
          for (final i in r.value.ingredients) {
            final m = await matcher.findByName(
              originalText: i.name,
              scope: scope,
            );
            items.add({
              'name': i.name,
              'note': i.note,
              'matched': m is Matched,
              if (m is Matched) 'food': m.food.name,
            });
          }
          return {'dish': dish, 'model': r.model.label, 'ingredients': items};
        } on AllModelsExhausted catch (e) {
          return {
            'dish': dish,
            'error': 'AllModelsExhausted:${e.invalidOutput}',
          };
        } on Object catch (e) {
          return {'dish': dish, 'error': e.runtimeType.toString()};
        }
      }

      // Besplatni nivo ima minutne i dnevne limite: jedno jelo po jedno, a pri
      // iscrpljenim modelima se čeka do kraja pauze (najviše 70 s) i ponavlja
      // do 4 puta. Izlazi koji su ipak ostali greška se broje u `errors`.
      Future<Map<String, Object?>> withRetry(String dish) async {
        var r = await one(dish);
        for (
          var n = 0;
          n < 4 && r['error'] == 'AllModelsExhausted:false';
          n++
        ) {
          await Future<void>.delayed(const Duration(seconds: 70));
          r = await one(dish);
        }
        return r;
      }

      final results = <Map<String, Object?>>[];
      for (final dish in dishes.cast<String>()) {
        results.add(await withRetry(dish));
      }

      var total = 0;
      var matched = 0;
      for (final r in results) {
        for (final i in (r['ingredients'] as List<dynamic>? ?? const [])) {
          total++;
          if ((i as Map<String, Object?>)['matched'] == true) matched++;
        }
      }
      final out = File('evals/capstone/traces/catalog-names-$label.jsonl');
      out.writeAsStringSync(
        [
          jsonEncode({
            'label': label,
            'commit': commit,
            'dishes': dishes.length,
            'ingredients': total,
            'matched': matched,
            'errors': results.where((r) => r.containsKey('error')).length,
          }),
          for (final r in results) jsonEncode(r),
        ].join('\n'),
      );
      // ignore: avoid_print
      print('CATALOG_NAMES $label matched=$matched/$total');
    },
    skip: label.isEmpty ? 'ručno: traži EVAL_LABEL i pravi ključ' : null,
    timeout: const Timeout(Duration(minutes: 40)),
  );
}
