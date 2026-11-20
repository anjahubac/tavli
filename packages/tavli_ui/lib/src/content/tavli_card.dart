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
    this.selected = false,
  });

  final Widget child;
  final TavliCardVariant variant;

  /// Dodir na celu karticu (otvara recept ili obrok).
  final VoidCallback? onTap;

  /// Unutrašnji razmak; podrazumevano 14 (kompaktna 8).
  final EdgeInsetsGeometry? padding;

  /// Izabrana kartica (npr. recept otvoren pored liste): ivica 2 px u boji
  /// teme, a čitač ekrana kaže da je izabrana.
  final bool selected;

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
    final card = Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: selected
            ? BorderSide(color: c.primary, width: 2)
            : BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
    return selected ? Semantics(selected: true, child: card) : card;
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

/// Mreža kartica: [columns] kolona jednake širine, kartice u istom redu iste
/// visine. Recepti: tri kolone na računaru, jedna na telefonu; nedeljni plan
/// na računaru: sedam kolona kompaktnih kartica.
///
/// Gradi redove tek kad se prikažu, pa se koristi umesto `ListView`. Poslednji
/// red koji nije pun ostavlja prazna mesta, da kartice ostanu iste širine.
class TavliCardGrid extends StatelessWidget {
  const TavliCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.columns = 1,
    this.spacing = TavliSpacing.medium,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
  }) : assert(columns > 0);

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int columns;

  /// Razmak između kartica, vodoravno i uspravno.
  final double spacing;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final rows = (itemCount / columns).ceil();
    return ListView.separated(
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      itemCount: rows,
      separatorBuilder: (_, _) => SizedBox(height: spacing),
      itemBuilder: (context, row) {
        if (columns == 1) return itemBuilder(context, row);
        final start = row * columns;
        return TavliCardRow(
          spacing: spacing,
          children: [
            for (var i = start; i < start + columns; i++)
              i < itemCount ? itemBuilder(context, i) : const SizedBox(),
          ],
        );
      },
    );
  }
}
