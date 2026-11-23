import 'package:material_ui/material_ui.dart';

import '../controls/tavli_taste_chips.dart' show TavliDashedBorderPainter;
import '../icons/tavli_icons.dart';
import '../theme/tavli_colors.dart';

/// Radijus pločice omiljenog recepta sa platna.
const double _tileRadius = 18;

/// Mala pločica recepta (omiljeni recepti): sličica sa srcem gore desno i
/// naziv ispod.
///
/// U traci koja se pomera vodoravno ima širinu [stripWidth]; sa
/// `expand: true` popunjava ćeliju mreže (računar).
class TavliRecipeTile extends StatelessWidget {
  const TavliRecipeTile({
    super.key,
    required this.title,
    required this.onTap,
    this.photo,
    this.tintIndex = 0,
    this.expand = false,
  });

  /// Širina pločice u traci (telefon).
  static const double stripWidth = 124;

  final String title;
  final VoidCallback? onTap;

  /// Fotografija recepta; `null` crta ikonicu na mekoj boji teme.
  final Widget? photo;
  final int tintIndex;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final x = TavliColors.of(context);
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(_tileRadius);
    final photo = this.photo;
    final tile = Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: x.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  height: expand ? 64 : 72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        photo ??
                            ColoredBox(
                              color: x.tint(tintIndex),
                              child: Center(
                                child: TavliIcon(
                                  TavliIcons.dish,
                                  size: 26,
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                            ),
                        PositionedDirectional(
                          top: 6,
                          end: 6,
                          child: TavliIcon(
                            TavliIcons.like,
                            size: 16,
                            color: c.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: t.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: c.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      child: expand ? tile : SizedBox(width: stripWidth, child: tile),
    );
  }
}

/// Isprekidana pločica „+ Dodaj“ na početku trake omiljenih recepata.
class TavliAddTile extends StatelessWidget {
  const TavliAddTile({super.key, required this.label, required this.onTap});

  /// Širina pločice sa platna.
  static const double width = 96;

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final x = TavliColors.of(context);
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(_tileRadius);
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        child: CustomPaint(
          painter: TavliDashedBorderPainter(
            color: x.boxLine,
            radius: _tileRadius,
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 136),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: TavliIcon(
                          TavliIcons.add,
                          size: 20,
                          color: c.primary,
                        ),
                      ),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: t.labelLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
