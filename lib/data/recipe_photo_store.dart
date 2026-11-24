import 'dart:typed_data';

// Fajl varijanta (dart:io) postoji svuda osim na webu (spec 036).
export 'file_recipe_photo_store.dart'
    if (dart.library.js_interop) 'file_recipe_photo_store_web.dart';

/// Slike recepata na disku. U bazi se čuva relativna putanja jer se
/// putanja kontejnera na iOS-u menja posle ažuriranja aplikacije.
abstract class RecipePhotoStore {
  /// Čuva JPEG i vraća relativnu putanju.
  Future<String> save(Uint8List jpeg);

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
