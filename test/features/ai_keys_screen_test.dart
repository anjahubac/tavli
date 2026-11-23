import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/chat_client.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/features/settings/ai_keys_screen.dart';
import 'package:tavli/providers.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../helpers/fake_adapter.dart';

void main() {
  late KeyStore keys;
  late FakeAdapter adapter;

  Future<AppDatabase> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(800, 3000),
    double textScale = 1,
    AppDatabase? database,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = database ?? AppDatabase(NativeDatabase.memory());
    if (database == null) addTearDown(db.close);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyStoreProvider.overrideWithValue(keys),
          databaseProvider.overrideWithValue(db),
          chatClientProvider.overrideWithValue(
            OpenAICompatibleClient(
              dio: Dio()..httpClientAdapter = adapter,
              transientRetryDelay: Duration.zero,
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildTavliTheme(TavliMotif.bosiljak, Brightness.light),
          home: const AiKeysScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  Finder keyField() => find.descendant(
    of: find.widgetWithText(TavliTextField, 'API ključ'),
    matching: find.byType(TextField),
  );
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

  testWidgets('nepoznat servis: poruka, dugme isključeno, ništa se ne šalje', (
    tester,
  ) async {
    adapter = FakeAdapter([]);
    await pumpScreen(tester);

    for (final key in ['nepoznat-kljuc-9999', 'sk-ant-fake-9999']) {
      await tester.enterText(keyField(), key);
      await tester.pump();
      expect(
        find.text(
          'Servis nije prepoznat. Podržani su: '
          'Gemini, Groq, OpenRouter, OpenAI.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Prepoznat servis'), findsNothing);
      expect(
        tester.widget<ButtonStyleButton>(button('Dodaj ključ')).enabled,
        isFalse,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
    expect(find.text('Izaberi servis'), findsNothing);
    expect(adapter.requests, isEmpty);
    expect(await keys.list(), isEmpty);
  });

  testWidgets('poruka o servisu se gubi kad je polje prazno', (tester) async {
    adapter = FakeAdapter([]);
    await pumpScreen(tester);

    await tester.enterText(keyField(), 'x');
    await tester.pump();
    await tester.enterText(keyField(), '  ');
    await tester.pump();

    expect(find.textContaining('Servis nije prepoznat'), findsNothing);
  });

  testWidgets('OpenAI ključ: prepoznat, proveren i označen kao plaćen', (
    tester,
  ) async {
    adapter = FakeAdapter([
      (200, '{"data":[{"id":"gpt-4o-mini"}]}', <String, List<String>>{}),
    ]);
    await pumpScreen(tester);

    await tester.enterText(keyField(), 'sk-proj-fake-1234');
    await tester.pump();
    expect(find.text('Prepoznat servis: OpenAI'), findsOneWidget);
    await tester.tap(button('Dodaj ključ'));
    await tester.pumpAndSettle();

    expect(
      adapter.requests.single.uri.toString(),
      'https://api.openai.com/v1/models',
    );
    expect((await keys.list()).single.provider, AIProvider.openAI);
    expect(find.text('✓ OpenAI GPT-4o mini'), findsOneWidget);
    expect(find.textContaining('plaćen · Radi'), findsOneWidget);
  });

  group('redosled', () {
    final toggle = find.byType(TavliChoice<OwnKeyOrder>);

    testWidgets('vidi se samo uz plaćen i besplatan ključ', (tester) async {
      adapter = FakeAdapter([modelsOk]);
      await keys.add(AIProvider.gemini, 'AIza-fake-1111');
      await keys.add(AIProvider.groq, 'gsk_fake-2222');
      await pumpScreen(tester);
      expect(toggle, findsNothing);
      expect(find.text('Redosled'), findsNothing);

      await addKey(tester, 'sk-proj-fake-3333');
      expect(toggle, findsOneWidget);
      expect(find.text('Redosled'), findsOneWidget);
      expect(
        find.text(
          'Važi za tvoje ključeve. Ključevi koji dolaze uz aplikaciju uvek '
          'idu na kraju.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('samo plaćeni ključevi: nema izbora', (tester) async {
      adapter = FakeAdapter([]);
      await keys.add(AIProvider.openAI, 'sk-fake-1111');
      await pumpScreen(tester);

      expect(toggle, findsNothing);
    });

    testWidgets('izbor ostaje sačuvan', (tester) async {
      adapter = FakeAdapter([]);
      await keys.add(AIProvider.gemini, 'AIza-fake-1111');
      await keys.add(AIProvider.openAI, 'sk-fake-3333');
      final db = await pumpScreen(tester);
      expect(
        tester.widget<TavliChoice<OwnKeyOrder>>(toggle).selected,
        OwnKeyOrder.paidFirst,
      );

      await tester.tap(find.text('Prvo besplatni'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await pumpScreen(tester, database: db);
      expect(
        tester.widget<TavliChoice<OwnKeyOrder>>(toggle).selected,
        OwnKeyOrder.freeFirst,
      );
    });

    for (final (size, scale) in [
      (const Size(320, 4000), 1.0),
      (const Size(320, 4000), 2.0),
      (const Size(1200, 2000), 1.0),
      (const Size(1200, 2000), 2.0),
    ]) {
      testWidgets('staje na ${size.width.round()}, tekst $scale×', (
        tester,
      ) async {
        adapter = FakeAdapter([]);
        await keys.add(AIProvider.gemini, 'AIza-fake-1111');
        await keys.add(AIProvider.openAI, 'sk-fake-3333');
        await pumpScreen(tester, size: size, textScale: scale);
        await tester.enterText(keyField(), 'nepoznat');
        await tester.pump();

        expect(toggle, findsOneWidget);
        expect(tester.takeException(), isNull);
        final page = tester.getRect(find.byType(AiKeysScreen));
        final box = tester.getRect(toggle);
        expect(box.left, greaterThanOrEqualTo(page.left));
        expect(box.right, lessThanOrEqualTo(page.right));
      });
    }
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

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is TavliIconButton && w.semanticLabel == 'Obriši ključ',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Obrisati ključ ••••7777?'), findsOneWidget);
    await tester.tap(button('Obriši'));
    await tester.pumpAndSettle();

    expect(await keys.list(), isEmpty);
    expect(find.text('Ključ je obrisan.'), findsOneWidget);
    expect(find.text('Još nema dodatih ključeva.'), findsOneWidget);
  });

  testWidgets('bez ključeva nema pomena ugrađenih ni sekcije „Probaj AI“', (
    tester,
  ) async {
    adapter = FakeAdapter([]);
    await pumpScreen(tester);

    expect(find.text('Još nema dodatih ključeva.'), findsOneWidget);
    expect(find.textContaining('ugrađen'), findsNothing);
    expect(find.textContaining('••••'), findsNothing);
    expect(find.text('Probaj AI'), findsNothing);
    expect(find.text('Napravi probni recept'), findsNothing);
  });

  testWidgets('obaveštenje o redosledu ključeva', (tester) async {
    adapter = FakeAdapter([]);
    await pumpScreen(tester);

    expect(
      find.textContaining(
        'Tavli prvo koristi tvoje ključeve, redom. Kad se njihov besplatni '
        'limit potroši, prelazi na besplatne ključeve koji dolaze uz '
        'aplikaciju.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('aistudio.google.com'), findsNothing);
  });
}

class _BrokenKeyStore extends InMemoryKeyStore {
  @override
  Future<List<StoredKey>> list() async =>
      throw const FileSystemException('keychain');
}
