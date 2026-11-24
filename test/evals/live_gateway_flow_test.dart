// Živi prolaz kroz AI gateway sa prijavom (CAP-02, CAP-04, CAP-06).
//
// Pokreće se samo ručno, protiv lokalnog Supabase-a (`supabase start`) čiji
// `ai-gateway` ima ključ provajdera kao tajnu funkcije. Aplikacija nema ključ:
// zahtev ide sa JWT-om sintetičkog korisnika kroz isti `GatewayChatClient` i
// `AIRouter` kao u aplikaciji. Detalji: evals/capstone/gateway-flow.md.
//
//   GATEWAY_LIVE=1 SUPABASE_URL=… SUPABASE_ANON_KEY=… \
//   GATEWAY_TEST_EMAIL=… GATEWAY_TEST_PASSWORD=… \
//   flutter test test/evals/live_gateway_flow_test.dart
//
// Trag (bez tokena, ključeva i teksta recepta osim imena sastojaka) ide u
// evals/capstone/traces/gateway-flow.jsonl.
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/ai/ai_errors.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/ai_router.dart';
import 'package:tavli/ai/chain_config.dart';
import 'package:tavli/ai/chat_client.dart';
import 'package:tavli/ai/gateway_chat_client.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/ai/model_status_store.dart';
import 'package:tavli/ai/recipe_ai.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/shopping_repository.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/sync/synced_writer.dart';

final _env = Platform.environment;
final _live = _env['GATEWAY_LIVE'] == '1';
const _trace = 'evals/capstone/traces/gateway-flow.jsonl';

/// Oznaka prolaza (npr. `before`, `after`) da se isti ulazi porede.
final _label = _env['GATEWAY_LABEL'] ?? 'run';

void _record(Map<String, Object?> line) {
  File(_trace).writeAsStringSync(
    '${jsonEncode({'at': DateTime.now().toUtc().toIso8601String(), 'label': _label, ...line})}\n',
    mode: FileMode.append,
  );
}

/// Pokušaji koji su stvarno poslati (bez preskočenih modela bez ključa).
List<String> _sent(List<AttemptLog> attempts) => [
  for (final a in attempts)
    if (a.origin == KeyOrigin.builtIn) a.toString(),
];

List<String> _ingredients(Recipe recipe) => [
  for (final i in recipe.ingredients)
    [
      if (i.quantity != null) '${i.quantity}',
      ?i.unit,
      i.name,
      if (i.note != null) '(note: ${i.note})',
    ].join(' '),
];

/// Status i kod greške gateway-a za sirov zahtev (bez tela odgovora u tragu).
Future<(int, String?)> _raw(
  Uri url, {
  String method = 'POST',
  String? token,
  List<int>? body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, url);
    if (token != null) request.headers.set('Authorization', 'Bearer $token');
    request.headers.contentType = ContentType.json;
    if (body != null) request.add(body);
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    String? code;
    try {
      final data = jsonDecode(text);
      if (data is Map && data['error'] is String) {
        code = data['error'] as String;
      }
    } on FormatException {
      code = null;
    }
    return (response.statusCode, code);
  } finally {
    client.close(force: true);
  }
}

void main() {
  late SupabaseClient supabase;
  late AIRouter router;
  late Uri gatewayUrl;

  setUpAll(() async {
    if (!_live) return;
    final url = _env['SUPABASE_URL']!;
    gatewayUrl = Uri.parse('$url/functions/v1/ai-gateway');
    supabase = SupabaseClient(url, _env['SUPABASE_ANON_KEY']!);
    await supabase.auth.signInWithPassword(
      email: _env['GATEWAY_TEST_EMAIL']!,
      password: _env['GATEWAY_TEST_PASSWORD']!,
    );
    router = AIRouter(
      config: () => ChainConfig.defaults,
      client: OpenAICompatibleClient(),
      // Bez ličnog ključa: jedini put do modela je gateway.
      keys: OwnKeySource(InMemoryKeyStore()),
      status: InMemoryModelStatusStore(),
      gateway: GatewayChatClient.supabase(supabase, refresh: () async => true),
    );
  });

  tearDownAll(() async {
    if (_live) await supabase.dispose();
  });

  final skip = _live ? null : 'ručno: GATEWAY_LIVE=1 i lokalni Supabase';

  test(
    'GW-01 fotografija → gateway → potvrđen recept → obračun nabavke',
    () async {
      final photo = File('evals/capstone/fixtures/recipe-card.jpg');
      final result = await RecipeAI(router)
          .fromImage(AIImage(photo.readAsBytesSync()));
      final recipe = result.value;

      // Korak „potvrdi“: korisnik prihvata pregledan recept bez izmena.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final shopping = ShoppingRepository(
        db,
        scope: const AccountScope(userId: 'gw', householdId: 'gw-home'),
        writer: SyncedWriter(db, accountId: 'gw'),
      );
      final listId = await shopping.recipeList();
      // Stavka koja je već na listi: alat mora da je sabere sa receptom.
      await shopping.addManual(listId, 'Brašno', quantity: 200, unit: 'g');
      await shopping.addMissing(
        recipe.id,
        missing: recipe.ingredients,
        have: const <Ingredient>[],
      );
      final totals = ShoppingRepository.totalsOf(
        await shopping.listItems(listId),
      );
      final flour = totals.where((t) => t.ingredient.contains('brašn'));

      _record({
        'case': 'GW-01',
        'origin': result.origin.name,
        'model': result.model.toString(),
        'sent': _sent(result.attempts),
        'servings': recipe.servings,
        'ingredients': _ingredients(recipe),
        'steps': recipe.steps.length,
        'flourTotal': [
          for (final t in flour) '${t.openMicros / 1000000} ${t.baseUnit}',
        ],
        'totals': totals.length,
      });

      expect(result.origin, KeyOrigin.builtIn);
      expect(recipe.ingredients.length, greaterThanOrEqualTo(5));
      expect(recipe.steps, isNotEmpty);
      // Recept iz živog toka hrani obračun: 500 g brašna iz recepta je u
      // ukupnom zbiru. Da li se sabira sa ručnom stavkom „Brašno“ zavisi od
      // imena koje model vrati; ishod se beleži u tragu (`flourTotal`).
      expect(
        flour.map((t) => t.openMicros),
        anyOf(contains(500 * 1000000), contains(700 * 1000000)),
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'GW-02 nečitka fotografija završava kontrolisano, bez recepta',
    () async {
      final photo = File('evals/capstone/fixtures/recipe-card-unreadable.jpg');
      String outcome;
      int? ingredients;
      try {
        final result = await RecipeAI(router)
            .fromImage(AIImage(photo.readAsBytesSync()));
        outcome = 'recipe';
        ingredients = result.value.ingredients.length;
        _record({
          'case': 'GW-02',
          'detail': 'recipe returned',
          'model': result.model.toString(),
          'ingredients': _ingredients(result.value),
        });
      } on NotARecipeException {
        outcome = 'NotARecipeException';
      } on AIError catch (e) {
        outcome = e.runtimeType.toString();
      } on AllModelsExhausted {
        // Nijedan model nije odgovorio: ishod ne govori o čitanju slike.
        outcome = 'AllModelsExhausted';
      }
      _record({
        'case': 'GW-02',
        'outcome': outcome,
        'ingredients': ingredients,
      });
      expect(outcome, 'NotARecipeException');
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'GW-04 jedan nečitak red: recept ostaje, a taj sastojak nosi napomenu',
    () async {
      final photo = File(
        'evals/capstone/fixtures/recipe-card-one-line-unreadable.jpg',
      );
      final result = await RecipeAI(router)
          .fromImage(AIImage(photo.readAsBytesSync()));
      final recipe = result.value;
      final noted = [
        for (final i in recipe.ingredients)
          if (i.note != null) i.name,
      ];
      _record({
        'case': 'GW-04',
        'model': result.model.toString(),
        'ingredients': _ingredients(recipe),
        'noted': noted,
      });
      expect(recipe.ingredients.length, greaterThanOrEqualTo(5));
      expect(noted, isNotEmpty);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'GW-03 server odbija pre poziva modela: bez tokena, lažan token, '
    'preveliko telo, nepoznat zadatak, model van liste, višak polja',
    () async {
      final token = supabase.auth.currentSession!.accessToken;
      final ok = {
        'task': 'recipe_from_name',
        'model': 'gemini/gemini-flash-lite-latest',
        'system': 's',
        'prompt': 'p',
      };
      final cases = <String, Future<(int, String?)>>{
        'no_token': _raw(gatewayUrl, body: utf8.encode(jsonEncode(ok))),
        'forged_token': _raw(
          gatewayUrl,
          token: 'eyJhbGciOiJIUzI1NiJ9.e30.forged',
          body: utf8.encode(jsonEncode(ok)),
        ),
        'too_large': _raw(
          gatewayUrl,
          token: token,
          body: utf8.encode(jsonEncode({...ok, 'prompt': 'x' * 1600000})),
        ),
        'unknown_task': _raw(
          gatewayUrl,
          token: token,
          body: utf8.encode(jsonEncode({...ok, 'task': 'run_sql'})),
        ),
        'model_not_allowed': _raw(
          gatewayUrl,
          token: token,
          body: utf8.encode(jsonEncode({...ok, 'model': 'evil/any-model'})),
        ),
        'extra_field': _raw(
          gatewayUrl,
          token: token,
          body: utf8.encode(
            jsonEncode({...ok, 'url': 'http://169.254.169.254'}),
          ),
        ),
        'bad_json': _raw(gatewayUrl, token: token, body: utf8.encode('{')),
      };
      final results = {
        for (final entry in cases.entries) entry.key: await entry.value,
      };
      _record({
        'case': 'GW-03',
        'results': {
          for (final e in results.entries) e.key: '${e.value.$1} ${e.value.$2}',
        },
      });
      expect(results['no_token']!.$1, 401);
      expect(results['forged_token']!.$1, 401);
      expect(results['too_large'], (413, 'too_large'));
      expect(results['unknown_task'], (400, 'bad_request'));
      expect(results['model_not_allowed'], (400, 'bad_request'));
      expect(results['extra_field'], (400, 'bad_request'));
      expect(results['bad_json'], (400, 'bad_request'));
    },
    skip: skip,
  );
}
