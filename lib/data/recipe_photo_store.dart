import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Slike recepata na disku. U bazi se čuva relativna putanja jer se
/// putanja kontejnera na iOS-u menja posle ažuriranja aplikacije.
abstract class RecipePhotoStore {
  /// Čuva JPEG i vraća relativnu putanju.
  Future<String> save(Uint8List jpeg);

  /// Fajl slike ili null ako ga nema.
  Future<File?> file(String relativePath);

  Future<void> delete(String relativePath);
}

class FileRecipePhotoStore implements RecipePhotoStore {
  FileRecipePhotoStore(this._baseDir);

  final Future<Directory> Function() _baseDir;
  final _random = Random();

  static const _folder = 'recipe_photos';

  Future<File> _resolve(String relativePath) async =>
      File('${(await _baseDir()).path}/$relativePath');

  @override
  Future<String> save(Uint8List jpeg) async {
    final name =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '${_random.nextInt(1 << 32).toRadixString(36)}.jpg';
    final relative = '$_folder/$name';
    final file = await _resolve(relative);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(jpeg, flush: true);
    return relative;
  }

  @override
  Future<File?> file(String relativePath) async {
    final f = await _resolve(relativePath);
    return await f.exists() ? f : null;
  }

  @override
  Future<void> delete(String relativePath) async {
    final f = await _resolve(relativePath);
    if (await f.exists()) await f.delete();
  }
}
