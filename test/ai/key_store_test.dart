import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/key_store.dart';

class MapSecretStorage implements SecretStorage {
  final data = <String, String>{};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}

void main() {
  test('servis se prepoznaje po početku ključa', () {
    expect(detectProvider('AIzaSyFAKE'), AIProvider.gemini);
    expect(detectProvider('  gsk_fake'), AIProvider.groq);
    expect(detectProvider('sk-or-v1-fake'), AIProvider.openRouter);
    expect(detectProvider('sk-proj-fake'), isNull);
    expect(detectProvider(''), isNull);
  });

  test('prikaz ključa: samo poslednja 4 znaka', () {
    final k = StoredKey(
      id: '1',
      provider: AIProvider.groq,
      value: 'gsk_fake-1234',
      addedAt: DateTime(2026),
    );
    expect(k.masked, '••••1234');
    expect(k.toString(), isNot(contains('gsk_fake')));
  });

  group('sigurno skladište', () {
    late MapSecretStorage storage;
    late SecureKeyStore store;
    var n = 0;

    setUp(() {
      storage = MapSecretStorage();
      store = SecureKeyStore(
        storage: storage,
        clock: () => DateTime.utc(2026, 10, 30),
        newId: () => 'id${n++}',
      );
    });

    test('dodaje više ključeva, redom, i briše po id-ju', () async {
      final a = await store.add(AIProvider.gemini, ' AIza-one \n');
      await store.add(AIProvider.gemini, 'AIza-two');
      await store.add(AIProvider.groq, 'gsk_one');

      final keys = await store.list();
      expect(keys.map((k) => k.value), ['AIza-one', 'AIza-two', 'gsk_one']);
      expect(keys.first.addedAt, DateTime.utc(2026, 10, 30));

      await store.remove(a.id);
      expect((await store.list()).map((k) => k.value), ['AIza-two', 'gsk_one']);
    });

    test('isti ključ se ne dodaje dva puta', () async {
      await store.add(AIProvider.groq, 'gsk_one');
      expect(
        () => store.add(AIProvider.groq, ' gsk_one'),
        throwsA(isA<DuplicateKeyException>()),
      );
    });

    test('stari ključ (jedan po servisu) prelazi u listu jednom', () async {
      storage.data['api_key_gemini'] = 'AIza-legacy';
      storage.data['api_key_groq'] = '  ';

      final keys = await store.list();
      expect(keys.single.value, 'AIza-legacy');
      expect(keys.single.provider, AIProvider.gemini);
      expect(storage.data.containsKey('api_key_gemini'), isFalse);
      expect(storage.data.containsKey('api_key_groq'), isFalse);

      expect(await store.list(), hasLength(1));
      final saved = jsonDecode(storage.data['api_keys']!) as List<dynamic>;
      expect(saved, hasLength(1));
    });
  });

  test('InMemoryKeyStore radi isto', () async {
    final store = InMemoryKeyStore({AIProvider.gemini: 'g'});
    expect((await store.list()).single.id, 'gemini');
    await store.add(AIProvider.gemini, 'g2');
    expect((await store.list()).map((k) => k.value), ['g', 'g2']);
    await store.remove('gemini');
    expect((await store.list()).single.value, 'g2');
  });
}
