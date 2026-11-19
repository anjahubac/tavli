import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli_ui/tavli_ui.dart';

void main() {
  const twice = TavliTextScaler(TextScaler.linear(2));

  test('obični tekst dobija puno uvećanje', () {
    expect(twice.scale(14), 28);
    expect(twice.scale(16), 32);
  });

  test('veliki naslov raste najviše 1,5×', () {
    expect(twice.scale(28), 42);
    expect(twice.scale(36), 54);
  });

  test('između raste postepeno i nikad ne ide unazad', () {
    for (final factor in [1.3, 2.0, 3.0, 4.0]) {
      final scaler = TavliTextScaler(TextScaler.linear(factor));
      var previous = 0.0;
      for (var size = 10.0; size <= 60; size += 0.5) {
        final scaled = scaler.scale(size);
        expect(scaled, greaterThanOrEqualTo(previous), reason: '$factor×');
        previous = scaled;
      }
    }
  });

  test('bez uvećanja ili do 1,5× ništa se ne menja', () {
    for (final factor in [1.0, 1.5]) {
      final scaler = TavliTextScaler(TextScaler.linear(factor));
      expect(scaler.scale(32), 32 * factor);
    }
  });

  testWidgets('TavliTextScaling menja uvećanje za ceo podstablo', (
    tester,
  ) async {
    late TextScaler seen;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: TavliTextScaling(
          child: Builder(
            builder: (context) {
              seen = MediaQuery.textScalerOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(seen, isA<TavliTextScaler>());
    expect(seen.scale(16), 32);
    expect(seen.scale(28), 42);
  });
}
