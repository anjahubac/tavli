import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:tavli/ai/ai_errors.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/ai_router.dart';
import 'package:tavli/ai/chain_config.dart';
import 'package:tavli/ai/chat_client.dart';
import 'package:tavli/ai/gateway_chat_client.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/ai/model_status_store.dart';
import 'package:tavli/ai/repair_prompt.dart';

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

const openAI = ModelSpec(
  provider: AIProvider.openAI,
  model: 'paid',
  label: 'OpenAI',
  supportsVision: true,
);
const configWithPaid = ChainConfig(
  vision: [geminiPro, groqVision, geminiFlash, openAI],
  text: [geminiPro, groqText, geminiFlash, openAI],
);

/// Za svaki model vraća unapred zadate odgovore (String ili AIError).
class FakeClient implements ChatClient {
  final scripts = <String, List<Object>>{};
  final calls = <String>[];
  final keysUsed = <String>[];
  final requests = <AIRequest>[];

  /// Poziva se kad model „odgovori“, npr. da test pritisne „Prekini“.
  void Function()? onAnswer;

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
    requests.add(request);
    final queue = scripts[model.key];
    if (queue == null || queue.isEmpty) {
      throw StateError('Nema odgovora za ${model.key}');
    }
    final next = queue.removeAt(0);
    onAnswer?.call();
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

  AIRouter makeRouter({
    GatewayChatClient? gateway,
    FutureOr<OwnKeyOrder> Function()? order,
    ChainConfig Function()? chain,
  }) => order == null
      ? AIRouter(
          config: chain ?? () => config,
          client: client,
          keys: OwnKeySource(keys),
          status: status,
          gateway: gateway,
          clock: () => now,
        )
      : AIRouter(
          config: chain ?? () => config,
          client: client,
          keys: OwnKeySource(keys),
          status: status,
          gateway: gateway,
          ownKeyOrder: order,
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

  test('limit na prvom sopstvenom ključu -> isti model sa drugim', () async {
    await keys.add(AIProvider.gemini, 'g-key-2');
    client.script(geminiPro, [const RateLimitError('limit'), okJson, okJson]);

    final r = await router.run(textRequest, parseValue);
    expect(r.model, geminiPro);
    expect(client.keysUsed, ['g-key', 'g-key-2']);

    // Prvi ključ je pauziran, drugi se koristi direktno.
    await router.run(textRequest, parseValue);
    expect(client.keysUsed, ['g-key', 'g-key-2', 'g-key-2']);
  });

  test('odbijen jedan sopstveni ključ ne gasi ostale', () async {
    final second = await keys.add(AIProvider.gemini, 'g-key-2');
    client.script(geminiPro, [const AuthError('bad'), okJson]);

    final r = await router.run(textRequest, parseValue);

    expect(r.model, geminiPro);
    expect(router.invalidKeyIds, {'gemini'});
    expect(router.invalidKeyIds, isNot(contains(second.id)));
  });

  test('dnevni limit pauzira Gemini do resetovanja u 08:00 UTC', () async {
    client.script(geminiPro, [const RateLimitError('day', isDaily: true)]);
    client.script(groqText, [okJson]);

    await router.run(textRequest, parseValue);

    final until = await status.blockedUntil(geminiPro, keyId: 'gemini');
    expect(until!.toUtc(), DateTime.utc(2026, 10, 30, 8));
  });

  test('minutni limit bez Retry-After pauzira 60 sekundi', () async {
    client.script(geminiPro, [const RateLimitError('rpm')]);
    client.script(groqText, [okJson]);

    await router.run(textRequest, parseValue);

    expect(
      await status.blockedUntil(geminiPro, keyId: 'gemini'),
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
    expect(router.invalidKeyIds, {'gemini'});

    router.resetKey('gemini');
    client.script(geminiPro, [okJson]);
    expect((await router.run(textRequest, parseValue)).model, geminiPro);
  });

  test('provajder bez ključa se tiho preskače', () async {
    await keys.remove('gemini');
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

  test('neispravan JSON: jedna popravka na istom modelu', () async {
    client.script(geminiPro, ['ovo nije json', '```json\n$okJson\n```']);

    final r = await router.run(visionRequest, parseValue);

    expect(r.model, geminiPro);
    expect(client.calls, ['gemini/pro', 'gemini/pro']);
    final repair = client.requests.last;
    expect(repair.system, visionRequest.system);
    expect(repair.prompt, startsWith(visionRequest.prompt));
    expect(repair.prompt, contains('Your previous answer:\novo nije json'));
    expect(repair.prompt, contains('Problem: '));
    expect(repair.images, visionRequest.images, reason: 'ista slika');
    expect(status.requestsOn(geminiPro, now, keyId: 'gemini'), 2);
  });

  test('popravka dobija opis pravila iz ugovora, ne samo oznaku', () async {
    client.script(geminiPro, ['{"x": 1}', okJson]);

    await router.run(
      textRequest,
      (json) => json.containsKey('x')
          ? throw const FormatException('R6')
          : parseValue(json),
    );

    expect(
      client.requests.last.prompt,
      contains('Problem: every "quantity" must be a number'),
    );
  });

  test('pogrešan tip polja se popravlja kao i loš JSON', () async {
    client.script(geminiPro, ['{"value": 1}', okJson]);

    final r = await router.run(textRequest, (json) => json['value'] as String);

    expect(r.value, 'ok');
    expect(client.requests.last.prompt, contains('wrong type'));
  });

  test('predugačak odgovor se ne vraća modelu, samo opis greške', () async {
    final huge = '{"x": "${'a' * 13000}"}';
    client.script(geminiPro, [huge, okJson]);

    await router.run(textRequest, parseValue);

    expect(client.requests.last.prompt, isNot(contains('previous answer:')));
    expect(client.requests.last.prompt, contains('Problem: nema value'));
  });

  test('neuspela popravka zaustavlja lanac, bez ostalih modela', () async {
    client.script(geminiPro, ['{"x": 1}', '{"x": 2}']);
    client.script(groqText, [okJson]);
    // Pauziran model ne sme da pretvori poruku u „limiti su potrošeni“.
    await status.block(
      geminiFlash,
      now.add(const Duration(hours: 1)),
      'x',
      keyId: 'gemini',
    );

    await expectLater(
      router.run(textRequest, parseValue),
      throwsA(
        isA<AllModelsExhausted>()
            .having((e) => e.invalidOutput, 'invalidOutput', isTrue)
            .having((e) => e.nextAvailableAt, 'nextAvailableAt', isNull),
      ),
    );
    expect(client.calls, ['gemini/pro', 'gemini/pro']);
  });

  test('Pokušaj ponovo posle neuspele popravke pita sledeći model', () async {
    client.script(geminiPro, ['{"x": 1}', '{"x": 2}', okJson]);
    client.script(groqText, [okJson]);
    await expectLater(
      router.run(textRequest, parseValue),
      throwsA(isA<AllModelsExhausted>()),
    );

    final again = await router.run(textRequest, parseValue);
    expect(again.model, groqText);
    expect(
      again.attempts.first.outcome,
      startsWith('preskočen: neispravan odgovor'),
    );

    // Posle pauze model se ponovo pita.
    now = now.add(const Duration(minutes: 11));
    final later = await router.run(textRequest, parseValue);
    expect(later.model, geminiPro);
  });

  test('svi modeli preskočeni zbog lošeg odgovora -> označeno', () async {
    for (final m in [geminiPro, groqText, geminiFlash]) {
      client.script(m, ['{"x": 1}', '{"x": 2}']);
      await expectLater(
        router.run(textRequest, parseValue),
        throwsA(isA<AllModelsExhausted>()),
      );
    }

    await expectLater(
      router.run(textRequest, parseValue),
      throwsA(
        isA<AllModelsExhausted>().having(
          (e) => e.invalidOutput,
          'invalidOutput',
          isTrue,
        ),
      ),
    );
    expect(client.calls, hasLength(6), reason: 'četvrti put nema poziva');
  });

  test('prekid pre zahteva: nijedan poziv modela', () async {
    client.script(geminiPro, [okJson]);
    final cancel = AICancellation()..cancel();

    await expectLater(
      router.run(textRequest, parseValue, cancel: cancel),
      throwsA(isA<AICancelled>()),
    );
    expect(client.calls, isEmpty);
  });

  test('prekid dok model odgovara: nema popravke ni sledećeg modela', () async {
    client.script(geminiPro, ['{"x": 1}', okJson]);
    client.script(groqText, [okJson]);
    final cancel = AICancellation();
    client.onAnswer = cancel.cancel;

    await expectLater(
      router.run(textRequest, parseValue, cancel: cancel),
      throwsA(isA<AICancelled>()),
    );
    expect(client.calls, ['gemini/pro'], reason: 'popravka nije poslata');
  });

  test(
    'neuspela popravka sa slobodnim modelom: Pokušaj ponovo radi odmah',
    () async {
      client.script(geminiPro, ['{"x": 1}', '{"x": 2}']);

      await expectLater(
        router.run(textRequest, parseValue),
        throwsA(
          isA<AllModelsExhausted>()
              .having((e) => e.repairFailed, 'repairFailed', isTrue)
              .having((e) => e.nextAvailableAt, 'nextAvailableAt', isNull),
        ),
      );
    },
  );

  test('neuspela popravka kad su ostali pauzirani: javlja kada', () async {
    final groqFree = now.add(const Duration(minutes: 3));
    await status.block(groqText, groqFree, 'limit', keyId: 'groq');
    await status.block(
      geminiFlash,
      now.add(const Duration(hours: 2)),
      'x',
      keyId: 'gemini',
    );
    client.script(geminiPro, ['{"x": 1}', '{"x": 2}']);

    await expectLater(
      router.run(textRequest, parseValue),
      throwsA(
        isA<AllModelsExhausted>()
            .having((e) => e.repairFailed, 'repairFailed', isTrue)
            .having((e) => e.nextAvailableAt, 'nextAvailableAt', groqFree),
      ),
    );
  });

  test('svi modeli vrate prazan odgovor -> označeno kao prazan', () async {
    for (final m in [geminiPro, groqText, geminiFlash]) {
      client.script(m, [const InvalidOutputError('Prazan odgovor modela')]);
    }

    await expectLater(
      router.run(textRequest, parseValue),
      throwsA(
        isA<AllModelsExhausted>()
            .having((e) => e.emptyOutput, 'emptyOutput', isTrue)
            .having((e) => e.repairFailed, 'repairFailed', isFalse)
            .having((e) => e.invalidOutput, 'invalidOutput', isFalse),
      ),
    );
  });

  test(
    'zahtev za popravku staje u granicu servera od 40 000 znakova',
    () async {
      final big = AIRequest(system: 's' * 2000, prompt: 'p' * 33000);
      final answer = '{"x": "${'a' * 9000}"}';
      client.script(geminiPro, [answer, okJson]);

      await router.run(big, parseValue);

      final repair = client.requests.last;
      expect(
        repair.system.length + repair.prompt.length,
        lessThanOrEqualTo(maxRequestChars),
      );
      expect(repair.prompt, isNot(contains('previous answer:')));
      expect(repair.prompt, contains('Problem: nema value'));
    },
  );

  test('prazan odgovor ide na sledeći model, bez popravke', () async {
    client.script(geminiPro, [const InvalidOutputError('Prazan odgovor')]);
    client.script(groqText, [okJson]);

    final r = await router.run(textRequest, parseValue);

    expect(r.model, groqText);
    expect(client.calls, ['gemini/pro', 'groq/text']);
  });

  test('mreža pukne tokom popravke -> sledeći model', () async {
    client.script(geminiPro, ['{"x": 1}', const TransientError('timeout')]);
    client.script(groqText, [okJson]);

    final r = await router.run(textRequest, parseValue);

    expect(r.model, groqText);
    expect(client.calls, ['gemini/pro', 'gemini/pro', 'groq/text']);
  });

  test('bez ijednog odgovora nije označeno kao neispravan odgovor', () async {
    client.script(geminiPro, [const AuthError('bad key')]);
    client.script(groqText, [const AuthError('bad key')]);
    client.script(geminiFlash, [const AuthError('bad key')]);

    await expectLater(
      router.run(textRequest, parseValue),
      throwsA(
        isA<AllModelsExhausted>().having(
          (e) => e.invalidOutput,
          'invalidOutput',
          isFalse,
        ),
      ),
    );
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

    expect(status.requestsOn(geminiPro, now, keyId: 'gemini'), 2);
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
      'Groq Qwen 3.6 27B',
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

  group('zajednički pristup (gateway)', () {
    const gatewayId = 'gemini/gemini-pro-latest';
    const taskRequest = AIRequest(
      task: AITask.recipeFromName,
      system: 'Return JSON',
      prompt: 'p',
    );
    final shared = ChainConfig.gatewayModels(TaskKind.text)[gatewayId]!;
    late List<Object?> posted;
    late List<Object> answers;

    setUp(() async {
      posted = [];
      answers = [];
      await keys.remove('groq');
      client.script(geminiFlash, []);
      router = makeRouter(
        gateway: GatewayChatClient(
          accountId: () => 'account',
          refresh: () async => false,
          invoke: (method, body) async {
            if (method == HttpMethod.get) {
              return const FunctionResponse(
                status: 200,
                data: {
                  'text': [gatewayId],
                },
              );
            }
            posted.add(body?['model']);
            final next = answers.isEmpty ? okJson : answers.removeAt(0);
            if (next is FunctionResponse) return next;
            return FunctionResponse(
              status: 200,
              data: {'model': body?['model'], 'content': next},
            );
          },
        ),
      );
    });

    test(
      'limit na sopstvenom -> gateway, a pauzira se samo sopstveni',
      () async {
        client
          ..script(geminiPro, [const RateLimitError('limit')])
          ..script(geminiFlash, [const RateLimitError('limit')]);

        final r = await router.run(taskRequest, parseValue);

        expect(r.origin, KeyOrigin.builtIn);
        expect(posted, [gatewayId]);
        expect(
          await status.blockedUntil(geminiPro, keyId: 'gemini'),
          isNotNull,
        );
        expect(
          await status.blockedUntil(shared, origin: KeyOrigin.builtIn),
          isNull,
        );
      },
    );

    test('pauza gateway modela ne utiče na sopstveni ključ', () async {
      await status.block(
        geminiPro,
        now.add(const Duration(hours: 1)),
        'limit',
        origin: KeyOrigin.builtIn,
      );
      client.script(geminiPro, [okJson]);

      final r = await router.run(taskRequest, parseValue);

      expect(r.origin, KeyOrigin.user);
      expect(posted, isEmpty);
    });

    test('odbijen sopstveni ključ: gateway radi, UI traži novi', () async {
      client.script(geminiPro, [const AuthError('bad')]);

      final r = await router.run(taskRequest, parseValue);

      expect(r.origin, KeyOrigin.builtIn);
      expect(router.invalidKeyIds, {'gemini'});
    });

    test('nextAvailableAt gleda i gateway pauzu', () async {
      client
        ..script(geminiPro, [
          const RateLimitError('l', retryAfter: Duration(minutes: 5)),
        ])
        ..script(geminiFlash, [
          const RateLimitError('l', retryAfter: Duration(minutes: 10)),
        ]);
      answers = [
        const FunctionResponse(
          status: 429,
          data: {'error': 'provider_rate_limited', 'retryAfterSeconds': 120},
        ),
      ];

      await expectLater(
        router.run(taskRequest, parseValue),
        throwsA(
          isA<AllModelsExhausted>().having(
            (e) => e.nextAvailableAt,
            'nextAvailableAt',
            now.add(const Duration(minutes: 2)),
          ),
        ),
      );
    });

    test('plaćeni i besplatni sopstveni ključevi idu pre gateway-a', () async {
      await keys.add(AIProvider.openAI, 'o-key');
      for (final order in OwnKeyOrder.values) {
        client.calls.clear();
        client
          ..script(openAI, [const TransientError('x')])
          ..script(geminiPro, [const TransientError('x')])
          ..script(geminiFlash, [const TransientError('x')]);
        router = makeRouter(
          gateway: router.gateway,
          order: () => order,
          chain: () => configWithPaid,
        );

        final r = await router.run(taskRequest, parseValue);

        expect(client.calls, hasLength(3), reason: order.name);
        expect(r.origin, KeyOrigin.builtIn);
      }
    });
  });

  group('redosled sopstvenih ključeva', () {
    setUp(() => keys.add(AIProvider.openAI, 'o-key'));

    Future<AIResult<String>> runWith(FutureOr<OwnKeyOrder> Function()? order) {
      client
        ..script(openAI, [const TransientError('x')])
        ..script(geminiPro, [const TransientError('x')])
        ..script(groqText, [const TransientError('x')])
        ..script(geminiFlash, [okJson, okJson]);
      router = makeRouter(order: order, chain: () => configWithPaid);
      return router.run(textRequest, parseValue);
    }

    test('podrazumevano: prvo plaćeni, ostali istim redom', () async {
      final r = await runWith(null);

      expect(r.attempts.map((a) => a.model.key), [
        'openAI/paid',
        'gemini/pro',
        'groq/text',
        'gemini/flash',
      ]);
      expect(client.keysUsed, ['o-key', 'g-key', 'q-key', 'g-key']);
    });

    test(
      'prvo besplatni: plaćeni je poslednji i ne zove se bez potrebe',
      () async {
        final r = await runWith(() => OwnKeyOrder.freeFirst);

        expect(r.model, geminiFlash);
        expect(client.calls, ['gemini/pro', 'groq/text', 'gemini/flash']);
      },
    );

    test('prvo besplatni: kad svi padnu, plaćeni odgovara', () async {
      client
        ..script(geminiPro, [const RateLimitError('l')])
        ..script(groqText, [const RateLimitError('l')])
        ..script(geminiFlash, [const RateLimitError('l')])
        ..script(openAI, [okJson]);
      router = makeRouter(
        order: () => OwnKeyOrder.freeFirst,
        chain: () => configWithPaid,
      );

      final r = await router.run(textRequest, parseValue);

      expect(r.model, openAI);
      expect(client.calls.last, 'openAI/paid');
    });

    test('izbor koji se još učitava važi i za prvi zahtev', () async {
      final loading = Completer<OwnKeyOrder>();
      final result = runWith(() => loading.future);
      await pumpEventQueue();
      expect(client.calls, isEmpty);

      loading.complete(OwnKeyOrder.freeFirst);

      expect((await result).model, geminiFlash);
      expect(client.calls, isNot(contains('openAI/paid')));
    });

    test('promena redosleda važi za sledeći zahtev', () async {
      var order = OwnKeyOrder.freeFirst;
      await runWith(() => order);
      order = OwnKeyOrder.paidFirst;
      client.calls.clear();
      client.script(openAI, [okJson]);

      final r = await router.run(textRequest, parseValue);

      expect(r.model, openAI);
    });
  });

  group('OpenAI model za sopstveni ključ', () {
    test('na kraju je oba lanca i čita slike', () {
      for (final kind in TaskKind.values) {
        final last = ChainConfig.defaults.chainFor(kind).last;
        expect(last.key, 'openAI/gpt-4o-mini');
        expect(last.supportsVision, isTrue);
      }
    });

    test('gateway i dalje zna samo openai/default', () {
      for (final kind in TaskKind.values) {
        final models = ChainConfig.gatewayModels(kind);
        expect(models['openai/default']?.model, 'default');
        expect(models.keys.where((id) => id.startsWith('openai/')), [
          'openai/default',
        ]);
      }
    });
  });
}
