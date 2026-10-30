import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tavli/data/photo_resize.dart';
import 'package:tavli/data/recipe_photo_store.dart';

Uint8List png(int w, int h) => img.encodePng(
  img.Image(width: w, height: h)..clear(img.ColorRgb8(200, 80, 40)),
);

void main() {
  test('velika slika se smanjuje na najviše 1600 px i postaje JPEG', () {
    final out = downscaleToJpeg(png(3200, 2000));
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 1000);
  });

  test('mala slika zadržava veličinu', () {
    final decoded = img.decodeJpg(downscaleToJpeg(png(800, 600)))!;
    expect((decoded.width, decoded.height), (800, 600));
  });

  test('uspravna slika se ograničava po visini', () {
    final decoded = img.decodeJpg(downscaleToJpeg(png(1000, 2000)))!;
    expect((decoded.width, decoded.height), (800, 1600));
  });

  test('nešto što nije slika baca FormatException', () {
    expect(
      () => downscaleToJpeg(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });

  group('skladište slika', () {
    late Directory dir;
    late FileRecipePhotoStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('tavli_photos');
      store = FileRecipePhotoStore(() async => dir);
    });
    tearDown(() => dir.delete(recursive: true));

    test('čuva, nalazi i briše sliku po relativnoj putanji', () async {
      final path = await store.save(Uint8List.fromList([1, 2, 3]));
      expect(path, startsWith('recipe_photos/'));
      expect(path, endsWith('.jpg'));

      final file = await store.file(path);
      expect(await file!.readAsBytes(), [1, 2, 3]);

      await store.delete(path);
      expect(await store.file(path), isNull);
    });

    test('nepostojeća slika daje null i brisanje ne puca', () async {
      expect(await store.file('recipe_photos/nema.jpg'), isNull);
      await store.delete('recipe_photos/nema.jpg');
    });
  });
}
