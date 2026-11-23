import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:tavli/data/planning_tastes_remote.dart';
import 'package:tavli/domain/cuisine_preferences.dart';
import 'package:tavli/domain/planning_tastes.dart';
import 'package:tavli/domain/recipe_labels.dart';

const household = '11111111-1111-4111-8111-111111111111';
const fish = '33333333-3333-4333-8333-333333333333';

Map<String, Object?> body({
  List<String> disliked = const [fish],
  List<String> kinds = const ['soup', 'unknown_kind'],
  List<String> cuisines = const ['italian', 'klingon'],
}) => {
  'likedFoodIds': <String>[],
  'dislikedFoodIds': disliked,
  'likedDishKinds': <String>[],
  'dislikedDishKinds': kinds,
  'likedCuisineCodes': cuisines,
  'dislikedCuisineCodes': <String>[],
};

void main() {
  final sent = <Map<String, Object?>>[];
  var names = 0;

  RemotePlanningTastes remote(
    FutureOr<FunctionResponse> Function() answer, {
    String? home = household,
  }) => RemotePlanningTastes(
    householdId: () => home,
    timeout: const Duration(milliseconds: 50),
    foodNames: (h) async {
      names++;
      expect(h, household);
      return {fish: 'riba', 'other': 'drugo'};
    },
    invoke: (b) async {
      sent.add(b);
      return answer();
    },
  );

  setUp(() {
    sent.clear();
    names = 0;
  });

  test('šalje samo id domaćinstva i čita šest nizova', () async {
    final tastes = await remote(
      () => FunctionResponse(data: body(), status: 200),
    ).current();

    expect(sent, [
      {'householdId': household},
    ]);
    expect(tastes.dislikedFoodIds, {fish});
    expect(tastes.foodNames, {fish: 'riba'});
    // Nepoznata vrsta jela ili kuhinja se preskače.
    expect(tastes.dislikedDishKinds, {DishKind.soup});
    expect(tastes.likedCuisines, {Cuisine.italian});
  });

  test('bez namirnica u ukusima katalog se ne čita', () async {
    final tastes = await remote(
      () => FunctionResponse(data: body(disliked: const []), status: 200),
    ).current();
    expect(tastes.dislikedDishKinds, {DishKind.soup});
    expect(names, 0);
  });

  test('bez prijave nema poziva ni ukusa', () async {
    final tastes = await remote(
      () => throw StateError('ne sme'),
      home: null,
    ).current();
    expect(tastes.isEmpty, isTrue);
    expect(sent, isEmpty);
  });

  test('409 i 401 zaustavljaju plan', () async {
    for (final status in [401, 409]) {
      await expectLater(
        remote(() => throw FunctionException(status: status)).current(),
        throwsA(isA<PlanningTastesDenied>()),
      );
      await expectLater(
        remote(() => FunctionResponse(status: status)).current(),
        throwsA(isA<PlanningTastesDenied>()),
      );
    }
  });

  test('ostale greške su privremene: plan ide bez ukusa', () async {
    final failures = <FutureOr<FunctionResponse> Function()>[
      () => throw const FunctionException(status: 429),
      () => throw const FunctionException(status: 500),
      () => throw const FunctionException(status: 404),
      () => throw const SocketLikeError(),
      () => Completer<FunctionResponse>().future,
      () => const FunctionResponse(data: 'nije mapa', status: 200),
      () => FunctionResponse(
        data: {...body(), 'dislikedFoodIds': 'riba'},
        status: 200,
      ),
      () => const FunctionResponse(
        data: {'likedFoodIds': <String>[]},
        status: 200,
      ),
    ];
    for (final fail in failures) {
      await expectLater(
        remote(fail).current(),
        throwsA(isA<PlanningTastesUnavailable>()),
      );
    }
  });
}

class SocketLikeError implements Exception {
  const SocketLikeError();
}
