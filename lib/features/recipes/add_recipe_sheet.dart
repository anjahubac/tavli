import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

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
      showTavliMessage(context, photoPickErrorText(e, camera: false));
      return;
    }
    if (picked == null || !context.mounted) return;
    context.go('/recipes/new/photo', extra: picked);
  }

  return showTavliSheet<void>(
    context,
    builder: (sheetContext) => TavliListGroup(
      children: [
        TavliListRow(
          leading: Icon(
            phone ? Icons.photo_camera_outlined : Icons.photo_library_outlined,
          ),
          title: 'Sa slike',
          subtitle: phone
              ? 'Slikaj ili izaberi sliku recepta'
              : 'Izaberi sliku recepta',
          showChevron: true,
          onTap: () => phone
              ? open(sheetContext, '/recipes/new/photo')
              : pickOnDesktop(sheetContext),
        ),
        TavliListRow(
          leading: const Icon(Icons.auto_awesome_outlined),
          title: 'Po nazivu jela',
          subtitle: 'AI pravi recept za jelo koje upišeš',
          showChevron: true,
          onTap: () => open(sheetContext, '/recipes/new/name'),
        ),
        TavliListRow(
          leading: const Icon(Icons.mic_none),
          title: 'Glasom',
          subtitle: 'Izgovori recept, AI ga upisuje',
          showChevron: true,
          onTap: () => open(sheetContext, '/recipes/new/voice'),
        ),
        TavliListRow(
          leading: const Icon(Icons.edit_note),
          title: 'Ručno',
          subtitle: 'Upiši recept sam',
          showChevron: true,
          onTap: () => open(sheetContext, '/recipes/new/manual'),
        ),
      ],
    ),
  );
}
