import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'recipe_providers.dart';

final _recipePhotoBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>(
      (ref, path) => ref.watch(recipePhotoStoreProvider).read(path),
    );

/// Slika iz IndexedDB-a pregledača (spec 036).
Widget recipePhotoImage(
  WidgetRef ref,
  String path, {
  required double width,
  required double? height,
  required int? cacheWidth,
  required Widget placeholder,
  required Widget loading,
}) => ref
    .watch(_recipePhotoBytesProvider(path))
    .when(
      data: (bytes) => bytes == null
          ? placeholder
          : Image.memory(
              bytes,
              width: width,
              height: height,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              errorBuilder: (_, _, _) => placeholder,
            ),
      loading: () => loading,
      error: (_, _) => placeholder,
    );
