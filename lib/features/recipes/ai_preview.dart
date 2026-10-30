import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/recipe.dart';
import 'recipe_view.dart';

/// Recept koji je AI napravio, pre čuvanja.
class AiRecipePreview extends StatelessWidget {
  const AiRecipePreview({
    super.key,
    required this.recipe,
    required this.onSave,
    required this.onRetry,
    required this.onDiscard,
    this.photoBytes,
    this.saving = false,
  });

  final Recipe recipe;
  final Uint8List? photoBytes;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ReadableScroll(
            children: [
              RecipeView(recipe, photoBytes: photoBytes, showTitle: true),
            ],
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: saving ? null : onDiscard,
                  child: const Text('Odbaci'),
                ),
                OutlinedButton.icon(
                  onPressed: saving ? null : onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Pokušaj ponovo'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: const Icon(Icons.check),
                  label: const Text('Sačuvaj'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Indikator dok AI radi.
class AiBusy extends StatelessWidget {
  const AiBusy(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}

/// Greška AI-ja sa dugmićima za sledeći korak.
class AiErrorBox extends StatelessWidget {
  const AiErrorBox(this.message, {super.key, required this.actions});

  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(color: colors.onErrorContainer)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    );
  }
}
