import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/chat_client.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/features/settings/ai_keys_screen.dart';
import 'package:tavli/providers.dart';

import '../helpers/fake_adapter.dart';

void main() {
  late InMemoryKeyStore keys;
  late FakeAdapter adapter;

  Future<void> pumpScreen(
    WidgetTester tester, {
    BuiltInKeys builtIn = const BuiltInKeys(),
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyStoreProvider.overrideWithValue(keys),
          builtInKeysProvider.overrideWithValue(builtIn),
          databaseProvider.overrideWithValue(db),
          chatClientProvider.overrideWithValue(
            OpenAICompatibleClient(
              dio: Dio()..httpClientAdapter = adapter,
              transientRetryDelay: Duration.zero,
            ),
          ),
        ],
        child: const MaterialApp(home: AiKeysScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder geminiField() => find.byType(TextField).first;

  setUp(() => keys = InMemoryKeyStore());

  testWidgets('čuva ključ i proverava ga preko liste modela', (tester) async {
    adapter = FakeAdapter([
      (
        200,
        jsonEncode({
          'data': [
            {'id': 'models/gemini-flash-latest'},
          ],
        }),
        {},
      ),
    ]);
    await pumpScreen(tester);
    expect(find.text('Nema ključa'), findsNWidgets(3));

    await tester.enterText(geminiField(), '  test-gemini-key ');
    await tester.tap(find.text('Sačuvaj').first);
    await tester.pumpAndSettle();

    expect(await keys.read(AIProvider.gemini), 'test-gemini-key');
    expect(find.text('Sačuvan'), findsOneWidget);
    expect(find.text('Ključ radi. Dostupno modela: 1.'), findsOneWidget);
    expect(find.text('Gemini Flash'), findsOneWidget);
    expect(adapter.requests.single.uri.path, endsWith('/models'));
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer test-gemini-key',
    );
  });

  testWidgets('pogrešan ključ prikazuje jasnu poruku', (tester) async {
    adapter = FakeAdapter([(401, '{"error":"invalid"}', {})]);
    await keys.write(AIProvider.gemini, 'stari');
    await pumpScreen(tester);

    await tester.tap(find.text('Proveri').first);
    await tester.pumpAndSettle();

    expect(find.text('Ključ nije ispravan ili je opozvan.'), findsOneWidget);
  });

  testWidgets('brisanje ključa', (tester) async {
    adapter = FakeAdapter([]);
    await keys.write(AIProvider.gemini, 'stari');
    await pumpScreen(tester);

    await tester.tap(find.text('Obriši'));
    await tester.pumpAndSettle();

    expect(await keys.read(AIProvider.gemini), isNull);
    expect(find.text('Ključ je obrisan.'), findsOneWidget);
  });

  group('ugrađeni Tavli AI', () {
    const builtIn = BuiltInKeys({AIProvider.gemini: 'b-key'});
    const inUse = 'Koristi se ugrađeni Tavli AI';

    testWidgets('prikazuje se kad nema sopstvenog ključa', (tester) async {
      adapter = FakeAdapter([]);
      await pumpScreen(tester, builtIn: builtIn);

      expect(find.text(inUse), findsOneWidget);
      expect(find.text('b-key'), findsNothing);
    });

    testWidgets('ne prikazuje se uz sopstveni ključ', (tester) async {
      adapter = FakeAdapter([]);
      await keys.write(AIProvider.gemini, 'own');
      await pumpScreen(tester, builtIn: builtIn);

      expect(find.text(inUse), findsNothing);
    });

    testWidgets('ne prikazuje se bez ugrađenih ključeva', (tester) async {
      adapter = FakeAdapter([]);
      await pumpScreen(tester);

      expect(find.text(inUse), findsNothing);
    });

    testWidgets('probni recept sa ugrađenim ključem nosi oznaku Tavli AI', (
      tester,
    ) async {
      final recipe = {
        'title': 'Palačinke',
        'servings': 2,
        'ingredients': [
          {'name': 'brašno', 'quantity': 200, 'unit': 'g'},
        ],
        'steps': ['Umesi.'],
      };
      adapter = FakeAdapter([
        (
          200,
          jsonEncode({
            'choices': [
              {
                'message': {'content': jsonEncode(recipe)},
              },
            ],
          }),
          {},
        ),
      ]);
      await pumpScreen(tester, builtIn: builtIn);

      await tester.tap(find.text('Napravi probni recept'));
      await tester.pumpAndSettle();
      expect(adapter.requests.single.headers['Authorization'], 'Bearer b-key');
      expect(
        find.textContaining('Odgovorio: Gemini Pro · Tavli AI'),
        findsOneWidget,
      );

      await tester.tap(find.text('Kako je lanac radio'));
      await tester.pumpAndSettle();
      expect(find.text('Gemini Pro · Tavli AI'), findsOneWidget);
    });
  });
}
