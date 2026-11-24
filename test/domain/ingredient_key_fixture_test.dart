import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/shopping_sync.dart';

/// Isti primeri kao test servera (`plan_eligibility_test.ts`): server proverava
/// vezu sastojka sa namirnicom istim ključem naziva kao aplikacija (TRELLO-43).
void main() {
  test('ingredientKey se poklapa sa zajedničkim primerima servera', () {
    final fixture = jsonDecode(
      File('supabase/functions/planning-inputs/testdata/ingredient_keys.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final cases = (fixture['cases'] as List<dynamic>).cast<List<dynamic>>();
    expect(cases, isNotEmpty);
    for (final c in cases) {
      expect(ingredientKey(c[0] as String), c[1], reason: '${c[0]}');
    }
  });
}
