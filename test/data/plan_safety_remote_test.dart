import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:tavli/data/planning_tastes_remote.dart';
import 'package:tavli/domain/plan_safety.dart';
import 'package:tavli/domain/planning_tastes.dart';

const household = '11111111-1111-4111-8111-111111111111';

void main() {
  final sent = <Map<String, Object?>>[];

  RemotePlanSafety remote(
    FutureOr<FunctionResponse> Function() answer, {
    String? home = household,
  }) => RemotePlanSafety(
    householdId: () => home,
    timeout: const Duration(milliseconds: 50),
    invoke: (b) async {
      sent.add(b);
      return answer();
    },
  );

  setUp(sent.clear);

  test('šalje domaćinstvo i recepte, čita bezbedne', () async {
    final safety = await remote(
      () => const FunctionResponse(
        data: {
          'restricted': true,
          'safeRecipeIds': ['a'],
        },
        status: 200,
      ),
    ).check({'b', 'a'});

    expect(sent, [
      {
        'householdId': household,
        'recipeIds': ['a', 'b'],
      },
    ]);
    expect(safety.restricted, isTrue);
    expect(safety.allows('a'), isTrue);
    expect(safety.allows('b'), isFalse);
  });

  test('bez alergija sve je dozvoljeno', () async {
    final safety = await remote(
      () => const FunctionResponse(data: {'restricted': false}, status: 200),
    ).check({'a'});
    expect(safety.restricted, isFalse);
    expect(safety.allows('bilo-koji'), isTrue);
  });

  test('bez domaćinstva nema ograničenja ni poziva', () async {
    final safety = await remote(
      () => throw StateError('ne zove se'),
      home: null,
    ).check({'a'});
    expect(safety.restricted, isFalse);
    expect(sent, isEmpty);
  });

  test(
    'odbijanje zaustavlja plan, ostalo znači da provera nije moguća',
    () async {
      for (final status in [401, 409]) {
        await expectLater(
          remote(() => throw FunctionException(status: status)).check({'a'}),
          throwsA(isA<PlanningTastesDenied>()),
        );
      }
      for (final answer in <FutureOr<FunctionResponse> Function()>[
        () => throw const FunctionException(status: 429),
        () => throw const FunctionException(status: 500),
        () => Completer<FunctionResponse>().future, // istek vremena
        () => const FunctionResponse(data: 'x', status: 200),
        () => const FunctionResponse(data: {'restricted': true}, status: 200),
        () => const FunctionResponse(data: {'restricted': 'da'}, status: 200),
        // Server ne sme da vrati recept koji nismo pitali.
        () => const FunctionResponse(
          data: {
            'restricted': true,
            'safeRecipeIds': ['tudji'],
          },
          status: 200,
        ),
      ]) {
        await expectLater(
          remote(answer).check({'a'}),
          throwsA(isA<PlanSafetyUnavailable>()),
        );
      }
    },
  );
}
