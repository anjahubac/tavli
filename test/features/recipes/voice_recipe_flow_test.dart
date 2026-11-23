import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/ai_router.dart';
import 'package:tavli/ai/chain_config.dart';
import 'package:tavli/ai/chat_client.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/ai/model_status_store.dart';
import 'package:tavli/ai/speech_transcriber.dart';
import 'package:tavli/ai/voice_agent.dart';
import 'package:tavli/features/recipes/voice_recipe_flow.dart';
import 'package:tavli/features/recipes/voice_recorder.dart';

class FakeRecorder implements VoiceRecorder {
  FakeRecorder({this.allowed = true, this.limit = const Duration(minutes: 2)});

  bool allowed;
  final Duration limit;
  bool recording = false;
  int cancels = 0;
  bool disposed = false;

  /// Zadržava `stop()` dok test ne pusti (sporo zaustavljanje snimača).
  Completer<void>? stopGate;

  @override
  Duration get maxDuration => limit;

  @override
  Future<bool> start() async {
    if (allowed) recording = true;
    return allowed;
  }

  @override
  Future<RecordedClip?> stop() async {
    await stopGate?.future;
    recording = false;
    return RecordedClip(Uint8List.fromList([1, 2, 3]), 'audio/mp4');
  }

  @override
  Future<void> cancel() async {
    recording = false;
    cancels++;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeTranscriber implements SpeechTranscriber {
  FakeTranscriber(this.answers);
  final List<Object> answers;
  int calls = 0;

  @override
  Future<String> transcribe(Uint8List audio, {required String mimeType}) async {
    calls++;
    final next = answers.removeAt(0);
    if (next is TranscriptionError) throw next;
    return next as String;
  }
}

/// Model koji odgovara redom; [gate] zadržava odgovor dok test ne pusti.
class ScriptedModel implements ChatClient {
  ScriptedModel(this.answers);
  final List<String> answers;
  final prompts = <String>[];
  Completer<void>? gate;

  @override
  Future<String> complete(
    ModelSpec model,
    AIRequest request, {
    required String apiKey,
  }) async {
    prompts.add(request.prompt);
    await gate?.future;
    if (answers.isEmpty) throw const FormatException('nema');
    return answers.removeAt(0);
  }
}

const model = ModelSpec(
  provider: AIProvider.gemini,
  model: 'flash',
  label: 'Flash',
);

/// Drugi model u lancu: „Pokušaj ponovo“ posle neuspele popravke ide na
/// njega, jer router prethodni kratko preskače.
const backup = ModelSpec(
  provider: AIProvider.gemini,
  model: 'flash-lite',
  label: 'Flash-Lite',
);

String turn(List<Map<String, Object?>> actions, {String? reply}) =>
    jsonEncode({'actions': actions, 'reply': reply});

void main() {
  late FakeRecorder recorder;
  late FakeTranscriber transcriber;
  late ScriptedModel ai;

  VoiceRecipeFlow flow() => VoiceRecipeFlow(
    recorder: recorder,
    transcriber: transcriber,
    agent: VoiceAgent(
      AIRouter(
        config: () => const ChainConfig(vision: [model], text: [model, backup]),
        client: ai,
        keys: OwnKeySource(InMemoryKeyStore({AIProvider.gemini: 'k'})),
        status: InMemoryModelStatusStore(),
      ),
    ),
  );

  setUp(() {
    recorder = FakeRecorder();
    transcriber = FakeTranscriber(['Sarma za šest osoba.']);
    ai = ScriptedModel([
      turn([
        {'op': 'set_title', 'title': 'Sarma'},
        {'op': 'set_servings', 'servings': 6},
      ], reply: 'Upisano.'),
    ]);
  });

  test('Govori → Zaustavi: prepis, agent, nacrt i poruka', () async {
    final f = flow();
    await f.startRecording();
    expect(f.phase, VoicePhase.recording);
    await f.stopAndSend();

    expect(f.phase, VoicePhase.idle);
    expect(f.transcript, 'Sarma za šest osoba.');
    expect(f.draft.title, 'Sarma');
    expect(f.draft.servings, 6);
    expect(f.reply, 'Upisano.');
    expect(f.canUndo, isTrue);
    expect(recorder.recording, isFalse);
  });

  test('odbijen mikrofon: poruka, ništa se ne snima ni šalje', () async {
    recorder.allowed = false;
    final f = flow();
    await f.startRecording();
    expect(f.phase, VoicePhase.idle);
    expect(f.error, contains('Mikrofon nije dozvoljen'));
    expect(transcriber.calls, 0);
  });

  test('greška prepisa: poruka, agent se ne zove', () async {
    transcriber = FakeTranscriber([
      const TranscriptionError(TranscriptionFailure.quota),
    ]);
    final f = flow();
    await f.startRecording();
    await f.stopAndSend();
    expect(f.error, contains('Limit'));
    expect(ai.prompts, isEmpty);
    expect(f.draft.isEmpty, isTrue);
  });

  test('prazan prepis: poruka, agent se ne zove', () async {
    transcriber = FakeTranscriber(['']);
    final f = flow();
    await f.startRecording();
    await f.stopAndSend();
    expect(f.error, contains('Nisam ništa čuo'));
    expect(ai.prompts, isEmpty);
  });

  test('ukucan tekst ide agentu bez snimanja', () async {
    final f = flow();
    await f.sendText('Sarma za šest osoba.');
    expect(transcriber.calls, 0);
    expect(f.draft.title, 'Sarma');
  });

  test(
    'neuspeh agenta: „Pokušaj ponovo“ šalje isti prepis bez novog snimka',
    () async {
      ai = ScriptedModel([
        '{"actions": [{"op": "save_recipe"}]}',
        '{"actions": [{"op": "save_recipe"}]}',
        turn([
          {'op': 'set_title', 'title': 'Sarma'},
        ]),
      ]);
      final f = flow();
      await f.startRecording();
      await f.stopAndSend();
      expect(f.error, isNotNull);
      expect(f.canRetry, isTrue);
      expect(f.draft.isEmpty, isTrue);

      await f.retry();
      expect(f.error, isNull);
      expect(f.draft.title, 'Sarma');
      expect(transcriber.calls, 1);
      expect(ai.prompts.last, contains(jsonEncode('Sarma za šest osoba.')));
    },
  );

  test('Otkaži dok agent radi: zakasneli odgovor ne menja nacrt', () async {
    final f = flow();
    ai.gate = Completer<void>();
    final sending = f.sendText('Sarma za šest osoba.');
    await Future<void>.delayed(Duration.zero);
    expect(f.phase, VoicePhase.thinking);

    await f.cancelTurn();
    ai.gate!.complete();
    await sending;

    expect(f.phase, VoicePhase.idle);
    expect(f.draft.isEmpty, isTrue);
    expect(f.reply, isNull);
  });

  test('Otkaži dok snima: snimak se odbacuje', () async {
    final f = flow();
    await f.startRecording();
    await f.cancelTurn();
    expect(recorder.cancels, 1);
    expect(f.phase, VoicePhase.idle);
    expect(transcriber.calls, 0);
  });

  test('Otkaži dok se snimanje zaustavlja: snimak se ne šalje', () async {
    final f = flow();
    await f.startRecording();
    recorder.stopGate = Completer<void>();
    final sending = f.stopAndSend();
    await Future<void>.delayed(Duration.zero);
    expect(f.phase, VoicePhase.transcribing);

    await f.cancelTurn();
    recorder.stopGate!.complete();
    await sending;

    expect(transcriber.calls, 0);
    expect(f.phase, VoicePhase.idle);
    expect(f.transcript, isNull);
    expect(f.error, isNull);
    expect(f.draft.isEmpty, isTrue);
  });

  test('snimanje staje samo posle najdužeg trajanja', () async {
    recorder = FakeRecorder(limit: const Duration(milliseconds: 10));
    final f = flow();
    await f.startRecording();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(transcriber.calls, 1);
    expect(f.draft.title, 'Sarma');
  });

  test('ispravka zamenjuje prethodni izgovor, bez duplikata', () async {
    ai = ScriptedModel([
      turn([
        {'op': 'add_ingredient', 'name': 'mleveni mens', 'quantity': 1},
      ]),
      turn([
        {'op': 'add_ingredient', 'name': 'mleveno meso', 'quantity': 1},
      ]),
    ]);
    final f = flow();
    await f.sendText('kilogram mlevenog mensa');
    expect(f.canCorrect, isTrue);
    await f.correct('kilogram mlevenog mesa');

    expect([for (final i in f.draft.ingredients) i.name], ['mleveno meso']);
    expect(f.transcript, 'kilogram mlevenog mesa');
  });

  test('ispravka posle neuspeha ne poništava raniji izgovor', () async {
    ai = ScriptedModel([
      turn([
        {'op': 'set_title', 'title': 'Sarma'},
      ]),
      '{"actions": [{"op": "save_recipe"}]}',
      '{"actions": [{"op": "save_recipe"}]}',
      turn([
        {'op': 'set_servings', 'servings': 6},
      ]),
    ]);
    final f = flow();
    await f.sendText('Sarma.');
    await f.sendText('za šest osoba');
    expect(f.error, isNotNull);
    // Neuspeli izgovor nije menjao nacrt, pa ispravka ne dira „Sarma“.
    await f.correct('za šest osoba.');
    expect(f.draft.title, 'Sarma');
    expect(f.draft.servings, 6);
  });

  test('Poništi i Počni ispočetka', () async {
    final f = flow();
    await f.sendText('Sarma za šest osoba.');
    f.undo();
    expect(f.draft.isEmpty, isTrue);

    ai.answers.add(
      turn([
        {'op': 'set_title', 'title': 'Pasulj'},
      ]),
    );
    await f.sendText('Pasulj.');
    f.startOver();
    expect(f.draft.isEmpty, isTrue);
    expect(f.transcript, isNull);
  });

  test('izlazak sa ekrana oslobađa mikrofon', () async {
    final f = flow();
    await f.startRecording();
    f.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(recorder.disposed, isTrue);
  });
}
