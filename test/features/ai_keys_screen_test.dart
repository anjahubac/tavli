import 'dart:convert';
import 'dart:io';

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
  late KeyStore keys;
  late FakeAdapter adapter;

  Future<void> pumpScreen(
    WidgetTester tester, {
    BuiltInKeys builtIn = const BuiltInKeys(),
    Size size = const Size(800, 3000),
  }) async {
    tester.view.physicalSize = size;
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

  Finder keyField() => find.widgetWithText(TextField, 'API ključ');
  Finder button(String text) => find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  const modelsOk = (
    200,
    '{"data":[{"id":"models/gemini-flash-latest"}]}',
    <String, List<String>>{},
  );

  setUp(() => keys = InMemoryKeyStore());

  Future<void> addKey(WidgetTester tester, String value) async {
    await tester.enterText(keyField(), value);
    await tester.pump();
    await tester.tap(button('Dodaj ključ'));
    await tester.pumpAndSettle();
  }

  testWidgets('jedno polje bez naziva servisa; prazna lista', (tester) async {
    adapter = FakeAdapter([]);
    await pumpScreen(tester);

    expect(find.byType(TextField), findsWidgets);
    expect(keyField(), findsOneWidget);
    expect(find.textContaining('Gemini API'), findsNothing);
    expect(find.text('Još nema dodatih ključeva.'), findsOneWidget);
    expect(
      tester.widget<ButtonStyleButton>(button('Dodaj ključ')).enabled,
      isFalse,
    );
  });

  testWidgets('prepoznaje servis, proverava i dodaje ključ', (tester) async {
    adapter = FakeAdapter([modelsOk]);
    await pumpScreen(tester);

    await tester.enterText(keyField(), '  AIza-test-key-1234 ');
    await tester.pump();
    expect(find.text('Prepoznat servis: Gemini'), findsOneWidget);
    await tester.tap(button('Dodaj ključ'));
    await tester.pumpAndSettle();

    final saved = await keys.list();
    expect(saved.single.value, 'AIza-test-key-1234');
    expect(saved.single.provider, AIProvider.gemini);
    expect(adapter.requests.single.uri.path, endsWith('/models'));
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer AIza-test-key-1234',
    );
    expect(find.text('Ključ je dodat (Gemini).'), findsOneWidget);
    expect(find.text('••••1234'), findsOneWidget);
    expect(find.textContaining('AIza-test'), findsNothing);
    expect(find.textContaining('Radi'), findsOneWidget);
    expect(find.text('✓ Gemini Flash'), findsOneWidget);
  });

  testWidgets('više ključeva istog servisa; isti ključ dvaput ne', (
    tester,
  ) async {
    adapter = FakeAdapter([modelsOk, modelsOk]);
    await pumpScreen(tester);

    await addKey(tester, 'gsk_first-aaaa');
    await addKey(tester, 'gsk_second-bbbb');
    expect((await keys.list()).map((k) => k.value), [
      'gsk_first-aaaa',
      'gsk_second-bbbb',
    ]);
    expect(find.text('••••aaaa'), findsOneWidget);
    expect(find.text('••••bbbb'), findsOneWidget);

    await addKey(tester, 'gsk_first-aaaa');
    expect(find.text('Ovaj ključ je već dodat.'), findsOneWidget);
    expect(await keys.list(), hasLength(2));
  });

  testWidgets('nepoznat format: bira se servis', (tester) async {
    adapter = FakeAdapter([modelsOk]);
    await pumpScreen(tester);

    await tester.enterText(keyField(), 'nepoznat-kljuc-9999');
    await tester.pump();
    expect(find.text('Izaberi servis'), findsOneWidget);
    expect(
      tester.widget<ButtonStyleButton>(button('Dodaj ključ')).enabled,
      isFalse,
    );

    await tester.tap(find.text('Izaberi servis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenRouter').last);
    await tester.pumpAndSettle();
    await tester.tap(button('Dodaj ključ'));
    await tester.pumpAndSettle();

    expect((await keys.list()).single.provider, AIProvider.openRouter);
  });

  testWidgets('odbijen ključ se ne čuva', (tester) async {
    adapter = FakeAdapter([(401, '{"error":"invalid"}', {})]);
    await pumpScreen(tester);

    await addKey(tester, 'AIza-bad');

    expect(find.text('Ključ nije ispravan ili je opozvan.'), findsOneWidget);
    expect(await keys.list(), isEmpty);
  });

  testWidgets('bez mreže ključ se čuva kao neproveren', (tester) async {
    adapter = FakeAdapter([(503, '{}', {}), (503, '{}', {})]);
    await pumpScreen(tester);

    await addKey(tester, 'gsk_offline-0000');

    expect(await keys.list(), hasLength(1));
    expect(find.textContaining('Nije provereno'), findsOneWidget);
  });

  testWidgets('uzak telefon: lista ključeva staje bez prelivanja', (
    tester,
  ) async {
    adapter = FakeAdapter([]);
    await keys.add(AIProvider.openRouter, 'sk-or-v1-fake-5555');
    await pumpScreen(tester, size: const Size(360, 1600));

    expect(find.text('••••5555'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('greška skladišta: poruka umesto beskonačnog učitavanja', (
    tester,
  ) async {
    adapter = FakeAdapter([]);
    keys = _BrokenKeyStore();
    await pumpScreen(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.textContaining('Ključevi nisu učitani iz sigurnog skladišta'),
      findsOneWidget,
    );
    expect(find.text('Pokušaj ponovo'), findsOneWidget);
  });

  testWidgets('brisanje ključa uz potvrdu', (tester) async {
    adapter = FakeAdapter([]);
    await keys.add(AIProvider.groq, 'gsk_old-7777');
    await pumpScreen(tester);
    expect(find.text('••••7777'), findsOneWidget);

    await tester.tap(find.byTooltip('Obriši ključ'));
    await tester.pumpAndSettle();
    expect(find.text('Obrisati ključ ••••7777?'), findsOneWidget);
    await tester.tap(button('Obriši'));
    await tester.pumpAndSettle();

    expect(await keys.list(), isEmpty);
    expect(find.text('Ključ je obrisan.'), findsOneWidget);
    expect(find.text('Još nema dodatih ključeva.'), findsOneWidget);
  });

  group('ugrađeni Tavli AI', () {
    const builtIn = BuiltInKeys({AIProvider.gemini: 'b-key'});
    const inUse = 'Koristi se ugrađeni Tavli AI: Gemini';

    testWidgets('prikazuje se kad nema sopstvenog ključa', (tester) async {
      adapter = FakeAdapter([]);
      await pumpScreen(tester, builtIn: builtIn);

      expect(find.text(inUse), findsOneWidget);
      expect(find.text('b-key'), findsNothing);
    });

    testWidgets('ne prikazuje se uz sopstveni ključ', (tester) async {
      adapter = FakeAdapter([]);
      await keys.add(AIProvider.gemini, 'own');
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

class _BrokenKeyStore extends InMemoryKeyStore {
  @override
  Future<List<StoredKey>> list() async =>
      throw const FileSystemException('keychain');
}
