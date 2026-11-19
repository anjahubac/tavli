import 'package:material_ui/material_ui.dart';

import '../theme/tavli_colors.dart';
import '../tokens.dart';
import 'tavli_tag.dart';

/// Izgled kartice iz standarda komponenti.
enum TavliCardVariant {
  /// Površina sa ivicom 1 px, radijus 20.
  plain,

  /// Boja teme, za sledeći obrok.
  highlighted,

  /// Skuvan obrok: zasenčena kartica i zelena kvačica gore desno.
  cooked,

  /// Radijus 14 i manji razmak, za nedeljnu mrežu na računaru.
  compact,
}

/// Kartica: radijus 20 (kompaktna 14), ivica 1 px, bez senke.
///
/// Kartice u istom redu stavljaju se u [TavliCardRow], da budu iste visine.
class TavliCard extends StatelessWidget {
  const TavliCard({
    super.key,
    required this.child,
    this.variant = TavliCardVariant.plain,
    this.onTap,
    this.padding,
  });

  final Widget child;
  final TavliCardVariant variant;

  /// Dodir na celu karticu (otvara recept ili obrok).
  final VoidCallback? onTap;

  /// Unutrašnji razmak; podrazumevano 14 (kompaktna 8).
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final x = TavliColors.of(context);
    final compact = variant == TavliCardVariant.compact;
    final radius = BorderRadius.circular(
      compact ? TavliRadius.compact : TavliRadius.card,
    );
    final (color, border) = switch (variant) {
      TavliCardVariant.highlighted => (c.primaryContainer, c.primaryContainer),
      // Zasenčena: bliže pozadini nego površine i pozadine ekrana.
      TavliCardVariant.cooked => (Color.lerp(c.surface, x.bg, 0.6)!, x.line),
      _ => (c.surface, x.line),
    };
    Widget content = Padding(
      padding:
          padding ??
          EdgeInsets.all(compact ? TavliSpacing.small : TavliSpacing.medium),
      child: variant == TavliCardVariant.highlighted
          ? DefaultTextStyle.merge(
              style: TextStyle(color: c.onPrimaryContainer),
              child: IconTheme.merge(
                data: IconThemeData(color: c.onPrimaryContainer),
                child: child,
              ),
            )
          : child,
    );
    if (variant == TavliCardVariant.cooked) {
      content = Stack(
        children: [
          Opacity(opacity: 0.72, child: content),
          const Positioned(
            top: TavliSpacing.small,
            right: TavliSpacing.small,
            child: TavliTag.cooked(),
          ),
        ],
      );
    }
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Kartice u istom redu, sve iste visine (visina najviše kartice).
///
/// Svaka kartica dobija jednak deo širine.
class TavliCardRow extends StatelessWidget {
  const TavliCardRow({
    super.key,
    required this.children,
    this.spacing = TavliSpacing.small,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing,
        children: [for (final c in children) Expanded(child: c)],
      ),
    );
  }
}
