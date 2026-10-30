import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_errors.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/ai_router.dart';
import 'package:tavli/ai/chain_config.dart';
import 'package:tavli/ai/chat_client.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/ai/model_status_store.dart';

const geminiPro = ModelSpec(
  provider: AIProvider.gemini,
  model: 'pro',
  label: 'Gemini Pro',
  supportsVision: true,
  dailyResetUtcHour: 8,
);
const groqText = ModelSpec(
  provider: AIProvider.groq,
  model: 'text',
  label: 'Groq text',
);
const groqVision = ModelSpec(
  provider: AIProvider.groq,
  model: 'vision',
  label: 'Groq vision',
  supportsVision: true,
);
const geminiFlash = ModelSpec(
  provider: AIProvider.gemini,
  model: 'flash',
  label: 'Gemini Flash',
  supportsVision: true,
  dailyResetUtcHour: 8,
);

const config = ChainConfig(
  vision: [geminiPro, groqVision, geminiFlash],
  text: [geminiPro, groqText, geminiFlash],
);

/// Za svaki model vraća unapred zadate odgovore (String ili AIError).
class FakeClient implements ChatClient {
  final scripts = <String, List<Object>>{};
  final calls = <String>[];
  final keysUsed = <String>[];

  void script(ModelSpec m, List<Object> responses) =>
      scripts[m.key] = [...responses];

  @override
  Future<String> complete(
    ModelSpec model,
    AIRequest request, {
    required String apiKey,
  }) async {
    calls.add(model.key);
    keysUsed.add(apiKey);
    final queue = scripts[model.key];
    if (queue == null || queue.isEmpty) {
      throw StateError('Nema odgovora za ${model.key}');
    }
    final next = queue.removeAt(0);
    if (next is AIError) throw next;
    return next as String;
  }
}

const okJson = '{"value": "ok"}';
const textRequest = AIRequest(system: 's', prompt: 'p');
final visionRequest = AIRequest(
  system: 's',
  prompt: 'p',
  images: [
    AIImage(Uint8List.fromList([1, 2, 3])),
  ],
);

String parseValue(Map<String, dynamic> json) {
  final v = json['value'];
  if (v is! String) throw const FormatException('nema value');
  return v;
}

void main() {
  late FakeClient client;
  late InMemoryModelStatusStore status;
  late InMemoryKeyStore keys;
  late DateTime now;
  late AIRouter router;

  AIRouter makeRouter({BuiltInKeys builtIn = const BuiltInKeys()}) => AIRouter(
    config: () => config,
    client: client,
    keys: LayeredKeySource(keys, builtIn),
    status: status,
    clock: () => now,
  );

  setUp(() {
    client = FakeClient();
    status = InMemoryModelStatusStore();
    keys = InMemoryKeyStore({
      AIProvider.gemini: 'g-key',
      AIProvider.groq: 'q-key',
    });
    now = DateTime.utc(2026, 10, 29, 12);
    router = makeRouter();
  });

  test('prvi model odgovara, ostali se ne zovu', () async {
    client.script(geminiPro, [okJson]);

    final r = await router.run(textRequest, parseValue);

    expect(r.value, 'ok');
    expect(r.model, geminiPro);
    expect(client.calls, ['gemini/pro']);
  });

  test('429 na Gemini Pro -> Groq -> pa Gemini Flash', () async {
    client.script(geminiPro, [const RateLimitError('limit')]);
    client.script(groqText, [const RateLimitError('limit')]);
    client.script(geminiFlash, [okJson]);

    final r = await router.run(textRequest, parseValue);

    expect(r.model, geminiFlash);
    expect(client.calls, ['gemini/pro', 'groq/text', 'gemini/flash']);
  });

  test('pauziran model se preskače dok pauza ne istekne', () async {
    client.script(geminiPro, [
      const RateLimitError('limit', retryAfter: Duration(seconds: 30)),
      okJson,
    ]);
    client.script(groqText, [okJson, okJson]);

    await router.run(textRequest, parseValue);
    final second = await router.run(textRequest, parseValue);
    expect(second.model, groqText);
    expect(client.calls, ['gemini/pro', 'groq/text', 'groq/text']);

    now = now.add(const Duration(seconds: 31));
    final third = await router.run(textRequest, parseValue);
    expect(third.model, geminiPro);
  });

  test('dnevni limit pauzira Gemini do resetovanja u 08:00 UTC', () async {
    client.script(geminiPro, [const RateLimitError('day', isDaily: true)]);
    client.script(groqText, [okJson]);

    await router.run(textRequest, parseValue);

    final until = await status.blockedUntil(geminiPro);
    expect(until!.toUtc(), DateTime.utc(2026, 10, 30, 8));
  });

  test('minutni limit bez Retry-After pauzira 60 sekundi', () async {
    client.script(geminiPro, [const RateLimitError('rpm')]);
    client.script(groqText, [okJson]);

    await router.run(textRequest, parseValue);

    expect(
      await status.blockedUntil(geminiPro),
      now.add(const Duration(seconds: 60)),
    );
  });

  test('odbijen ključ preskače sve modele tog provajdera', () async {
    client.script(geminiPro, [const AuthError('bad key')]);
    client.script(groqText, [const TransientError('down')]);

    await expectLater(
      router.run(textRequest, parseValue),
      throwsA(isA<AllModelsExhausted>()),
    );
    // Gemini Flash se ne zove jer je Gemini ključ odbijen.
    expect(client.calls, ['gemini/pro', 'groq/text']);
    expect(router.invalidProviders, {AIProvider.gemini});

    router.resetProvider(AIProvider.gemini);
    client.script(geminiPro, [okJson]);
    expect((await router.run(textRequest, parseValue)).model, geminiPro);
  });

  test('provajder bez ključa se tiho preskače', () async {
    await keys.delete(AIProvider.gemini);
    client.script(groqText, [okJson]);

    final r = await router.run(textRequest, parseValue);

    expect(r.model, groqText);
    expect(client.calls, ['groq/text']);
  });

  test('model koji ne postoji (404) se dalje ne zove', () async {
    client.script(geminiPro, [const ModelNotFoundError('404')]);
    client.script(groqText, [okJson, okJson]);

    await router.run(textRequest, parseValue);
    await router.run(textRequest, parseValue);

    expect(client.calls, ['gemini/pro', 'groq/text', 'groq/text']);
  });

  test('neispravan JSON: jedan ponovni pokušaj na istom modelu', () async {
    client.script(geminiPro, ['ovo nije json', '```json\n$okJson\n```']);

    final r = await router.run(textRequest, parseValue);

    expect(r.model, geminiPro);
    expect(client.calls, ['gemini/pro', 'gemini/pro']);
  });

  test('dva puta neispravan JSON -> sledeći model', () async {
    client.script(geminiPro, ['{"x": 1}', '{"x": 2}']);
    client.script(groqText, [okJson]);

    final r = await router.run(textRequest, parseValue);

    expect(r.model, groqText);
    expect(client.calls, ['gemini/pro', 'gemini/pro', 'groq/text']);
  });

  test('zadatak sa slikom koristi samo lanac za slike', () async {
    client.script(geminiPro, [const RateLimitError('limit')]);
    client.script(groqVision, [okJson]);

    final r = await router.run(visionRequest, parseValue);

    expect(r.model, groqVision);
    expect(client.calls, ['gemini/pro', 'groq/vision']);
  });

  test(
    'svi potrošeni: greška javlja kada je prvi model opet dostupan',
    () async {
      client.script(geminiPro, [
        const RateLimitError('l', retryAfter: Duration(minutes: 5)),
      ]);
      client.script(groqText, [
        const RateLimitError('l', retryAfter: Duration(minutes: 2)),
      ]);
      client.script(geminiFlash, [const RateLimitError('l', isDaily: true)]);

      try {
        await router.run(textRequest, parseValue);
        fail('očekivana greška');
      } on AllModelsExhausted catch (e) {
        expect(e.nextAvailableAt, now.add(const Duration(minutes: 2)));
        expect(e.attempts, hasLength(3));
      }
    },
  );

  test('greška iz parse funkcije (npr. nije recept) prekida lanac', () async {
    client.script(geminiPro, ['{"error": "not_a_recipe"}']);

    await expectLater(
      router.run(textRequest, (json) => throw StateError('nije recept')),
      throwsStateError,
    );
    expect(client.calls, ['gemini/pro']);
  });

  test('broji zahteve po modelu', () async {
    client.script(geminiPro, ['loše', okJson]);

    await router.run(textRequest, parseValue);

    expect(status.requestsOn(geminiPro, now), 2);
  });

  test('podrazumevani lanac za slike sadrži samo modele koji vide slike', () {
    final vision = ChainConfig.defaults.chainFor(TaskKind.vision);
    expect(vision, isNotEmpty);
    expect(vision.every((m) => m.supportsVision), isTrue);
    // Brzi modeli čekaju 30 s, Pro (dugo razmišlja) 60 s.
    for (final m in vision) {
      expect(
        m.timeout,
        Duration(seconds: m.label == 'Gemini Pro' ? 60 : 30),
        reason: m.label,
      );
    }
    // Čitanje recepta sa slike: prvo brzi modeli, spori Pro tek posle njih.
    expect(vision.map((m) => m.label).take(3), [
      'Gemini Flash',
      'Groq Llama 4 Maverick',
      'Gemini Pro',
    ]);
    expect(
      ChainConfig.defaults.chainFor(TaskKind.text).first.provider,
      AIProvider.gemini,
    );
    expect(
      ChainConfig.defaults.chainFor(TaskKind.text)[1].provider,
      AIProvider.groq,
    );
  });

  test('ChainConfig preživljava JSON', () {
    final copy = ChainConfig.fromJson(ChainConfig.defaults.toJson());
    expect(
      copy.text.map((m) => m.key),
      ChainConfig.defaults.text.map((m) => m.key),
    );
  });

  group('ugrađeni ključ', () {
    const builtIn = BuiltInKeys({AIProvider.gemini: 'b-key'});

    test('radi bez sopstvenih ključeva', () async {
      await keys.delete(AIProvider.gemini);
      await keys.delete(AIProvider.groq);
      router = makeRouter(builtIn: builtIn);
      client.script(geminiPro, [okJson]);

      final r = await router.run(textRequest, parseValue);

      expect(r.model, geminiPro);
      expect(r.origin, KeyOrigin.builtIn);
      expect(r.attempts.last.origin, KeyOrigin.builtIn);
      expect(client.keysUsed, ['b-key']);
    });

    test('sopstveni ključ ide prvi', () async {
      router = makeRouter(builtIn: builtIn);
      client.script(geminiPro, [okJson]);

      final r = await router.run(textRequest, parseValue);

      expect(r.origin, KeyOrigin.user);
      expect(client.keysUsed, ['g-key']);
    });

    test('limit na sopstvenom -> isti model sa ugrađenim, pa pauza', () async {
      router = makeRouter(builtIn: builtIn);
      client.script(geminiPro, [const RateLimitError('limit'), okJson, okJson]);

      final first = await router.run(textRequest, parseValue);
      expect(first.model, geminiPro);
      expect(first.origin, KeyOrigin.builtIn);
      expect(client.keysUsed, ['g-key', 'b-key']);

      // Sopstveni ključ je pauziran, ugrađeni nije.
      await router.run(textRequest, parseValue);
      expect(client.keysUsed, ['g-key', 'b-key', 'b-key']);
      expect(await status.blockedUntil(geminiPro), isNotNull);
      expect(
        await status.blockedUntil(geminiPro, origin: KeyOrigin.builtIn),
        isNull,
      );
    });

    test('pauza ugrađenog ključa ne utiče na sopstveni', () async {
      router = makeRouter(builtIn: builtIn);
      await status.block(
        geminiPro,
        now.add(const Duration(hours: 1)),
        'limit',
        origin: KeyOrigin.builtIn,
      );
      client.script(geminiPro, [okJson]);

      final r = await router.run(textRequest, parseValue);

      expect(r.origin, KeyOrigin.user);
    });

    test(
      'odbijen sopstveni ključ: ugrađeni radi, UI traži novi ključ',
      () async {
        router = makeRouter(builtIn: builtIn);
        client.script(geminiPro, [const AuthError('bad'), okJson, okJson]);

        final r = await router.run(textRequest, parseValue);
        expect(r.origin, KeyOrigin.builtIn);
        expect(router.invalidProviders, {AIProvider.gemini});

        await router.run(textRequest, parseValue);
        expect(client.keysUsed, ['g-key', 'b-key', 'b-key']);
      },
    );

    test('odbijen ugrađeni ključ se tiho preskače', () async {
      await keys.delete(AIProvider.gemini);
      router = makeRouter(builtIn: builtIn);
      client.script(geminiPro, [const AuthError('bad')]);
      client.script(groqText, [okJson]);

      final r = await router.run(textRequest, parseValue);

      expect(r.model, groqText);
      expect(router.invalidProviders, isEmpty);
    });

    test('resetProvider briše samo stanje sopstvenog ključa', () async {
      router = makeRouter(builtIn: builtIn);
      client.script(geminiPro, [const AuthError('own'), const AuthError('b')]);
      client.script(groqText, [okJson, okJson]);
      await router.run(textRequest, parseValue);

      router.resetProvider(AIProvider.gemini);
      client.script(geminiPro, [const RateLimitError('limit')]);
      client.calls.clear();
      await router.run(textRequest, parseValue);

      // Sopstveni ključ se opet proba, ugrađeni ostaje odbijen.
      expect(client.calls, ['gemini/pro', 'groq/text']);
    });

    test('nextAvailableAt gleda pauze oba ključa', () async {
      await keys.delete(AIProvider.groq);
      router = makeRouter(builtIn: builtIn);
      client.script(geminiPro, [
        const RateLimitError('l', retryAfter: Duration(minutes: 5)),
        const RateLimitError('l', retryAfter: Duration(minutes: 2)),
      ]);
      client.script(geminiFlash, [
        const RateLimitError('l', retryAfter: Duration(minutes: 10)),
        const RateLimitError('l', retryAfter: Duration(minutes: 10)),
      ]);

      try {
        await router.run(textRequest, parseValue);
        fail('očekivana greška');
      } on AllModelsExhausted catch (e) {
        expect(e.nextAvailableAt, now.add(const Duration(minutes: 2)));
      }
    });
  });
}
