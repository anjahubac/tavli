import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:tavli/ai/gateway_chat_client.dart';
import 'package:tavli/ai/recipe_semantic_search.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/recipe_search.dart';

Recipe _recipe(String id, String title) => Recipe(
  id: id,
  title: title,
  servings: 2,
  ingredients: const [Ingredient(name: 'namirnica')],
  source: RecipeSource.manual,
  createdAt: DateTime.utc(2026),
);

void main() {
  test('server ranking searches beyond the 256-candidate SQL limit', () async {
    final recipes = [
      for (var i = 0; i < 257; i++) _recipe('recipe-$i', 'Jelo $i'),
    ];
    final batches = <List<String>>[];
    final gateway = GatewayChatClient(
      accountId: () => 'account',
      refresh: () async => false,
      invoke: (_, body) async {
        final ids = (body!['recipeIds'] as List<Object?>).cast<String>();
        batches.add(ids);
        return FunctionResponse(
          status: 200,
          data: {
            'matches': [
              {'recipe_id': ids.first, 'distance': ids.length == 1 ? 0.1 : 0.4},
            ],
          },
        );
      },
    );
    final hits = await IndexedRecipeSearchService(gateway).search(
      query: 'večera sa povrćem',
      recipes: recipes,
      filter: const RecipeFilter(query: 'večera sa povrćem'),
    );
    expect(batches.map((ids) => ids.length), [256, 1]);
    expect(batches.expand((ids) => ids), recipes.map((recipe) => recipe.id));
    expect(hits.map((recipe) => recipe.id), ['recipe-256', 'recipe-0']);
  });

  test('server ranking merges title hits and filters candidate IDs', () async {
    final title = _recipe('title', 'Čorba od sočiva').copyWith(prepMinutes: 10);
    final titleWithoutVector = _recipe(
      'unindexed',
      'Čorba od povrća',
    ).copyWith(prepMinutes: 20);
    final nearby = _recipe('nearby', 'Krem supa').copyWith(prepMinutes: 15);
    final distant = _recipe('distant', 'Salata').copyWith(prepMinutes: 5);
    final filtered = _recipe(
      'filtered',
      'Čorba od mesa',
    ).copyWith(prepMinutes: 90);
    final gateway = GatewayChatClient(
      accountId: () => 'account',
      refresh: () async => false,
      invoke: (_, body) async {
        expect(body!['query'], 'corba');
        expect(body['recipeIds'], ['title', 'unindexed', 'nearby', 'distant']);
        return const FunctionResponse(
          status: 200,
          data: {
            'matches': [
              {'recipe_id': 'distant', 'distance': 0.5},
              {'recipe_id': 'nearby', 'distance': 0.2},
              {'recipe_id': 'title', 'distance': 0.1},
              {'recipe_id': 'filtered', 'distance': 0.0},
            ],
          },
        );
      },
    );
    final hits = await IndexedRecipeSearchService(gateway).search(
      query: 'corba',
      recipes: [title, titleWithoutVector, nearby, distant, filtered],
      filter: const RecipeFilter(query: 'corba', maxPrepMinutes: 30),
    );
    expect(hits.map((recipe) => recipe.id), [
      'title',
      'unindexed',
      'nearby',
      'distant',
    ]);
  });
}
