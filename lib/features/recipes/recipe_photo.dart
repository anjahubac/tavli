import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recipe_providers.dart';

/// Sačuvana slika recepta; kad fajla nema, prikazuje ikonicu.
class RecipePhoto extends ConsumerWidget {
  const RecipePhoto(this.path, {super.key, this.size, this.height});

  final String path;

  /// Kvadratna sličica (lista) ili [height] za punu širinu (detalji).
  final double? size;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = size;
    final h = size ?? height;
    final cacheWidth = width == null
        ? null
        : (width * MediaQuery.devicePixelRatioOf(context)).round();
    final placeholder = SizedBox(
      width: width,
      height: h,
      child: Icon(
        Icons.restaurant_menu,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
    return Semantics(
      label: 'Slika recepta',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size == null ? 12 : 8),
        child: ref
            .watch(recipePhotoFileProvider(path))
            .when(
              data: (file) => file == null
                  ? placeholder
                  : Image.file(
                      file,
                      width: width ?? double.infinity,
                      height: h,
                      fit: BoxFit.cover,
                      cacheWidth: cacheWidth,
                      errorBuilder: (_, _, _) => placeholder,
                    ),
              loading: () => SizedBox(width: width, height: h),
              error: (_, _) => placeholder,
            ),
      ),
    );
  }
}
