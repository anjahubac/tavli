@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/data/indexed_db_recipe_photo_store.dart';

void main() {
  late IndexedDbRecipePhotoStore store;
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]);

  setUp(() {
    store = IndexedDbRecipePhotoStore(
      'test_photos_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  test('save, read, exists and delete round trip', () async {
    final path = await store.save(jpeg);
    expect(path, startsWith('recipe_photos/'));
    expect(await store.exists(path), isTrue);
    expect(await store.read(path), jpeg);
    await store.delete(path);
    expect(await store.exists(path), isFalse);
    expect(await store.read(path), isNull);
  });

  test('write places a downloaded photo at the given path', () async {
    await store.write('recipe_photos/server.jpg', jpeg);
    expect(await store.read('recipe_photos/server.jpg'), jpeg);
  });

  test('unsafe paths are rejected like on native platforms', () async {
    for (final path in [
      '../x.jpg',
      '/abs.jpg',
      'recipe_photos/../x.jpg',
      'recipe_photos/a/b.jpg',
      'other/x.jpg',
    ]) {
      expect(await store.read(path), isNull, reason: path);
      expect(await store.exists(path), isFalse, reason: path);
      await expectLater(store.write(path, jpeg), throwsArgumentError);
      await store.delete(path);
    }
  });
}
