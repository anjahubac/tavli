import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'from_photo_screen.dart';
import 'recipe_providers.dart';

/// Izbor načina dodavanja recepta.
Future<void> showAddRecipeSheet(BuildContext context) {
  final phone = isPhonePlatform(context);

  void open(BuildContext sheetContext, String path) {
    Navigator.of(sheetContext).pop();
    context.go(path);
  }

  // Na računaru se odmah otvara izbor slike, bez međuekrana.
  // Odustajanje ne menja ništa.
  Future<void> pickOnDesktop(BuildContext sheetContext) async {
    final picker = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(photoPickerProvider);
    Navigator.of(sheetContext).pop();
    final Uint8List? picked;
    try {
      picked = await picker.pick(camera: false);
    } on Exception catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(photoPickErrorText(e, camera: false))),
        );
      return;
    }
    if (picked == null || !context.mounted) return;
    context.go('/recipes/new/photo', extra: picked);
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              phone
                  ? Icons.photo_camera_outlined
                  : Icons.photo_library_outlined,
            ),
            title: const Text('Sa slike'),
            subtitle: Text(
              phone
                  ? 'Slikaj ili izaberi sliku recepta'
                  : 'Izaberi sliku recepta',
            ),
            onTap: () => phone
                ? open(sheetContext, '/recipes/new/photo')
                : pickOnDesktop(sheetContext),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Po nazivu jela'),
            subtitle: const Text('AI pravi recept za jelo koje upišeš'),
            onTap: () => open(sheetContext, '/recipes/new/name'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Ručno'),
            subtitle: const Text('Upiši recept sam'),
            onTap: () => open(sheetContext, '/recipes/new/manual'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
