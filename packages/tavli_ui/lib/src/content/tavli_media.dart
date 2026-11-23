import 'package:material_ui/material_ui.dart';

import '../icons/tavli_icons.dart';
import '../platform.dart';
import '../theme/tavli_colors.dart';
import '../tokens.dart';

/// Sličica recepta: radijus 14. Bez fotografije prikazuje ikonicu na mekoj
/// boji teme (`TavliColors.tint`).
///
/// Ukras je: čitač ekrana je preskače, naziv recepta čita red ili kartica.
class TavliThumbnail extends StatelessWidget {
  /// 56 x 56, u redu liste.
  const TavliThumbnail.row({
    super.key,
    this.image,
    this.tintIndex = 0,
    this.icon = Icons.restaurant_rounded,
    this.photo,
  }) : width = 56,
       height = 56,
       rounded = true;

  /// Puna širina i visina 120, na vrhu kartice recepta na računaru.
  const TavliThumbnail.banner({
    super.key,
    this.image,
    this.tintIndex = 0,
    this.icon = Icons.restaurant_rounded,
    this.photo,
  }) : width = double.infinity,
       height = 120,
       rounded = true;

  /// Vrh kartice recepta u mreži na računaru: puna širina, visina 120, bez
  /// svog radijusa (zaobljava je kartica).
  const TavliThumbnail.cardTop({
    super.key,
    this.image,
    this.tintIndex = 0,
    this.icon = Icons.restaurant_rounded,
    this.photo,
  }) : width = double.infinity,
       height = 120,
       rounded = false;

  /// Fotografija recepta; `null` crta ikonicu.
  final ImageProvider? image;

  /// Gotov prikaz fotografije (npr. slika iz keša aplikacije) umesto
  /// [image]; popunjava ceo okvir.
  final Widget? photo;
  final bool rounded;

  /// Koja od tri meke boje teme (recepti se smenjuju).
  final int tintIndex;
  final IconData icon;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final x = TavliColors.of(context);
    final image = this.image;
    final photo = this.photo;
    final placeholder = ColoredBox(
      color: x.tint(tintIndex),
      child: Center(
        child: Icon(
          icon,
          size: height >= 100 ? 36 : 26,
          color: c.onSurfaceVariant,
        ),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: rounded
              ? BorderRadius.circular(TavliRadius.compact)
              : BorderRadius.zero,
          child: photo != null
              ? SizedBox.expand(child: photo)
              : image == null
              ? placeholder
              : Image(
                  image: image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}

/// Avatar: krug sa inicijalima, slikom ili ikonicom. Podrazumevano 40, na
/// iOS-u 36.
class TavliAvatar extends StatelessWidget {
  const TavliAvatar({
    super.key,
    required this.initials,
    this.image,
    this.size,
    this.semanticLabel,
  }) : glyph = null,
       destructive = false;

  /// Ikonica u mekom krugu umesto inicijala (domaćinstvo u profilu,
  /// upozorenje u dijalogu). [destructive] boji krug bojom greške.
  const TavliAvatar.icon(
    TavliIconData this.glyph, {
    super.key,
    this.size,
    this.semanticLabel,
    this.destructive = false,
  }) : initials = '',
       image = null;

  /// Jedno ili dva slova; prikazuju se i dok se slika učitava.
  final String initials;
  final ImageProvider? image;

  /// Prečnik; `null` bira 40 (36 na iOS-u).
  final double? size;

  /// Prečnik velikog avatara u zaglavlju profila.
  static const double large = 56;

  /// Ikonica domaćinstva u kartici profila (kanvas: 44).
  static const double medium = 44;

  /// Ikonica u zaglavlju dijaloga (kanvas: 48).
  static const double prominent = 48;

  final TavliIconData? glyph;
  final bool destructive;

  /// Ime osobe za čitač ekrana; bez njega avatar je ukras.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final size =
        this.size ?? (TavliPlatform.of(context) == TavliPlatform.ios ? 36 : 40);
    final fontSize = switch (size) {
      >= large => 20.0,
      >= 40 => 14.0,
      >= 36 => 13.0,
      _ => 12.0,
    };
    final image = this.image;
    final glyph = this.glyph;
    final (fill, ink) = destructive
        ? (c.errorContainer, c.error)
        : (c.primaryContainer, c.onPrimaryContainer);
    Widget circle = SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          image: image == null
              ? null
              : DecorationImage(image: image, fit: BoxFit.cover),
        ),
        child: image != null
            ? null
            : glyph != null
            // Kanvas: 22 u krugu od 44, 24 u krugu od 48.
            ? Center(
                child: TavliIcon(glyph, size: size / 2, color: ink),
              )
            : Center(
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
    final label = semanticLabel;
    circle = label == null
        ? ExcludeSemantics(child: circle)
        : Semantics(
            label: label,
            image: true,
            excludeSemantics: true,
            child: circle,
          );
    return circle;
  }
}
