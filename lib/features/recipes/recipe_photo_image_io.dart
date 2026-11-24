import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/recipe_photo_store.dart';
import 'recipe_providers.dart';

final _recipePhotoFileProvider = FutureProvider.autoDispose
    .family<File?, String>((ref, path) async {
      final store = ref.watch(recipePhotoStoreProvider);
      return store is FileRecipePhotoStore ? store.file(path) : null;
    });

/// Slika iz fajla (sve platforme osim weba).
Widget recipePhotoImage(
  WidgetRef ref,
  String path, {
  required double width,
  required double? height,
  required int? cacheWidth,
  required Widget placeholder,
  required Widget loading,
}) => ref
    .watch(_recipePhotoFileProvider(path))
    .when(
      data: (file) => file == null
          ? placeholder
          : Image.file(
              file,
              width: width,
              height: height,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              errorBuilder: (_, _, _) => placeholder,
            ),
      loading: () => loading,
      error: (_, _) => placeholder,
    );
