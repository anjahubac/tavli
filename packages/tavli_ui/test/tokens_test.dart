import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

double radiusOf(ShapeBorder? shape) =>
    ((shape! as RoundedRectangleBorder).borderRadius as BorderRadius).topLeft.x;

void main() {
  test('razmaci sa platna', () {
    expect(
      [TavliSpacing.small, TavliSpacing.medium, TavliSpacing.large],
      [8, 14, 20],
    );
  });

  test('tema koristi radijuse iz standarda komponenti', () {
    final t = buildTavliTheme(TavliMotif.bosiljak, Brightness.light);
    expect(radiusOf(t.cardTheme.shape), TavliRadius.card);
    expect(
      radiusOf(t.filledButtonTheme.style!.shape!.resolve({})),
      TavliRadius.button,
    );
    expect(
      radiusOf(t.outlinedButtonTheme.style!.shape!.resolve({})),
      TavliRadius.field,
    );
    expect(
      radiusOf(t.textButtonTheme.style!.shape!.resolve({})),
      TavliRadius.compact,
    );
    expect(radiusOf(t.floatingActionButtonTheme.shape), TavliRadius.card);
    expect(radiusOf(t.listTileTheme.shape), TavliRadius.field);
    expect(radiusOf(t.dialogTheme.shape), TavliRadius.sheet);
    expect(radiusOf(t.bottomSheetTheme.shape), TavliRadius.sheet);
    expect(radiusOf(t.checkboxTheme.shape), TavliRadius.checkbox);
  });

  testWidgets('trajanja su nula kada sistem traži smanjeno kretanje', (
    tester,
  ) async {
    late Duration normal, reduced;
    Widget probe(bool disable, void Function(Duration) out) => MediaQuery(
      data: MediaQueryData(disableAnimations: disable),
      child: Builder(
        builder: (context) {
          out(TavliMotion.duration(context, TavliMotion.transition));
          return const SizedBox();
        },
      ),
    );
    await tester.pumpWidget(probe(false, (d) => normal = d));
    await tester.pumpWidget(probe(true, (d) => reduced = d));
    expect(normal, const Duration(milliseconds: 240));
    expect(reduced, Duration.zero);
  });
}
