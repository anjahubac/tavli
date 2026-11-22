import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  testTavli('macOS: prečice čekaju da se zatvore panel i dijalog', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await pumpTavli(tester, size: wide);

    final newRecipe = menuItem(tester, 'Datoteka', 'Novi recept').onSelected!;
    newRecipe();
    newRecipe();
    await tester.pumpAndSettle();
    expect(find.text('Ručno', skipOffstage: false), findsOneWidget);
    await choose(tester, 'Datoteka', 'Novi recept');
    await choose(tester, 'Prikaz', 'Ostava');
    expect(currentTab(tester), 'Recepti');
    expect(find.text('Ručno', skipOffstage: false), findsOneWidget);
    Navigator.of(tester.element(find.text('Ručno'))).pop();
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(RecipesScreen));
    final dialog = showTavliDialog<void>(
      context,
      title: 'Potvrda',
      actions: const [],
    );
    await tester.pumpAndSettle();
    await choose(tester, 'Prikaz', 'Pretraži recepte');
    await choose(tester, 'Tavli', 'Podešavanja…');
    await choose(tester, 'Prikaz', 'Ostava');
    expect(currentTab(tester), 'Recepti');
    expect(find.text('Potvrda'), findsOneWidget);
    Navigator.of(tester.element(find.text('Potvrda'))).pop();
    await tester.pumpAndSettle();
    await dialog;

    await choose(tester, 'Prikaz', 'Ostava');
    expect(currentTab(tester), 'Ostava');
  });

  testTavli('macOS: prečica za podešavanja ostaje na otvorenom podekranu', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await pumpTavli(tester, size: wide, location: '/profile/appearance');

    final router = GoRouter.of(tester.element(find.text('Izgled').first));
    await choose(tester, 'Tavli', 'Podešavanja…');
    expect(router.state.uri.path, '/profile/appearance');
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/profile');
  });

  testTavli('macOS: ceo ekran uklanja prostor za semafore u oba rasporeda', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('tavli/macos_window');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'isFullScreen');
      return true;
    });
    tester.view.padding = const FakeViewPadding(top: 18);
    tester.view.viewPadding = const FakeViewPadding(top: 18);
    await pumpTavli(tester);

    double recipeTopInset() =>
        MediaQuery.paddingOf(tester.element(find.byType(RecipesScreen))).top;
    Future<void> changeFullScreen(bool value) async {
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall('fullScreenChanged', value)),
        null,
      );
      await tester.pumpAndSettle();
    }

    expect(recipeTopInset(), 18);
    await changeFullScreen(false);
    expect(recipeTopInset(), TavliWindowFrame.macosTitleBarHeight);

    tester.view.physicalSize = wide;
    await tester.pumpAndSettle();
    final homeLabel = find.descendant(
      of: find.byType(TavliNavigation),
      matching: find.text('Početna'),
    );
    final windowedLabelTop = tester.getTopLeft(homeLabel).dy;
    await changeFullScreen(true);
    expect(recipeTopInset(), 18);
    expect(tester.getTopLeft(homeLabel).dy, lessThan(windowedLabelTop));
    expect(currentTab(tester), 'Recepti');
    await changeFullScreen(false);
    expect(tester.getTopLeft(homeLabel).dy, windowedLabelTop);
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

  testTavli('macOS: link iz mejla izbacuje prozor ispred pregledača', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('tavli/macos_window');
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return call.method == 'isFullScreen' ? false : null;
    });
    final app = await pumpTavli(tester, signedIn: false, size: wide);
    expect(calls, isNot(contains('activate')));

    app.links.add(Uri.parse('tavli://auth-callback?code=iskoriscen'));
    await tester.pumpAndSettle();
    expect(calls, contains('activate'));
  });
}
