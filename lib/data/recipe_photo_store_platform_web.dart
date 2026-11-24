import 'indexed_db_recipe_photo_store.dart';
import 'recipe_photo_store.dart';

/// IndexedDB pregledača (spec 036).
RecipePhotoStore createRecipePhotoStore() => IndexedDbRecipePhotoStore();
