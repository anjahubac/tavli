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
}
