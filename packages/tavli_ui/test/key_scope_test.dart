import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

Widget app(TargetPlatform platform, Widget Function(BuildContext) build) =>
    MaterialApp(
      theme: buildTavliTheme(
        TavliMotif.bosiljak,
        Brightness.light,
      ).copyWith(platform: platform),
      home: Scaffold(body: Builder(builder: build)),
    );

void main() {
  testWidgets('oznaka prečice: ⌘ na macOS-u, Ctrl na Windows-u, ništa na '
      'telefonu', (tester) async {
    late String mac, win, phone;
    String hint(BuildContext c) =>
        tavliWithShortcut(c, 'Sledeća nedelja', '→', command: true);
    await tester.pumpWidget(
      app(TargetPlatform.macOS, (c) {
        mac = hint(c);
        return const SizedBox();
      }),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      app(TargetPlatform.windows, (c) {
        win = hint(c);
        return const SizedBox();
      }),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      app(TargetPlatform.android, (c) {
        phone = hint(c);
        return const SizedBox();
      }),
    );
    await tester.pumpAndSettle();
    expect(mac, 'Sledeća nedelja (⌘→)');
    expect(win, 'Sledeća nedelja (Ctrl+→)');
    expect(phone, 'Sledeća nedelja');
  });

  testWidgets('TavliKeyScope: Ctrl+strelica na Windows-u, polje zadržava '
      'svoje strelice', (tester) async {
    var next = 0;
    await tester.pumpWidget(
      app(
        TargetPlatform.windows,
        (c) => TavliKeyScope(
          bindings: {
            tavliShortcut(
              c,
              LogicalKeyboardKey.arrowRight,
              command: true,
            ): () =>
                next++,
          },
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(next, 0, reason: 'bez Ctrl ne radi');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(next, 1);
  });
}
