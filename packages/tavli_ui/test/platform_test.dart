import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

void main() {
  test('svaka ciljna platforma ima Tavli platformu', () {
    expect(
      TavliPlatform.fromTarget(TargetPlatform.android),
      TavliPlatform.android,
    );
    expect(
      TavliPlatform.fromTarget(TargetPlatform.fuchsia),
      TavliPlatform.android,
    );
    expect(TavliPlatform.fromTarget(TargetPlatform.iOS), TavliPlatform.ios);
    expect(TavliPlatform.fromTarget(TargetPlatform.macOS), TavliPlatform.macos);
    expect(
      TavliPlatform.fromTarget(TargetPlatform.windows),
      TavliPlatform.windows,
    );
    expect(
      TavliPlatform.fromTarget(TargetPlatform.linux),
      TavliPlatform.windows,
    );
  });

  test('računar i Apple', () {
    expect(TavliPlatform.values.where((p) => p.isDesktop), [
      TavliPlatform.macos,
      TavliPlatform.windows,
    ]);
    expect(TavliPlatform.values.where((p) => p.isApple), [
      TavliPlatform.ios,
      TavliPlatform.macos,
    ]);
  });

  testWidgets('platforma se čita iz teme, pa se može simulirati', (
    tester,
  ) async {
    late TavliPlatform seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTavliTheme(
          TavliMotif.bosiljak,
          Brightness.light,
        ).copyWith(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) {
            seen = TavliPlatform.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, TavliPlatform.ios);
  });
}
