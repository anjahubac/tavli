import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_errors.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/chain_config.dart';
import 'package:tavli/ai/chat_client.dart';

import '../helpers/fake_adapter.dart';

const model = ModelSpec(
  provider: AIProvider.groq,
  model: 'test-model',
  label: 'Test',
);
const request = AIRequest(system: 's', prompt: 'p');

(OpenAICompatibleClient, FakeAdapter) clientWith(
  List<(int, String, Map<String, List<String>>)> responses,
) {
  final adapter = FakeAdapter(responses);
  final dio = Dio()..httpClientAdapter = adapter;
  return (
    OpenAICompatibleClient(dio: dio, transientRetryDelay: Duration.zero),
    adapter,
  );
}

String completion(String content) => jsonEncode({
  'choices': [
    {
      'message': {'content': content},
    },
  ],
});

void main() {
  test('šalje OpenAI-kompatibilan zahtev i vraća sadržaj', () async {
    final (client, adapter) = clientWith([(200, completion('{"a":1}'), {})]);

    final out = await client.complete(model, request, apiKey: 'k');

    expect(out, '{"a":1}');
    final req = adapter.requests.single;
    expect(
      req.uri.toString(),
      'https://api.groq.com/openai/v1/chat/completions',
    );
    expect(req.headers['Authorization'], 'Bearer k');
    expect((req.data as Map)['response_format'], {'type': 'json_object'});
    expect(req.data, containsPair('temperature', request.temperature));
    expect((req.data as Map).containsKey('reasoning_effort'), isFalse);
  });

  test('OpenAI: adresa, Bearer ključ i JSON odgovor', () async {
    final (client, adapter) = clientWith([(200, completion('{"a":1}'), {})]);
    final openAI = ChainConfig.defaults.text.last;

    await client.complete(openAI, request, apiKey: 'sk-fake');

    final req = adapter.requests.single;
    expect(req.uri.toString(), 'https://api.openai.com/v1/chat/completions');
    expect(req.headers['Authorization'], 'Bearer sk-fake');
    expect(req.data, containsPair('model', 'gpt-6-luna'));
    expect((req.data as Map).containsKey('temperature'), isFalse);
    expect(req.data, containsPair('reasoning_effort', 'none'));
    expect(req.data, containsPair('response_format', {'type': 'json_object'}));
  });

  test('429 sa Retry-After i dnevnim limitom', () async {
    final (client, _) = clientWith([
      (
        429,
        '{"error":{"message":"Rate limit reached on tokens per day"}}',
        {
          'retry-after': ['120'],
        },
      ),
    ]);

    final e = await client
        .complete(model, request, apiKey: 'k')
        .then<Object>((_) => 'ok', onError: (Object e) => e);

    expect(e, isA<RateLimitError>());
    final rl = e as RateLimitError;
    expect(rl.retryAfter, const Duration(seconds: 120));
    expect(rl.isDaily, isTrue);
  });

  test('Gemini retryDelay iz tela odgovora', () {
    expect(
      parseRetryAfter(null, '"retryDelay": "34s"'),
      const Duration(seconds: 34),
    );
    expect(
      looksLikeDailyLimit('GenerateRequestsPerDayPerProjectPerModel'),
      isTrue,
    );
  });

  test('statusi se mapiraju na prave greške', () async {
    Future<Object> statusError(int status, String body) async {
      final (client, _) = clientWith([(status, body, {})]);
      return client
          .complete(model, request, apiKey: 'k')
          .then<Object>((_) => 'ok', onError: (Object e) => e);
    }

    expect(await statusError(401, '{}'), isA<AuthError>());
    expect(
      await statusError(400, '{"error":"API key not valid"}'),
      isA<AuthError>(),
    );
    expect(await statusError(404, '{}'), isA<ModelNotFoundError>());
    expect(await statusError(403, '{}'), isA<AuthError>());
    // OpenAI: ključ je ispravan, projekat nema pristup modelu.
    expect(
      await statusError(403, '{"error":{"code":"model_not_found"}}'),
      isA<ModelNotFoundError>(),
    );
    expect(
      await statusError(400, '{"error":"bad param"}'),
      isA<BadRequestError>(),
    );
  });

  // SEC-03: telo odgovora provajdera može da nosi deo prompta, ključa ili
  // naloga; poruka greške ide u UI i u zapis pokušaja, pa sadrži samo status.
  test('poruka greške ne sadrži telo odgovora provajdera', () async {
    const sentinel = 'SENTINEL-sk-test-0123456789';
    Future<AIError> statusError(int status, String body) async {
      final (client, _) = clientWith([(status, body, {}), (status, body, {})]);
      return client
          .complete(model, request, apiKey: 'k')
          .then<AIError>(
            (_) => throw StateError('expected an error'),
            onError: (Object e) => e as AIError,
          );
    }

    for (final (status, body) in [
      (400, '{"error":"bad param $sentinel"}'),
      (400, '{"error":"API key not valid $sentinel"}'),
      (401, '{"error":"$sentinel"}'),
      (403, '{"error":{"code":"model_not_found","m":"$sentinel"}}'),
      (404, '{"error":"$sentinel"}'),
      (429, '{"error":"$sentinel"}'),
      (500, '{"error":"$sentinel"}'),
    ]) {
      final error = await statusError(status, body);
      expect(error.message, isNot(contains(sentinel)), reason: '$status');
      expect(error.toString(), isNot(contains(sentinel)), reason: '$status');
      expect(error.message, contains('HTTP $status'), reason: '$status');
    }
  });

  test('5xx: jedan ponovni pokušaj pa uspeh', () async {
    final (client, adapter) = clientWith([
      (503, '{}', {}),
      (200, completion('{"ok":true}'), {}),
    ]);

    expect(await client.complete(model, request, apiKey: 'k'), '{"ok":true}');
    expect(adapter.requests, hasLength(2));
  });

  test('prazan odgovor je InvalidOutputError', () async {
    final (client, _) = clientWith([(200, completion('  '), {})]);

    await expectLater(
      client.complete(model, request, apiKey: 'k'),
      throwsA(isA<InvalidOutputError>()),
    );
  });

  test('isteklo vreme: bez ponovnog pokušaja, odmah sledeći model', () async {
    final adapter = _TimeoutAdapter();
    final client = OpenAICompatibleClient(
      dio: Dio()..httpClientAdapter = adapter,
      transientRetryDelay: Duration.zero,
    );

    await expectLater(
      client.complete(model, request, apiKey: 'k'),
      throwsA(
        isA<TransientError>().having((e) => e.isTimeout, 'isTimeout', true),
      ),
    );
    expect(adapter.calls, 1);
  });

  test('čekanje odgovora zavisi od modela', () async {
    final (client, adapter) = clientWith([
      (200, completion('{"ok":true}'), {}),
      (200, completion('{"ok":true}'), {}),
    ]);
    await client.complete(model, request, apiKey: 'k');
    await client.complete(
      const ModelSpec(
        provider: AIProvider.gemini,
        model: 'pro',
        label: 'Pro',
        timeout: Duration(seconds: 60),
      ),
      request,
      apiKey: 'k',
    );
    expect(adapter.requests[0].receiveTimeout, const Duration(seconds: 30));
    expect(adapter.requests[1].receiveTimeout, const Duration(seconds: 60));
  });
}

class _TimeoutAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    throw DioException.receiveTimeout(
      timeout: const Duration(seconds: 60),
      requestOptions: options,
    );
  }

  @override
  void close({bool force = false}) {}
}
