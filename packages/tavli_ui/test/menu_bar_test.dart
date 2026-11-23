import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

PlatformMenuItem item(WidgetTester tester, String menu, String label) {
  final bar = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
  final top = bar.menus.whereType<PlatformMenu>().singleWhere(
    (m) => m.label == menu,
  );
  return [
    for (final g in top.menus.whereType<PlatformMenuItemGroup>()) ...g.members,
  ].singleWhere((i) => i.label == label);
}

Future<void> pump(WidgetTester tester, TargetPlatform platform, Widget child) =>
    tester.pumpWidget(
      MaterialApp(
        theme: buildTavliTheme(
          TavliMotif.bosiljak,
          Brightness.light,
        ).copyWith(platform: platform),
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('macOS: meni aplikacije, uređivanje, grupe i prozor', (
    tester,
  ) async {
    var opened = 0;
    var settings = 0;
    final text = TextEditingController(text: 'paradajz');
    await pump(
      tester,
      TargetPlatform.macOS,
      TavliMenuBar(
        onSettings: () => settings++,
        groups: [
          TavliMenuGroup('Prikaz', [
            TavliMenuCommand('Plan', onSelected: () => opened++),
          ]),
        ],
        child: TextField(controller: text, autofocus: true),
      ),
    );
    await tester.pump();
    final bar = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
    // Prozor ima samo sistemske stavke, koje postoje tek na pravom macOS-u.
    expect(bar.menus.map((m) => m.label), ['Tavli', 'Uređivanje', 'Prikaz']);

    item(tester, 'Tavli', 'Podešavanja…').onSelected!();
    item(tester, 'Prikaz', 'Plan').onSelected!();
    expect((settings, opened), (1, 1));

    // Prečica iz menija stiže do polja u fokusu.
    item(tester, 'Uređivanje', 'Izaberi sve').onSelected!();
    await tester.pump();
    expect(text.selection, const TextSelection(baseOffset: 0, extentOffset: 8));
  });

  for (final p in [TargetPlatform.iOS, TargetPlatform.windows]) {
    testWidgets('bez trake menija: ${p.name}', (tester) async {
      await pump(tester, p, const TavliMenuBar(child: Text('sadržaj')));
      expect(find.byType(PlatformMenuBar), findsNothing);
      expect(find.text('sadržaj'), findsOneWidget);
    });
  }

  for (final (p, opens) in [
    (TargetPlatform.macOS, true),
    (TargetPlatform.windows, true),
    (TargetPlatform.iOS, false),
  ]) {
    testWidgets('desni klik otvara meni samo na računaru: ${p.name}', (
      tester,
    ) async {
      var chosen = 0;
      await pump(
        tester,
        p,
        TavliContextMenu(
          actions: [TavliMenuAction('Izmeni', onSelected: () => chosen++)],
          child: const Text('Musaka'),
        ),
      );
      await tester.tap(find.text('Musaka'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text('Izmeni'), opens ? findsOneWidget : findsNothing);
      if (opens) {
        await tester.tap(find.text('Izmeni'));
        await tester.pumpAndSettle();
        expect(chosen, 1);
      }
    });
  }

  group('Windows: meni u naslovnoj traci', () {
    Widget frame({VoidCallback? settings, bool menus = true}) => TavliMenuBar(
      onSettings: settings,
      onAbout: () {},
      onQuit: () {},
      windowsMenus: menus,
      groups: [
        TavliMenuGroup('Datoteka', [
          TavliMenuCommand(
            'Novi recept',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyN,
              meta: true,
            ),
            onSelected: () {},
          ),
        ]),
      ],
      child: const TavliWindowFrame(child: Text('sadržaj')),
    );

    testWidgets('Datoteka, Uređivanje, Pomoć i Ctrl prečice', (tester) async {
      var settings = 0;
      await pump(
        tester,
        TargetPlatform.windows,
        frame(settings: () => settings++),
      );
      for (final label in ['Datoteka', 'Uređivanje', 'Pomoć']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(PlatformMenuBar), findsNothing);
      await tester.tap(find.text('Datoteka'));
      await tester.pumpAndSettle();
      expect(find.text('Novi recept'), findsOneWidget);
      expect(find.text('Podešavanja'), findsOneWidget);
      expect(find.text('Izlaz'), findsOneWidget);
      await tester.tap(find.text('Podešavanja'));
      await tester.pumpAndSettle();
      expect(settings, 1);
    });

    testWidgets('bez menija pre prijave, dugmad prozora ostaju', (
      tester,
    ) async {
      await pump(tester, TargetPlatform.windows, frame(menus: false));
      expect(find.text('Datoteka'), findsNothing);
      expect(find.bySemanticsLabel('Zatvori'), findsOneWidget);
    });

    testWidgets('prečica ⌘ postaje Ctrl', (tester) async {
      final groups = const TavliMenuBar(
        groups: [
          TavliMenuGroup('Datoteka', [
            TavliMenuCommand('Novi recept', onSelected: _noop),
          ]),
        ],
        child: SizedBox(),
      ).windowsGroups();
      expect(groups.map((g) => g.label), ['Datoteka', 'Uređivanje']);
    });
  });
}

void _noop() {}
