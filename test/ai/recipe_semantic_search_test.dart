import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:tavli/ai/embedding_client.dart';
import 'package:tavli/ai/gateway_chat_client.dart';
import 'package:tavli/ai/recipe_semantic_search.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/recipe_embedding_repository.dart';
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

  test(
    'combines title hits and semantic hits once, with shared filters',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final embeddings = RecipeEmbeddingRepository(db, 'household');
      final titleMatch = _recipe(
        'title',
        'Šargarepa čorba',
      ).copyWith(prepMinutes: 15);
      final titleWithoutVector = _recipe(
        'title-no-vector',
        'Šargarepa iz rerne',
      ).copyWith(prepMinutes: 25);
      final semanticMatch = _recipe(
        'semantic',
        'Krem supa',
      ).copyWith(prepMinutes: 20);
      final filtered = _recipe(
        'filtered',
        'Šargarepa paprikaš',
      ).copyWith(prepMinutes: 60);
      final queryVector = List<double>.filled(recipeEmbeddingDimensions, 1);
      await embeddings.save(titleMatch, [
        1,
        ...List<double>.filled(recipeEmbeddingDimensions - 1, 0),
      ]);
      await embeddings.save(
        titleWithoutVector,
        List<double>.filled(recipeEmbeddingDimensions, 0),
      );
      await embeddings.save(semanticMatch, queryVector);
      final service = RecipeSemanticSearchService(
        embeddings: embeddings,
        client: OpenAIEmbeddingClient(
          GatewayChatClient(
            accountId: () => 'account',
            refresh: () async => false,
            invoke: (_, body) async {
              expect(body!['inputs'], [
                {'text': 'SARGAREPA', 'taskType': 'RETRIEVAL_QUERY'},
              ]);
              return FunctionResponse(
                status: 200,
                data: {
                  'model': recipeEmbeddingModel,
                  'embeddings': [queryVector],
                },
              );
            },
          ),
        ),
      );

      final result = await service.search(
        query: 'SARGAREPA',
        recipes: [semanticMatch, titleMatch, titleWithoutVector, filtered],
        filter: const RecipeFilter(query: 'SARGAREPA', maxPrepMinutes: 30),
      );
      expect(result.map((recipe) => recipe.id), [
        'title',
        'title-no-vector',
        'semantic',
      ]);
    },
  );

  test(
    'batches changed recipe vectors, caches them, and embeds each query',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final List<List<Map<String, Object?>>> calls = [];
      final gateway = GatewayChatClient(
        accountId: () => 'account',
        refresh: () async => false,
        invoke: (_, body) async {
          final inputs = (body!['inputs'] as List).cast<Map<String, Object?>>();
          calls.add(inputs);
          final vectors = [
            for (final input in inputs)
              List<double>.filled(
                recipeEmbeddingDimensions,
                input['taskType'] == 'RETRIEVAL_QUERY'
                    ? 1
                    : input['text'].toString().contains('Pasulj')
                    ? 0.8
                    : 0.1,
              ),
          ];
          return FunctionResponse(
            status: 200,
            data: {'model': recipeEmbeddingModel, 'embeddings': vectors},
          );
        },
      );
      final service = RecipeSemanticSearchService(
        client: OpenAIEmbeddingClient(gateway),
        embeddings: RecipeEmbeddingRepository(db, 'household'),
      );
      final recipes = [
        _recipe('beans', 'Pasulj'),
        _recipe('salad', 'Zelena salata'),
      ];

      final first = await service.search(
        query: 'topli obrok',
        recipes: recipes,
        filter: const RecipeFilter(query: 'topli obrok'),
      );
      final second = await service.search(
        query: 'brza vecera',
        recipes: recipes,
        filter: const RecipeFilter(query: 'brza vecera'),
      );

      expect(first.first.id, 'beans');
      expect(second.first.id, 'beans');
      expect(calls.map((inputs) => inputs.length), [3, 1]);
      expect(calls.last.single['taskType'], 'RETRIEVAL_QUERY');
    },
  );
}
