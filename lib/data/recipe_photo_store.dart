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

  Future<bool> exists(String relativePath);

  /// Sadržaj slike (za slanje na server) ili null ako je nema.
  Future<Uint8List?> read(String relativePath);

  /// Upisuje sliku preuzetu sa servera na datu relativnu putanju.
  Future<void> write(String relativePath, Uint8List jpeg);
}

/// Jedini oblik relativne putanje slike: `recipe_photos/<ime>`, gde ime nema
/// separator, ne počinje tačkom i sastoji se od slova, cifara, `.`, `_`, `-`.
final _safePhotoPath = RegExp(
  r'^recipe_photos/[A-Za-z0-9][A-Za-z0-9._-]{0,127}$',
);

/// SEC-02: putanja stiže i iz sinhronizovanih zapisa, pa se proverava pre
/// svake operacije nad fajlom (bez `..`, apsolutnih putanja i podfoldera).
bool isSafeRecipePhotoPath(String relativePath) =>
    _safePhotoPath.hasMatch(relativePath) && !relativePath.contains('..');

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

  @override
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
