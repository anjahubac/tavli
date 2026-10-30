# Contract: RecipeRepository

```dart
class RecipeRepository {
  RecipeRepository(AppDatabase db, RecipePhotoStore photos, {DateTime Function()? clock});

  Stream<List<Recipe>> watchAll();                 // newest first
  Stream<Recipe?> watch(String id);
  Future<Recipe?> get(String id);
  Future<void> create(Recipe recipe);
  Future<void> update(Recipe next, {required ChangeKind kind, String? instruction, String? changedBy});
  Stream<List<RecipeVersion>> watchVersions(String recipeId);   // newest first
  Future<bool> undoLast(String recipeId);          // false when no versions
  Future<void> restore(int versionId);
  Future<void> delete(String id);                  // + versions, photo
}

abstract class RecipePhotoStore {
  Future<String> save(Uint8List jpeg);             // returns relative path
  Future<File?> file(String relativePath);         // null when missing
  Future<void> delete(String relativePath);
}

abstract class PhotoPicker {
  bool get canUseCamera;
  Future<Uint8List?> pick({required bool camera}); // null when cancelled
}
```

`update`, `undoLast`, `restore` and `delete` each run in one transaction.
