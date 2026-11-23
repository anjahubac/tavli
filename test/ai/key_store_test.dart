import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:win32/win32.dart' as win32;

class MapSecretStorage implements SecretStorage {
  final data = <String, String>{};
  final reads = <String>[];

  /// Zapisi kojima sistem odbija pristup.
  final denied = <String>{};

  /// Upis i brisanje padaju.
  bool readOnly = false;

  @override
  Future<String?> read(String key) async {
    reads.add(key);
    if (denied.contains(key)) throw const SecretStorageException('-25293');
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (readOnly) throw const SecretStorageException('-25308');
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (readOnly) throw const SecretStorageException('-25308');
    data.remove(key);
  }
}

void main() {
  group('KeychainSecretStorage.guard', () {
    Future<SecretStorageException> failure(Exception error) async {
      try {
        await KeychainSecretStorage.guard<void>(() async => throw error);
      } on SecretStorageException catch (e) {
        return e;
      }
      fail('greška nije pretvorena u SecretStorageException');
    }

    test('PlatformException (Keychain, Keystore, libsecret)', () async {
      final e = await failure(PlatformException(code: '-25293'));
      expect(e.code, '-25293');
    });

    test('WindowsException iz CryptProtectData', () async {
      final e = await failure(
        win32.WindowsException(
          win32.ERROR_ACCESS_DENIED.toHRESULT(),
          message: 'C:\\Users\\ana',
        ),
      );
      expect(e.code, 'windows:0x80070005');
      expect(e.toString(), isNot(contains('ana')));
    });

    test('FileSystemException pri pisanju fajla', () async {
      final e = await failure(
        const FileSystemException(
          'Cannot create file',
          'C:\\Users\\ana\\flutter_secure_storage.dat',
          OSError('Access is denied.', 5),
        ),
      );
      expect(e.code, 'fs:5');
      expect(e.toString(), isNot(contains('ana')));
    });

    test('ostale greške prolaze neizmenjene', () async {
      await expectLater(
        KeychainSecretStorage.guard<void>(
          () async => throw const FormatException('x'),
        ),
        throwsFormatException,
      );
    });
  });

  test('servis se prepoznaje po početku ključa', () {
    expect(detectProvider('AIzaSyFAKE'), AIProvider.gemini);
    expect(detectProvider('  gsk_fake'), AIProvider.groq);
    expect(detectProvider('sk-or-v1-fake'), AIProvider.openRouter);
    expect(detectProvider('sk-fake'), AIProvider.openAI);
    expect(detectProvider('sk-proj-fake'), AIProvider.openAI);
    // `sk-or-` je duži početak od `sk-`.
    expect(detectProvider('sk-or-'), AIProvider.openRouter);
    expect(detectProvider('sk-org-fake'), AIProvider.openAI);
  });

  test('nepoznat ili nepodržan ključ nema servis', () {
    for (final key in ['sk-ant-api03-fake', 'nepoznat', 'sk', '', '   ']) {
      expect(detectProvider(key), isNull, reason: key);
    }
  });

  test('samo OpenAI je plaćen, svi servisi primaju sopstveni ključ', () {
    expect(AIProvider.values.where((p) => p.paid), [AIProvider.openAI]);
    expect(AIProvider.values.every((p) => p.supportsPersonalKey), isTrue);
    expect(AIProvider.openAI.baseUrl, 'https://api.openai.com/v1/');
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

    test('odbijen pristup starom ključu ne ruši listu', () async {
      storage.data['api_key_gemini'] = 'AIza-old';
      storage.denied.add('api_key_gemini');
      storage.data['api_key_groq'] = 'gsk_old';

      final keys = await store.list();

      expect(keys.single.value, 'gsk_old');
      expect(storage.data.containsKey('api_keys'), isTrue);
    });

    test('postojeća lista: jedno čitanje, bez starih zapisa', () async {
      storage.data['api_keys'] = '[]';

      await store.list();

      expect(storage.reads, ['api_keys']);
    });

    group('pamćenje u memoriji', () {
      test('drugo čitanje ne dira skladište', () async {
        final first = await store.list();
        storage.reads.clear();

        expect(await store.list(), first);
        expect(storage.reads, isEmpty);
      });

      test('dodavanje, brisanje i clear osvežavaju zapamćenu listu', () async {
        await store.list();
        storage.reads.clear();

        final a = await store.add(AIProvider.openAI, 'sk-one');
        await store.add(AIProvider.groq, 'gsk_two');
        expect((await store.list()).map((k) => k.value), ['sk-one', 'gsk_two']);

        await store.remove(a.id);
        expect((await store.list()).single.value, 'gsk_two');

        await store.clear();
        expect(await store.list(), isEmpty);
        expect(storage.reads, isEmpty);
      });

      test('zapamćena lista je ista kao sačuvana', () async {
        await store.add(AIProvider.openAI, 'sk-one');

        final fresh = SecureKeyStore(storage: storage);

        expect((await fresh.list()).single.value, 'sk-one');
      });

      test('odbijeno čitanje se ne pamti', () async {
        await store.add(AIProvider.groq, 'gsk_one');
        final fresh = SecureKeyStore(storage: storage);
        storage.denied.add('api_keys');
        await expectLater(fresh.list(), throwsA(isA<SecretStorageException>()));

        storage.denied.clear();

        expect((await fresh.list()).single.value, 'gsk_one');
      });

      test('neuspeo upis ne menja listu, sledeći put se čita', () async {
        await store.add(AIProvider.groq, 'gsk_one');
        storage
          ..readOnly = true
          ..reads.clear();
        await expectLater(
          store.add(AIProvider.groq, 'gsk_two'),
          throwsA(isA<SecretStorageException>()),
        );

        expect((await store.list()).single.value, 'gsk_one');
        expect(storage.reads, ['api_keys']);
      });

      test('spolja se ne može menjati', () async {
        await store.add(AIProvider.groq, 'gsk_one');
        final keys = await store.list();
        expect(keys.clear, throwsUnsupportedError);
      });
    });

    test('clear briše sve sopstvene ključeve, a sesiju ostavlja', () async {
      await store.add(AIProvider.gemini, 'AIza-one');
      storage.data['api_key_groq'] = 'gsk_stari';
      storage.data['auth_session'] = '{"fake":true}';
      await store.clear();
      expect(storage.data.keys, ['auth_session']);
      expect(await store.list(), isEmpty);
    });

    test('pokvaren zapis liste daje praznu listu, ne grešku', () async {
      storage.data['api_keys'] = 'nije json';
      expect(await store.list(), isEmpty);
    });
  });

  test('InMemoryKeyStore radi isto', () async {
    final store = InMemoryKeyStore({AIProvider.gemini: 'g'});
    expect((await store.list()).single.id, 'gemini');
    await store.add(AIProvider.gemini, 'g2');
    expect((await store.list()).map((k) => k.value), ['g', 'g2']);
    await store.remove('gemini');
    expect((await store.list()).single.value, 'g2');
    await store.clear();
    expect(await store.list(), isEmpty);
  });
}
