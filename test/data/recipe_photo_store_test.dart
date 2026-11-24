import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/data/recipe_photo_store.dart';

/// SEC-02: relativna putanja slike stiže i iz sinhronizovanih zapisa, pa
/// operacije nad fajlovima ostaju u `recipe_photos/` ispod osnovnog foldera.
void main() {
  late Directory root;
  late Directory base;
  late File canary;
  late FileRecipePhotoStore store;
  final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);

  setUp(() {
    root = Directory.systemTemp.createTempSync('photo_store_');
    base = Directory('${root.path}/app')..createSync();
    canary = File('${root.path}/canary.jpg')..writeAsBytesSync([42]);
    File('${base.path}/outside.jpg').writeAsBytesSync([7]);
    store = FileRecipePhotoStore(() async => base);
  });
  tearDown(() => root.deleteSync(recursive: true));

  const unsafe = [
    '../canary.jpg',
    'recipe_photos/../../canary.jpg',
    'recipe_photos/../outside.jpg',
    'outside.jpg',
    'recipe_photos/a/b.jpg',
    'recipe_photos/.hidden.jpg',
    'recipe_photos/',
    'recipe_photos/..',
    'recipe_photos\\..\\..\\canary.jpg',
    '/etc/passwd',
    '',
  ];

  test(
    'nebezbedna putanja ne čita, ne briše i ne upisuje van foldera',
    () async {
      for (final path in unsafe) {
        expect(isSafeRecipePhotoPath(path), isFalse, reason: path);
        expect(await store.exists(path), isFalse, reason: path);
        expect(await store.file(path), isNull, reason: path);
        expect(await store.read(path), isNull, reason: path);
        await store.delete(path);
        await expectLater(
          store.write(path, jpeg),
          throwsArgumentError,
          reason: path,
        );
      }
      expect(canary.readAsBytesSync(), [42]);
      expect(File('${base.path}/outside.jpg').readAsBytesSync(), [7]);
    },
  );

  test('ispravne putanje rade kao i do sada', () async {
    final saved = await store.save(jpeg);
    expect(isSafeRecipePhotoPath(saved), isTrue);
    expect(await store.read(saved), jpeg);

    const downloaded =
        'recipe_photos/ai_0b3a5c1e-2f4d-4a6b-8c9d-1e2f3a4b5c6d.jpg';
    expect(isSafeRecipePhotoPath(downloaded), isTrue);
    await store.write(downloaded, jpeg);
    expect(await store.exists(downloaded), isTrue);
    await store.delete(downloaded);
    expect(await store.exists(downloaded), isFalse);
  });
}
