import 'package:material_ui/material_ui.dart';

import '../content/tavli_media.dart';
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
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) =>
      TavliAvatar(initials: initials, size: size);
}
