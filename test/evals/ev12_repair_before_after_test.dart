// EV-12 pre/posle izmene #69 (jedna popravka nevalidnog odgovora).
//
// Isti ulazi se izvršavaju na commitu pre i posle #69; rezultati su u
// evals/capstone/results.md i evals/capstone/traces/ev12-repair-before-after.jsonl.
// Test proverava ponašanje posle #69, pa na commitu pre #69 pada.
// Svaki scenario ispisuje jedan red `EVRESULT {...}` za trag.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_errors.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/ai_router.dart';
import 'package:tavli/ai/chain_config.dart';
import 'package:tavli/ai/chat_client.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/ai/model_status_store.dart';
import 'package:tavli/ai/recipe_ai.dart';

import '../ai/ai_router_test.dart' show geminiPro, groqText;

const _bad = '{"title":"Gulaš","servings":0,"ingredients":[],"steps":[]}';
const _good =
    '{"title":"Supa","servings":4,"ingredients":'
    '[{"name":"voda","quantity":1,"unit":"l"}],"steps":["Prokuvaj."]}';

class _RecordingClient implements ChatClient {
  _RecordingClient(this.scripts);

  final Map<String, List<Object>> scripts;
  final calls = <String>[];
  final prompts = <String>[];

  @override
  Future<String> complete(
    ModelSpec model,
    AIRequest request, {
    required String apiKey,
  }) async {
    calls.add(model.key);
    prompts.add(request.prompt);
    final next = scripts[model.key]!.removeAt(0);
    if (next is AIError) throw next;
    return next as String;
  }
}

class _Run {
  _Run(this.calls, this.repairWithPreviousAnswer, this.outcome);

  final List<String> calls;
  final bool repairWithPreviousAnswer;
  final String outcome;
}

Future<_Run> _run(String scenario, Map<String, List<Object>> scripts) async {
  final client = _RecordingClient(scripts);
  final router = AIRouter(
    config: () => const ChainConfig(
      vision: [geminiPro, groqText],
      text: [geminiPro, groqText],
    ),
    client: client,
    keys: LayeredKeySource(
      InMemoryKeyStore({AIProvider.gemini: 'g', AIProvider.groq: 'q'}),
      const BuiltInKeys(),
    ),
    status: InMemoryModelStatusStore(),
    clock: () => DateTime.utc(2026, 11, 21, 12),
  );
  final ai = RecipeAI(router, clock: () => DateTime.utc(2026, 11, 21, 12));
  String outcome;
  try {
    outcome = 'recipe:${(await ai.fromDishName('gulaš')).value.title}';
  } on Object catch (e) {
    outcome = e.runtimeType.toString();
  }
  // Popravka: drugi zahtev nosi prethodni (nevalidan) odgovor modela.
  final repair =
      client.prompts.length > 1 && client.prompts[1].contains('"servings":0');
  // Trag za evals/capstone/traces; bez ključeva i ličnih podataka.
  // ignore: avoid_print
  print(
    'EVRESULT ${jsonEncode({'scenario': scenario, 'calls': client.calls, 'callCount': client.calls.length, 'repairPromptWithPreviousAnswer': repair, 'outcome': outcome})}',
  );
  return _Run(client.calls, repair, outcome);
}

void main() {
  test('EV-12a svi odgovori nevalidni: jedna popravka, pa stop', () async {
    final r = await _run('EV-12a: svi odgovori nevalidni', {
      'gemini/pro': [_bad, _bad, _bad],
      'groq/text': [_bad, _bad, _bad],
    });
    expect(r.calls, ['gemini/pro', 'gemini/pro']);
    expect(r.repairWithPreviousAnswer, isTrue);
    expect(r.outcome, 'AllModelsExhausted');
  });

  test('EV-12b nevalidan pa ispravan: popravka vraća recept', () async {
    final r = await _run('EV-12b: nevalidan pa ispravan', {
      'gemini/pro': [_bad, _good, _good],
      'groq/text': [_good, _good],
    });
    expect(r.calls, ['gemini/pro', 'gemini/pro']);
    expect(r.repairWithPreviousAnswer, isTrue);
    expect(r.outcome, 'recipe:Supa');
  });
}
