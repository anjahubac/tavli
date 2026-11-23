import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/features/recipes/recipe_providers.dart';
import 'package:tavli/features/recipes/recipe_view.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/fake_photo_store.dart';

Future<void> _pump(
  WidgetTester tester,
  RecipeImageSource? source, {
  TavliMotif motif = TavliMotif.bosiljak,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [recipePhotoStoreProvider.overrideWithValue(FakePhotoStore())],
      child: MaterialApp(
        theme: buildTavliTheme(motif, brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipeView(
              Recipe(
                id: 'r',
                title: 'Sarma',
                servings: 4,
                ingredients: const [Ingredient(name: 'kupus')],
                source: RecipeSource.ai,
                createdAt: DateTime.utc(2026),
                imagePath: 'recipe_photos/a.jpg',
                imageSource: source,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final motif in TavliMotif.values) {
    for (final brightness in Brightness.values) {
      for (final size in const [Size(390, 844), Size(1280, 800)]) {
        testWidgets(
          'AI image shows the label, ${motif.name} $brightness $size, 2x text',
          (tester) async {
            await _pump(
              tester,
              RecipeImageSource.ai,
              motif: motif,
              brightness: brightness,
              textScale: 2,
              size: size,
            );
            expect(find.text('AI slika'), findsOneWidget);
            expect(
              find.bySemanticsLabel('Sliku je napravio AI'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final source in [RecipeImageSource.user, null]) {
    testWidgets('no label for image source $source', (tester) async {
      await _pump(tester, source);
      expect(find.text('AI slika'), findsNothing);
    });
  }
}
