import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/chain_config.dart';
import 'package:tavli/ai/model_check.dart';

void main() {
  test('Gemini "models/" prefiks se ignoriše, model se broji jednom', () {
    final result = checkChainModels(ChainConfig.defaults, AIProvider.gemini, [
      'models/gemini-flash-latest',
      'models/gemini-2.0-flash',
    ]);

    final byModel = {for (final r in result) r.spec.model: r.listed};
    expect(byModel['gemini-flash-latest'], isTrue);
    expect(byModel['gemini-pro-latest'], isFalse);
    // Pro i Flash su i u lancu za slike i u lancu za tekst.
    expect(result.length, byModel.length);
  });

  test('vraća samo modele traženog provajdera', () {
    final result = checkChainModels(
      ChainConfig.defaults,
      AIProvider.groq,
      const [],
    );
    expect(result, isNotEmpty);
    expect(result.every((r) => r.spec.provider == AIProvider.groq), isTrue);
  });
}
