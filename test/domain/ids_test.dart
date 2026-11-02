import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/ids.dart';

void main() {
  test('newId je UUID v4', () {
    final id = newId();
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('newId je jedinstven u 10 000 poziva', () {
    final ids = {for (var i = 0; i < 10000; i++) newId()};
    expect(ids, hasLength(10000));
  });
}
