import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/features/recipes/recipes_screen.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../helpers/test_app.dart';

/// Stavka trake menija po nazivu, iz menija sa datim nazivom.
PlatformMenuItem menuItem(WidgetTester tester, String menu, String label) {
  final bar = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
  final top = bar.menus.whereType<PlatformMenu>().singleWhere(
    (m) => m.label == menu,
  );
  return [
    for (final group in top.menus.whereType<PlatformMenuItemGroup>())
      ...group.members,
  ].singleWhere((i) => i.label == label);
}

Future<void> choose(WidgetTester tester, String menu, String label) async {
  menuItem(tester, menu, label).onSelected!();
  await tester.pumpAndSettle();
}

void main() {
  testTavli('macOS: traka menija vodi na tabove, pretragu i novi recept', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await pumpTavli(tester, size: wide, location: '/pantry');

    expect(
      tester
          .widget<PlatformMenuBar>(find.byType(PlatformMenuBar))
          .menus
          .map((m) => m.label),
      ['Tavli', 'Uređivanje', 'Datoteka', 'Prikaz', 'Prozor'],
    );
    final plan =
        menuItem(tester, 'Prikaz', 'Plan').shortcut! as SingleActivator;
    expect(plan.trigger, LogicalKeyboardKey.digit2);
    expect(plan.meta, isTrue);

    await choose(tester, 'Prikaz', 'Recepti');
    expect(find.byType(RecipesScreen), findsOneWidget);

    await choose(tester, 'Prikaz', 'Pretraži recepte');
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TavliSearchField),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.focusNode.hasFocus, isTrue);

    await choose(tester, 'Prikaz', 'Ostava');
    await choose(tester, 'Datoteka', 'Novi recept');
    expect(find.byType(RecipesScreen), findsOneWidget);
    expect(find.text('Ručno'), findsWidgets);
  });

  testTavli('računar: desni klik na recept nudi Otvori i Izmeni', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await pumpTavli(
      tester,
      size: wide,
      recipes: [sampleRecipe('r1', 'Musaka')],
    );
    await tester.tap(find.text('Musaka'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Otvori'), findsOneWidget);
    await tester.tap(find.text('Izmeni'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipesScreen), findsNothing);
  });

  testTavli('telefon i Windows: bez trake menija', (tester) async {
    await pumpTavli(tester, size: wide, location: '/pantry');
    expect(find.byType(PlatformMenuBar), findsNothing);
  });
}
