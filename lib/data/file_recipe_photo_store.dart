import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'recipe_photo_store.dart';

/// Slike recepata kao fajlovi u dokumentima aplikacije (sve platforme osim weba).
class FileRecipePhotoStore implements RecipePhotoStore {
  FileRecipePhotoStore(this._baseDir);

  final Future<Directory> Function() _baseDir;
  final _random = Random();

  static const _folder = 'recipe_photos';

  /// Fajl unutar osnovnog foldera ili null za nebezbednu putanju.
  Future<File?> _resolve(String relativePath) async {
    if (!isSafeRecipePhotoPath(relativePath)) return null;
    return File('${(await _baseDir()).path}/$relativePath');
  }

  @override
  Future<String> save(Uint8List jpeg) async {
    final name =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '${_random.nextInt(1 << 32).toRadixString(36)}.jpg';
    final relative = '$_folder/$name';
    final file = (await _resolve(relative))!;
    await file.parent.create(recursive: true);
    await file.writeAsBytes(jpeg, flush: true);
    return relative;
  }

  Future<File?> file(String relativePath) async {
    final f = await _resolve(relativePath);
    return f != null && await f.exists() ? f : null;
  }

  @override
  Future<void> delete(String relativePath) async {
    final f = await _resolve(relativePath);
    if (f != null && await f.exists()) await f.delete();
  }

  @override
  Future<bool> exists(String relativePath) async =>
      await (await _resolve(relativePath))?.exists() ?? false;

  @override
  Future<Uint8List?> read(String relativePath) async {
    final f = await _resolve(relativePath);
    return f != null && await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> write(String relativePath, Uint8List jpeg) async {
    final file = await _resolve(relativePath);
    if (file == null) {
      throw ArgumentError.value('<redacted>', 'relativePath', 'unsafe path');
    }
    await file.parent.create(recursive: true);
    await file.writeAsBytes(jpeg, flush: true);
  }
}
