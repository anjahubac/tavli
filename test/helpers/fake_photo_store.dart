import 'dart:io';
import 'dart:typed_data';

import 'package:tavli/data/recipe_photo_store.dart';

/// Slike u memoriji; `file` uvek vraća null (testovi ne čitaju disk).
class FakePhotoStore implements RecipePhotoStore {
  final saved = <String, Uint8List>{};
  var _n = 0;

  @override
  Future<String> save(Uint8List jpeg) async {
    final path = 'recipe_photos/p${_n++}.jpg';
    saved[path] = jpeg;
    return path;
  }

  @override
  Future<File?> file(String relativePath) async => null;

  @override
  Future<void> delete(String relativePath) async => saved.remove(relativePath);

  @override
  Future<Uint8List?> read(String relativePath) async => saved[relativePath];

  @override
  Future<void> write(String relativePath, Uint8List jpeg) async =>
      saved[relativePath] = jpeg;
}
