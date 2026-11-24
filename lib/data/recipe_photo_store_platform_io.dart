import 'package:path_provider/path_provider.dart';

import 'recipe_photo_store.dart';

/// Fajlovi u dokumentima aplikacije (sve platforme osim weba).
RecipePhotoStore createRecipePhotoStore() =>
    FileRecipePhotoStore(getApplicationDocumentsDirectory);
