import 'package:material_ui/material_ui.dart';

import '../icons/tavli_icons.dart';
import '../tokens.dart';
import 'gallery_section.dart';

/// Odeljak galerije: ceo set Tavli ikonica sa imenima, u veličini za
/// navigaciju (22).
class TavliIconGallerySections extends StatelessWidget {
  const TavliIconGallerySections({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return GallerySection(
      title: 'Ikonice',
      child: Wrap(
        spacing: TavliSpacing.medium,
        runSpacing: TavliSpacing.medium,
        children: [
          for (final icon in TavliIcons.all)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TavliIcon(icon, size: 22),
                const SizedBox(height: TavliSpacing.small),
                Text(
                  icon.name,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: muted),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
