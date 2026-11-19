import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// Naslov i sadržaj jednog odeljka galerije.
class GallerySection extends StatelessWidget {
  const GallerySection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TavliSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: TavliSpacing.medium),
          child,
        ],
      ),
    );
  }
}

/// Mali prigušeni opis iznad primera u odeljku galerije.
class GalleryLabeled extends StatelessWidget {
  const GalleryLabeled(this.label, this.child, {super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: t.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: TavliSpacing.small),
        child,
      ],
    );
  }
}
