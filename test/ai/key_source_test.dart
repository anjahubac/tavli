import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/key_store.dart';

void main() {
  test('više sopstvenih ključeva istog servisa, redom dodavanja', () async {
    final own = InMemoryKeyStore({AIProvider.gemini: 'own1'});
    await own.add(AIProvider.groq, 'groq');
    await own.add(AIProvider.gemini, 'own2');
    final source = OwnKeySource(own);

    final creds = await source.credentialsFor(AIProvider.gemini);

    expect(creds.map((c) => c.value), ['own1', 'own2']);
    expect(creds.map((c) => c.origin).toSet(), {KeyOrigin.user});
    expect(creds.first.keyId, 'gemini');
    expect(creds.map((c) => c.slot).toSet(), hasLength(2));
  });

  test('prazne vrednosti se ignorišu, razmaci se skidaju', () async {
    final source = OwnKeySource(
      InMemoryKeyStore({AIProvider.groq: '  ', AIProvider.openAI: ' own '}),
    );

    expect(await source.credentialsFor(AIProvider.groq), isEmpty);
    expect(await source.credentialsFor(AIProvider.gemini), isEmpty);
    final openAI = await source.credentialsFor(AIProvider.openAI);
    expect(openAI.single.value, 'own');
  });

  test('ključ se ne pojavljuje u toString', () {
    const c = ApiCredential(AIProvider.gemini, 'tajna', KeyOrigin.user);
    expect(c.toString(), isNot(contains('tajna')));
  });

  test('gateway koristi oznaku zajedničkog pristupa bez ključa', () {
    const credential = ApiCredential.gateway(AIProvider.gemini);
    expect(credential.value, isNull);
    expect(credential.origin, KeyOrigin.builtIn);
  });
}
