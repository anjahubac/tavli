import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/recipe_format.dart';

void main() {
  test('ratingCountLabel pluralizes in Serbian', () {
    expect(ratingCountLabel(1), '1 ocena');
    expect(ratingCountLabel(2), '2 ocene');
    expect(ratingCountLabel(4), '4 ocene');
    expect(ratingCountLabel(5), '5 ocena');
    expect(ratingCountLabel(11), '11 ocena');
    expect(ratingCountLabel(12), '12 ocena');
    expect(ratingCountLabel(21), '21 ocena');
    expect(ratingCountLabel(22), '22 ocene');
  });

  test('ratingAverageLabel uses one decimal and a comma', () {
    expect(ratingAverageLabel(4.3333), '4,3');
    expect(ratingAverageLabel(5), '5,0');
  });
}
