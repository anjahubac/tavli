import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:tavli/ai/ai_errors.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/ai_router.dart';
import 'package:tavli/ai/chain_config.dart';
import 'package:tavli/ai/gateway_chat_client.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/ai/model_status_store.dart';

import 'ai_router_test.dart' show FakeClient, okJson, parseValue;

const _free = 'gemini/gemini-pro-latest';
const _paid = 'openai/default';
const _request = AIRequest(
  task: AITask.recipeFromName,
  system: 'Return JSON',
  prompt: 'Beans',
);

const _models = FunctionResponse(
  status: 200,
  data: {
    'text': [_paid, 'unknown/model', _free],
    'vision': [_paid, _free],
  },
);

FunctionResponse _completion(
  Map<String, Object?>? body, [
  String raw = okJson,
]) => FunctionResponse(
  status: 200,
  data: {'model': body?['model'], 'content': raw},
);

AIRouter _router(
  GatewayChatClient gateway, {
  FakeClient? direct,
  KeyStore? keys,
}) => AIRouter(
  config: () => ChainConfig.defaults,
  client: direct ?? FakeClient(),
  keys: OwnKeySource(keys ?? InMemoryKeyStore()),
  status: InMemoryModelStatusStore(),
  gateway: gateway,
);

void main() {
  test('Supabase adapter sends the session token to the function', () async {
    final expiration = DateTime.now().add(const Duration(hours: 1));
    final claims = base64Url.encode(
      utf8.encode(
        jsonEncode({'exp': expiration.millisecondsSinceEpoch ~/ 1000}),
      ),
    );
    final token = 'e30.$claims.synthetic';
    final calls = <String>[];
    final supabase = SupabaseClient(
      'https://supabase.invalid',
      'fake-public-key',
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://supabase.invalid/functions/v1/ai-gateway',
        );
        expect(request.headers['authorization'], 'Bearer $token');
        calls.add(request.method);
        final body = request.method == 'GET'
            ? {
                'text': [_free],
                'vision': [_free],
              }
            : {'content': okJson, 'model': _free};
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(supabase.dispose);
    await supabase.auth.recoverSession(
      jsonEncode({
        'access_token': token,
        'refresh_token': 'synthetic-refresh',
        'token_type': 'bearer',
        'user': {
          'id': 'synthetic-account',
          'app_metadata': <String, Object?>{},
          'user_metadata': <String, Object?>{},
        },
      }),
    );
    final client = GatewayChatClient.supabase(
      supabase,
      refresh: () async => false,
    );
    final result = await _router(client).run(_request, parseValue);
    expect(result.value, 'ok');
    expect(calls, ['GET', 'POST']);
  });

  test('completion encodes the task ID for every Tavli AI task', () async {
    final bodies = <Map<String, Object?>>[];
    final client = GatewayChatClient(
      accountId: () => 'account',
      refresh: () async => false,
      invoke: (method, body) async {
        expect(method, HttpMethod.post);
        bodies.add(body!);
        return _completion(body);
      },
    );
    for (final task in AITask.values) {
      final vision =
          task == AITask.recipeFromImage || task == AITask.pantryFromPhoto;
      final request = AIRequest(
        task: task,
        system: 'Return JSON',
        prompt: 'Beans',
        images: [
          if (vision) AIImage(Uint8List.fromList([1, 2, 3])),
        ],
      );
      await client.complete(
        ChainConfig.gatewayModels(request.kind)[_free]!,
        request,
      );
    }
    expect(bodies.map((body) => body['task']), [
      'recipe_from_image',
      'recipe_from_name',
      'recipe_refine',
      'plan_outline',
      'recipe_summaries',
      'recipe_image_description',
      'pantry_from_photo',
      'voice_draft_actions',
    ]);
    final withImages = {
      for (final body in bodies)
        if (body.containsKey('images')) body['task'],
    };
    expect(withImages, {'recipe_from_image', 'pantry_from_photo'});
    expect(bodies.first['images'], ['data:image/jpeg;base64,AQID']);
    expect(bodies.every((body) => !body.containsKey('apiKey')), isTrue);
  });

  test(
    'router honors shared ordering, falls back and keeps task on repair',
    () async {
      final posted = <Map<String, Object?>>[];
      final client = GatewayChatClient(
        accountId: () => 'account',
        refresh: () async => false,
        invoke: (method, body) async {
          if (method == HttpMethod.get) return _models;
          posted.add(body!);
          return switch (posted.length) {
            1 => const FunctionResponse(
              status: 429,
              data: {'error': 'provider_rate_limited'},
            ),
            2 => _completion(body, '{}'),
            _ => _completion(body),
          };
        },
      );
      final result = await _router(client).run(_request, parseValue);
      expect(result.origin, KeyOrigin.builtIn);
      expect(result.value, 'ok');
      expect(posted.map((body) => body['model']), [_paid, _free, _free]);
      expect(posted.map((body) => body['task']).toSet(), {'recipe_from_name'});
    },
  );

  test('personal key succeeds before any shared lookup', () async {
    final client = GatewayChatClient(
      accountId: () => 'account',
      refresh: () async => false,
      invoke: (_, _) async => throw StateError('unexpected gateway call'),
    );
    final direct = FakeClient()
      ..script(ChainConfig.defaults.text.first, [okJson]);
    final keys = InMemoryKeyStore({AIProvider.gemini: 'fake-personal'});
    final result = await _router(
      client,
      direct: direct,
      keys: keys,
    ).run(_request, parseValue);
    expect(result.origin, KeyOrigin.user);
    expect(direct.keysUsed, ['fake-personal']);
  });

  test('401 refresh budget is shared by discovery and completion', () async {
    var requests = 0;
    var refreshes = 0;
    final client = GatewayChatClient(
      accountId: () => 'account',
      refresh: () async {
        refreshes++;
        return true;
      },
      invoke: (method, _) async {
        requests++;
        if (requests == 2 && method == HttpMethod.get) return _models;
        throw const FunctionException(
          status: 401,
          details: 'opaque platform error',
        );
      },
    );
    await expectLater(
      _router(client).run(_request, parseValue),
      throwsA(isA<GatewayAuthError>()),
    );
    expect(requests, 3);
    expect(refreshes, 1);
  });

  test('switching accounts during refresh prevents replay', () async {
    var account = 'before';
    var requests = 0;
    final client = GatewayChatClient(
      accountId: () => account,
      refresh: () async {
        account = 'after';
        return true;
      },
      invoke: (_, _) async {
        requests++;
        throw const FunctionException(status: 401);
      },
    );
    await expectLater(
      _router(client).run(_request, parseValue),
      throwsA(isA<AICancelled>()),
    );
    expect(requests, 1);
  });

  test(
    'daily shared quota stops fallback and is scoped by account and kind',
    () async {
      var account = 'first';
      final posted = <Object?>[];
      final client = GatewayChatClient(
        accountId: () => account,
        refresh: () async => false,
        invoke: (method, body) async {
          if (method == HttpMethod.get) return _models;
          posted.add(body?['task']);
          if (posted.length > 1) return _completion(body);
          return const FunctionResponse(
            status: 429,
            data: {
              'error': 'quota_exceeded',
              'limit': 'daily',
              'kind': 'text',
              'retryAfterSeconds': 60,
            },
          );
        },
      );
      final router = _router(client);
      await expectLater(
        router.run(_request, parseValue),
        throwsA(isA<GatewayQuotaError>()),
      );
      await expectLater(
        router.run(_request, parseValue),
        throwsA(isA<GatewayQuotaError>()),
      );
      expect(posted, ['recipe_from_name']);
      await router.run(
        AIRequest(
          task: AITask.recipeFromImage,
          system: 'Return JSON',
          prompt: 'Read photo',
          images: [
            AIImage(Uint8List.fromList([1])),
          ],
        ),
        parseValue,
      );
      account = 'second';
      await router.run(_request, parseValue);
      expect(posted, [
        'recipe_from_name',
        'recipe_from_image',
        'recipe_from_name',
      ]);
    },
  );
}
