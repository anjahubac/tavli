import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/app/theme/tavli_colors.dart';

import '../../helpers/test_app.dart';

void main() {
  testTavli('po nazivu: dok AI radi lonac krčka i smenjuju se poruke', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/name',
      ai: [aiAnswer(recipeJson('Sarma'))],
    );
    final gate = app.adapter.gate = Completer<void>();
    await tester.enterText(
      find.widgetWithText(TextField, 'Naziv jela'),
      'sarma',
    );
    await tester.pump();
    await tester.tap(button('Napravi recept'));
    await tester.pump();

    expect(find.bySemanticsLabel('Lonac koji krčka'), findsOneWidget);
    expect(find.text('Pravim recept…'), findsOneWidget);
    expect(find.text('Seckam luk…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Dodajem začine…'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Lonac koji krčka'), findsNothing);
    expect(find.text('Sarma'), findsOneWidget);
  });

  testTavli('iz slike: skeniranje dok AI čita, pa sastojci kao čipovi', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/photo',
      ai: [aiAnswer(recipeJson('Pita'))],
    );
    app.picker.next = fakePhoto;
    final gate = app.adapter.gate = Completer<void>();

    await tester.tap(button('Izaberi iz galerije'));
    await tester.pump();
    await tester.pump();
    expect(find.bySemanticsLabel('Skeniranje fotografije'), findsOneWidget);
    expect(find.text('Tražim sastojke…'), findsOneWidget);
    // Slika već ima animaciju, pa nema i lonca.
    expect(find.bySemanticsLabel('Lonac koji krčka'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Tražim sastojke…'), findsNothing);
    expect(find.widgetWithText(Chip, 'crni luk'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'biber'), findsOneWidget);
  });

  testTavli('lista recepata: kartice sa bojama teme i varjača na povlačenje', (
    tester,
  ) async {
    await pumpTavli(
      tester,
      recipes: [sampleRecipe('1', 'Sarma'), sampleRecipe('2', 'Pasulj')],
    );
    final tints = TavliColors.of(tester.element(find.text('Sarma'))).tints
        .toSet();
    final boxes = tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(Card),
            matching: find.byType(ColoredBox),
          ),
        )
        .map((b) => b.color)
        .where(tints.contains);
    expect(boxes, hasLength(2));

    await tester.fling(find.text('Sarma'), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('Varjača u loncu'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Varjača u loncu'), findsNothing);
    expect(find.text('Sarma'), findsOneWidget);
  });
}
