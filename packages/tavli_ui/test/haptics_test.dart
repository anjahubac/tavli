import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

void main() {
  for (final (p, expected) in [
    (TargetPlatform.iOS, 3),
    (TargetPlatform.android, 0),
    (TargetPlatform.macOS, 0),
  ]) {
    testWidgets('otkucaj pri štikliranju i izboru samo na iOS-u: ${p.name}', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') calls.add(call);
          return null;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTavliTheme(
            TavliMotif.bosiljak,
            Brightness.light,
          ).copyWith(platform: p),
          home: Scaffold(
            body: Column(
              children: [
                TavliCheckRow(
                  title: 'Mleko',
                  checked: false,
                  onChanged: (_) {},
                ),
                TavliChoice<int>.segmented(
                  options: const [
                    TavliOption(0, 'Nedelja'),
                    TavliOption(1, 'Mesec'),
                  ],
                  selected: 0,
                  onChanged: (_) {},
                ),
                TavliChoice<int>.chips(
                  options: const [
                    TavliOption(0, 'Ceo plan'),
                    TavliOption(1, 'Nedelja 1'),
                  ],
                  selected: 0,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.text('Nedelja')));
      await tester.tapAt(tester.getCenter(find.text('Ceo plan')));
      expect(calls, isEmpty);

      await tester.tap(find.text('Mleko'));
      await tester.tap(find.text('Mesec'));
      await tester.tap(find.text('Nedelja 1'));
      expect(calls.length, expected);
    });
  }
}
