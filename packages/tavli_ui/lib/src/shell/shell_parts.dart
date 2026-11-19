import 'package:material_ui/material_ui.dart';

import '../platform.dart';
import '../theme/tavli_colors.dart';

/// Delovi koje dele komponente kostura; nisu deo javnog ulaza.

/// Pozadina bočne trake i naslovne trake prozora: između pozadine ekrana i
/// boje ivice, kao na platnu (#F1F0E9 u Bosiljku).
Color shellSurface(BuildContext context) {
  final x = TavliColors.of(context);
  return Color.lerp(x.bg, x.line, 0.35)!;
}

/// Telefon (Android, iOS) ili računar (macOS, Windows).
bool isDesktop(BuildContext context) => TavliPlatform.of(context).isDesktop;

/// Krug sa inicijalima korisnika (gornja traka i bočna navigacija).
///
/// Samostalna komponenta avatara stiže sa karticama i listama; ovde je samo
/// ono što kostur traži.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final fontSize = switch (size) {
      >= 40 => 14.0,
      >= 36 => 13.0,
      _ => 12.0,
    };
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: MediaQuery.withNoTextScaling(
            child: Text(
              initials,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: c.onPrimaryContainer,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
