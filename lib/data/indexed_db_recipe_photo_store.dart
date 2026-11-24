import 'dart:async';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:web/web.dart';

import 'recipe_photo_store.dart';

/// Slike recepata u IndexedDB-u pregledača (spec 036). Ključ je ista relativna
/// putanja kao na ostalim platformama, uz istu proveru putanje.
class IndexedDbRecipePhotoStore implements RecipePhotoStore {
  IndexedDbRecipePhotoStore([this._databaseName = 'tavli_recipe_photos']);

  final String _databaseName;
  final _random = Random();
  Future<IDBDatabase>? _database;

  static const _folder = 'recipe_photos';
  static const _objectStore = 'photos';

  Future<IDBDatabase> _open() => _database ??= () {
    final done = Completer<IDBDatabase>();
    final request = window.indexedDB.open(_databaseName, 1);
    request.onupgradeneeded = ((Event _) {
      (request.result! as IDBDatabase).createObjectStore(_objectStore);
    }).toJS;
    request.onsuccess = ((Event _) {
      done.complete(request.result! as IDBDatabase);
    }).toJS;
    request.onerror = ((Event _) {
      done.completeError(StateError('indexeddb_open_failed'));
    }).toJS;
    return done.future;
  }();

  Future<JSAny?> _run(
    String mode,
    IDBRequest Function(IDBObjectStore store) action,
  ) async {
    final db = await _open();
    final done = Completer<JSAny?>();
    final transaction = db.transaction(_objectStore.toJS, mode);
    final request = action(transaction.objectStore(_objectStore));
    request.onsuccess = ((Event _) => done.complete(request.result)).toJS;
    request.onerror = ((Event _) {
      done.completeError(StateError('indexeddb_request_failed'));
    }).toJS;
    return done.future;
  }

  @override
  Future<String> save(Uint8List jpeg) async {
    final name =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '${_random.nextInt(0x7fffffff).toRadixString(36)}.jpg';
    final relative = '$_folder/$name';
    await write(relative, jpeg);
    return relative;
  }

  @override
  Future<void> write(String relativePath, Uint8List jpeg) async {
    if (!isSafeRecipePhotoPath(relativePath)) {
      throw ArgumentError.value('<redacted>', 'relativePath', 'unsafe path');
    }
    await _run('readwrite', (store) => store.put(jpeg.toJS, relativePath.toJS));
  }

  @override
  Future<Uint8List?> read(String relativePath) async {
    if (!isSafeRecipePhotoPath(relativePath)) return null;
    final result = await _run(
      'readonly',
      (store) => store.get(relativePath.toJS),
    );
    return result == null ? null : (result as JSUint8Array).toDart;
  }

  @override
  Future<bool> exists(String relativePath) async =>
      await read(relativePath) != null;

  @override
  Future<void> delete(String relativePath) async {
    if (!isSafeRecipePhotoPath(relativePath)) return;
    await _run('readwrite', (store) => store.delete(relativePath.toJS));
  }
}
