import 'package:material_ui/material_ui.dart';

import '../icons/tavli_icons.dart';

/// Dugme samo sa ikonicom. Opis je obavezan: čita ga čitač ekrana i
/// prikazuje se kao oblačić pod mišem ili na dug pritisak.
///
/// Polje za dodir je uvek najmanje 48 x 48, a ikonica 24.
class TavliIconButton extends StatelessWidget {
  const TavliIconButton({
    super.key,
    this.icon,
    this.glyph,
    required this.semanticLabel,
    required this.onPressed,
    this.selected = false,
  }) : assert(
         (icon == null) != (glyph == null),
         'tačno jedna: ikonica ili Tavli ikonica',
       );

  final IconData? icon;

  /// Ikonica iz Tavli seta ([TavliIcons]); zamenjuje [icon].
  final TavliIconData? glyph;

  /// Šta dugme radi, npr. „Obriši pretragu“.
  final String semanticLabel;

  /// `null` isključuje dugme.
  final VoidCallback? onPressed;

  /// Uključeno stanje (npr. omiljeni recept): ikonica u boji teme.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    // Opis je oznaka dugmeta za čitač ekrana; oblačić ga samo prikazuje,
    // da se ne čita dva puta.
    return Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        isSelected: selected,
        icon: switch (glyph) {
          final g? => TavliIcon(g, size: 24, semanticLabel: semanticLabel),
          null => Icon(icon, size: 24, semanticLabel: semanticLabel),
        },
        color: selected ? c.primary : c.onSurfaceVariant,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        style: const ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
        ),
      ),
    );
  }
}
