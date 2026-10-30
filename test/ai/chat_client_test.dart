import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_errors.dart';
import 'package:tavli/ai/ai_models.dart';
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
    expect(
      await statusError(400, '{"error":"bad param"}'),
      isA<BadRequestError>(),
    );
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

  test('podrazumevano čekanje odgovora je 60 s', () {
    expect(
      OpenAICompatibleClient.defaultReceiveTimeout,
      const Duration(seconds: 60),
    );
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
