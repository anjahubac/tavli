import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/ai_response_validator.dart';
import 'package:tavli/ai/ai_router.dart';
import 'package:tavli/ai/chain_config.dart';
import 'package:tavli/ai/chat_client.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/ai/model_status_store.dart';
import 'package:tavli/ai/prompts.dart';
import 'package:tavli/ai/recipe_ai.dart';
import 'package:tavli/ai/recipe_image_client.dart';
import 'package:tavli/domain/recipe.dart';

const _model = ModelSpec(
  provider: AIProvider.gemini,
  model: 'flash',
  label: 'Gemini Flash',
);

class _ScriptedClient implements ChatClient {
  _ScriptedClient(this.answers);

  final List<String> answers;
  final requests = <AIRequest>[];

  @override
  Future<String> complete(
    ModelSpec model,
    AIRequest request, {
    required String apiKey,
  }) async {
    requests.add(request);
    return answers.removeAt(0);
  }
}

RecipeAI _ai(_ScriptedClient client) => RecipeAI(
  AIRouter(
    config: () => const ChainConfig(vision: [_model], text: [_model]),
    client: client,
    keys: OwnKeySource(InMemoryKeyStore({AIProvider.gemini: 'g-key'})),
    status: InMemoryModelStatusStore(),
    clock: () => DateTime.utc(2026, 11, 23, 12),
  ),
  clock: () => DateTime.utc(2026, 11, 23, 12),
);

const _zeljanica =
    'One thick rope of rolled phyllo coiled into a flat snail spiral, whole '
    'pie uncut, in a round black pan, top-down.';

Map<String, dynamic> _recipeJson({Object? description = _zeljanica}) => {
  'title': 'Zeljanica',
  'servings': 6,
  'prepMinutes': 60,
  'ingredients': [
    {'name': 'kora za pitu', 'quantity': 500, 'unit': 'g'},
    {'name': 'spanać', 'quantity': 400, 'unit': 'g'},
  ],
  'steps': ['Uvij kore.', 'Peci.'],
  'image_description': ?description,
};

Recipe _recipe({String? description, RecipeImageSource? imageSource}) => Recipe(
  id: 'r1',
  title: 'Sarma',
  servings: 4,
  ingredients: const [Ingredient(name: 'kiseli kupus')],
  steps: const ['Zavij sarme.'],
  source: RecipeSource.ai,
  createdAt: DateTime.utc(2026, 11, 23),
  imageDescription: description,
  imageSource: imageSource,
);

void main() {
  group('image_description parsing (I1)', () {
    test('is optional and never rejects a recipe', () {
      expect(aiImageDescription(null), isNull);
      expect(aiImageDescription(42), isNull);
      expect(aiImageDescription('   '), isNull);
      final recipe = recipeFromAiResponse(
        _recipeJson(description: null),
        id: 'r',
        source: RecipeSource.ai,
        createdAt: DateTime.utc(2026),
      );
      expect(recipe.imageDescription, isNull);
    });

    test('collapses whitespace and caps the length', () {
      expect(aiImageDescription('  Beans \n in\ta pot. '), 'Beans in a pot.');
      final long = aiImageDescription('word ' * 300)!;
      expect(long.length, lessThanOrEqualTo(maxImageDescriptionLength));
    });

    test('is stored on a parsed recipe', () {
      final recipe = recipeFromAiResponse(
        _recipeJson(),
        id: 'r',
        source: RecipeSource.ai,
        createdAt: DateTime.utc(2026),
      );
      expect(recipe.imageDescription, _zeljanica);
    });
  });

  test('saved recipe JSON keeps description and image source; old JSON '
      'still reads', () {
    final recipe = _recipe(
      description: _zeljanica,
      imageSource: RecipeImageSource.ai,
    );
    final read = Recipe.fromJson(
      jsonDecode(jsonEncode(recipe.toJson())) as Map<String, dynamic>,
    );
    expect(read.imageDescription, _zeljanica);
    expect(read.imageSource, RecipeImageSource.ai);

    final old = recipe.toJson()
      ..remove('imageDescription')
      ..remove('imageSource');
    final legacy = Recipe.fromJson(old);
    expect(legacy.imageDescription, isNull);
    expect(legacy.imageSource, isNull);
  });

  test('the recipe prompt asks for an English description with an '
      'explicit shape', () {
    expect(recipeSystemPrompt, contains('"image_description": string'));
    expect(recipeSystemPrompt, contains('ENGLISH'));
    expect(recipeSystemPrompt, contains('snail spiral'));
    expect(recipeSystemPrompt, contains('No text, people, hands'));
  });

  test('a recipe from a dish name keeps the description from the same '
      'call', () async {
    final client = _ScriptedClient([jsonEncode(_recipeJson())]);
    final result = await _ai(client).fromDishName('zeljanica');
    expect(client.requests, hasLength(1));
    expect(result.value.source, RecipeSource.ai);
    expect(result.value.imageDescription, _zeljanica);
  });

  test('refine keeps the existing description and image source', () async {
    final client = _ScriptedClient([
      jsonEncode(_recipeJson(description: 'Something else entirely here.')),
    ]);
    final current = _recipe(
      description: _zeljanica,
      imageSource: RecipeImageSource.ai,
    );
    final refined = await _ai(client).refine(current, 'Više spanaća');
    expect(refined.value.imageDescription, _zeljanica);
    expect(refined.value.imageSource, RecipeImageSource.ai);
  });

  group('fallback description call', () {
    test('uses its own task and prompt with title, ingredients and '
        'steps', () async {
      final client = _ScriptedClient([
        jsonEncode({
          'image_description':
              'Rolled cabbage leaf parcels in a pot of reddish sauce.',
        }),
      ]);
      final description = await _ai(client).describeImage(_recipe());
      expect(
        description,
        'Rolled cabbage leaf parcels in a pot of reddish sauce.',
      );
      final request = client.requests.single;
      expect(request.task, AITask.recipeImageDescription);
      expect(request.system, imageDescriptionSystemPrompt);
      expect(request.prompt, contains('Sarma'));
      expect(request.prompt, contains('kiseli kupus'));
      expect(request.prompt, contains('Zavij sarme.'));
    });

    test('an answer without a description is repaired once', () async {
      final client = _ScriptedClient([
        jsonEncode({'title': 'Sarma'}),
        jsonEncode({'image_description': 'Cabbage rolls in red sauce.'}),
      ]);
      final description = await _ai(client).describeImage(_recipe());
      expect(description, 'Cabbage rolls in red sauce.');
      expect(client.requests, hasLength(2));
    });
  });

  group('RecipeImageClient', () {
    const file = 'ai_00000000-0000-4000-8000-000000000001.jpg';

    Future<RecipeImageResult> answer(int status, Object? data) {
      final sent = <Map<String, Object?>>[];
      return RecipeImageClient((body) async {
        sent.add(body);
        expect(body.keys, unorderedEquals(['task', 'recipeId', 'description']));
        return FunctionResponse(status: status, data: data);
      }).generate('r1', _zeljanica);
    }

    test('sends only the task, recipe id and description', () async {
      Map<String, Object?>? sent;
      await RecipeImageClient((body) async {
        sent = body;
        return const FunctionResponse(status: 200, data: {'file': file});
      }).generate('r1', _zeljanica);
      expect(sent, {
        'task': 'recipe_image',
        'recipeId': 'r1',
        'description': _zeljanica,
      });
    });

    test('maps typed responses', () async {
      expect(
        await answer(200, {'file': file, 'path': 'h/$file'}),
        isA<RecipeImageReady>().having((r) => r.file, 'file', file),
      );
      expect(
        await answer(200, {'file': '../evil.jpg'}),
        isA<RecipeImageFailed>(),
      );
      expect(
        await answer(429, {
          'error': 'quota_exceeded',
          'limit': 'project',
          'retryAfterSeconds': 3600,
        }),
        isA<RecipeImageDeferred>().having(
          (r) => r.retryAfter,
          'retryAfter',
          const Duration(hours: 1),
        ),
      );
      expect(
        await answer(429, {'error': 'rate_limited', 'retryAfterSeconds': 60}),
        isA<RecipeImageDeferred>(),
      );
      expect(
        await answer(503, {'error': 'disabled'}),
        isA<RecipeImageDisabled>(),
      );
      expect(await answer(401, null), isA<RecipeImageUnauthorized>());
      expect(
        await answer(403, {'error': 'forbidden'}),
        isA<RecipeImageUnauthorized>(),
      );
      expect(
        await answer(400, {'error': 'bad_request'}),
        isA<RecipeImageRejected>(),
      );
      expect(
        await answer(502, {'error': 'provider_error'}),
        isA<RecipeImageFailed>(),
      );
      expect(await answer(504, {'error': 'timeout'}), isA<RecipeImageFailed>());
    });

    test('a 401 refreshes the session and retries exactly once', () async {
      var calls = 0;
      var refreshes = 0;
      final client = RecipeImageClient(
        (_) async {
          calls++;
          return calls == 1
              ? const FunctionResponse(status: 401)
              : const FunctionResponse(status: 200, data: {'file': file});
        },
        refresh: () async {
          refreshes++;
          return true;
        },
      );
      expect(await client.generate('r1', _zeljanica), isA<RecipeImageReady>());
      expect((calls, refreshes), (2, 1));

      calls = 0;
      final denied = RecipeImageClient((_) async {
        calls++;
        return const FunctionResponse(status: 401);
      }, refresh: () async => true);
      expect(
        await denied.generate('r1', _zeljanica),
        isA<RecipeImageUnauthorized>(),
      );
      expect(calls, 2);
    });

    test('a network error is offline, not a provider failure', () async {
      final result = await RecipeImageClient(
        (_) async => throw Exception('socket'),
      ).generate('r1', _zeljanica);
      expect(result, isA<RecipeImageOffline>());
    });

    test('maps function exceptions by status', () async {
      final result = await RecipeImageClient(
        (_) async => throw const FunctionException(
          status: 429,
          details: {'error': 'quota_exceeded', 'retryAfterSeconds': 10},
        ),
      ).generate('r1', _zeljanica);
      expect(result, isA<RecipeImageDeferred>());
    });
  });
}
