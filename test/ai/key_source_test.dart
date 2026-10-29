import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/key_store.dart';

void main() {
  test('sopstveni ključ ide pre ugrađenog', () async {
    final source = LayeredKeySource(
      InMemoryKeyStore({AIProvider.gemini: 'own'}),
      const BuiltInKeys({AIProvider.gemini: 'built'}),
    );

    final creds = await source.credentialsFor(AIProvider.gemini);

    expect(creds.map((c) => c.origin), [KeyOrigin.user, KeyOrigin.builtIn]);
    expect(creds.map((c) => c.value), ['own', 'built']);
  });

  test('prazne vrednosti se ignorišu', () async {
    final source = LayeredKeySource(
      InMemoryKeyStore({AIProvider.groq: '  '}),
      const BuiltInKeys({AIProvider.groq: ''}),
    );

    expect(await source.credentialsFor(AIProvider.groq), isEmpty);
    expect(
      const BuiltInKeys({AIProvider.groq: ''}).has(AIProvider.groq),
      false,
    );
  });

  test('samo ugrađeni ključ', () async {
    final source = LayeredKeySource(
      InMemoryKeyStore(),
      const BuiltInKeys({AIProvider.openRouter: 'built'}),
    );

    final creds = await source.credentialsFor(AIProvider.openRouter);

    expect(creds.single.origin, KeyOrigin.builtIn);
    expect(await source.credentialsFor(AIProvider.gemini), isEmpty);
  });

  test('ključ se ne pojavljuje u toString', () {
    const c = ApiCredential(AIProvider.gemini, 'tajna', KeyOrigin.builtIn);
    expect(c.toString(), isNot(contains('tajna')));
  });

  test('bez --dart-define nema ugrađenih ključeva', () {
    final keys = BuiltInKeys.fromEnvironment();
    for (final p in AIProvider.values) {
      expect(keys.has(p), false);
    }
  });
}
