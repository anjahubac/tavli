import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/chat_client.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/app/app.dart';
import 'package:tavli/app/router.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/recipe_repository.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/features/recipes/photo_picker.dart';
import 'package:tavli/features/recipes/recipe_providers.dart';
import 'package:tavli/providers.dart';

import 'fake_adapter.dart';
import 'fake_photo_store.dart';

const phone = Size(400, 800);
const wide = Size(1200, 800);

/// Mala prava slika (PNG); smanjivanje je u testovima isključeno.
final fakePhoto = img.encodePng(img.Image(width: 4, height: 4));

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.canUseCamera = true});

  @override
  final bool canUseCamera;

  /// Šta sledeći izbor vraća (null = korisnik je odustao).
  Uint8List? next;
  final calls = <bool>[];

  @override
  Future<Uint8List?> pick({required bool camera}) async {
    calls.add(camera);
    return next;
  }
}

/// Odgovor AI-ja (OpenAI oblik) sa datim JSON-om.
(int, String, Map<String, List<String>>) aiAnswer(Map<String, dynamic> json) =>
    (
      200,
      jsonEncode({
        'choices': [
          {
            'message': {'content': jsonEncode(json)},
          },
        ],
      }),
      {},
    );

Map<String, dynamic> recipeJson(String title, {int servings = 2}) => {
  'title': title,
  'servings': servings,
  'prepMinutes': 30,
  'ingredients': [
    {
      'name': 'crni luk',
      'quantity': 0.5,
      'unit': 'kg',
      'category': 'voće i povrće',
    },
    {'name': 'biber', 'category': 'začini i sosovi'},
  ],
  'steps': ['Iseckati luk.', 'Kuvati.'],
};

Recipe sampleRecipe(
  String id,
  String title, {
  DateTime? createdAt,
  RecipeSource source = RecipeSource.manual,
}) => Recipe(
  id: id,
  title: title,
  servings: 4,
  prepMinutes: 45,
  ingredients: const [
    Ingredient(name: 'biber', category: 'začini i sosovi'),
    Ingredient(
      name: 'kupus',
      quantity: 0.5,
      unit: 'kg',
      category: 'voće i povrće',
    ),
  ],
  steps: const ['Umotati.', 'Kuvati.'],
  source: source,
  createdAt: createdAt ?? DateTime.utc(2026),
);

class TestApp {
  TestApp(this.db, this.photos, this.picker, this.adapter);

  final AppDatabase db;
  final FakePhotoStore photos;
  final FakePhotoPicker picker;
  final FakeAdapter adapter;

  RecipeRepository get repo => RecipeRepository(db, photos);

  /// Naslovi sačuvanih recepata. Bez drift tokova: njihovi tajmeri ne
  /// rade dok se test ne pumpa.
  Future<List<String>> titles() async => [
    for (final r in await db.select(db.recipes).get()) r.title,
  ];
}

/// Cela aplikacija sa bazom u memoriji, lažnim AI-jem (ugrađeni test ključ)
/// i lažnim izborom slike.
Future<TestApp> pumpTavli(
  WidgetTester tester, {
  Size size = phone,
  String location = '/recipes',
  List<Recipe> recipes = const [],
  List<(int, String, Map<String, List<String>>)> ai = const [],
  bool canUseCamera = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = AppDatabase(NativeDatabase.memory());
  final app = TestApp(
    db,
    FakePhotoStore(),
    FakePhotoPicker(canUseCamera: canUseCamera),
    FakeAdapter([...ai]),
  );
  for (final r in recipes) {
    await app.repo.create(r);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        keyStoreProvider.overrideWithValue(InMemoryKeyStore()),
        builtInKeysProvider.overrideWithValue(
          const BuiltInKeys({AIProvider.gemini: 'fake-test-key'}),
        ),
        chatClientProvider.overrideWithValue(
          OpenAICompatibleClient(
            dio: Dio()..httpClientAdapter = app.adapter,
            transientRetryDelay: Duration.zero,
          ),
        ),
        recipePhotoStoreProvider.overrideWithValue(app.photos),
        photoPickerProvider.overrideWithValue(app.picker),
        photoResizerProvider.overrideWithValue((bytes) async => bytes),
      ],
      child: TavliApp(router: createRouter(initialLocation: location)),
    ),
  );
  await tester.pumpAndSettle();
  _current = app;
  return app;
}

TestApp? _current;

/// Skroluje do dugmeta pa ga pritiska.
Future<void> tapButton(WidgetTester tester, String text) async {
  await tester.ensureVisible(button(text));
  await tester.pumpAndSettle();
  await tester.tap(button(text));
  await tester.pumpAndSettle();
}

/// Dugme (bilo koje Material dugme) sa datim tekstom.
Finder button(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

/// testWidgets koji na kraju skida aplikaciju, da drift tokovi i
/// riverpod zatvore tajmere pre provere na kraju testa.
void testTavli(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await _current?.db.close();
    _current = null;
  });
}
