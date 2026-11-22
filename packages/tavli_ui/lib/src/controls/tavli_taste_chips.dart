import 'dart:ui' show PathMetric;

import 'package:material_ui/material_ui.dart';

import '../icons/tavli_icons.dart';
import '../platform.dart';
import '../theme/tavli_colors.dart';
import '../theme/tavli_status_colors.dart';

/// Čipovi za ukuse i alergene, sa platna „Ukusi i alergeni A“.
///
/// Vidljiva visina je 44 (zaobljeno do kraja), a polje za dodir 48: dva
/// prozirna piksela gore i dole. Zato se ređaju u [TavliChipWrap], koji
/// oduzima taj višak od razmaka između redova.

/// Vidljiva visina čipa sa platna.
const double _chipHeight = 44;

/// Debljina ivice čipa; ulazi u vidljivu visinu.
const double _border = 2;

/// Dodatak gore i dole do polja za dodir 48.
const double _touchInset = 2;

/// Ređa čipove kao na platnu: razmak 8 između čipova i redova (vidljivo).
class TavliChipWrap extends StatelessWidget {
  const TavliChipWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8 - 2 * _touchInset, children: children);
}

/// Neizabran čip: između pozadine i ivice (kanvas #EFEEE7).
Color _restingFill(BuildContext context) {
  final x = TavliColors.of(context);
  return Color.lerp(x.bg, x.line, 0.5)!;
}

TextStyle? _chipLabel(BuildContext context, Color color, bool strong) =>
    Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
      height: 1.25,
      color: color,
    );

/// Zajednički okvir čipa: površina sa ivicom 2, polje za dodir 48 i
/// dodir koji radi i u prozirnom dodatku.
class _ChipFrame extends StatelessWidget {
  const _ChipFrame({
    required this.fill,
    required this.border,
    required this.onTap,
    required this.child,
    this.radius,
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: 16),
    this.expand = false,
  });

  final Color fill;
  final Color border;
  final VoidCallback? onTap;
  final Widget child;

  /// `null`: zaobljeno do kraja (pilula).
  final double? radius;
  final EdgeInsetsGeometry padding;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final radius = this.radius;
    final ShapeBorder shape = radius == null
        ? StadiumBorder(
            side: BorderSide(color: border, width: _border),
          )
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(color: border, width: _border),
          );
    final ShapeBorder clip = radius == null
        ? const StadiumBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final tap = onTap == null
        ? null
        : () {
            TavliPlatform.selectionFeedback(context);
            onTap!();
          };
    final row = Padding(padding: padding, child: child);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      excludeFromSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _touchInset),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          decoration: ShapeDecoration(color: fill, shape: shape),
          // Ivicu crta dekoracija; Material samo seče talas dodira.
          child: Material(
            type: MaterialType.transparency,
            shape: clip,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: tap,
              customBorder: clip,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: _chipHeight - 2 * _border,
                ),
                child: expand ? row : IntrinsicWidth(child: row),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Čip koji se uključuje i isključuje, npr. alergen „Mleko“: ikonica u
/// krugu levo, kvačica desno kad je izabran.
///
/// Podrazumevano je pilula; [TavliToggleChip.tile] je pločica radijusa 12
/// preko cele širine, za mrežu u dve kolone na računaru.
class TavliToggleChip extends StatelessWidget {
  const TavliToggleChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.icon,
  }) : _tile = false;

  const TavliToggleChip.tile({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.icon,
  }) : _tile = true;

  final String label;
  final bool selected;
  final TavliIconData? icon;

  /// `null` isključuje čip.
  final ValueChanged<bool>? onChanged;
  final bool _tile;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final fg = selected ? c.onPrimaryContainer : c.onSurfaceVariant;
    final fill = selected ? c.surface : _restingFill(context);
    final icon = this.icon;
    final onChanged = this.onChanged;
    final text = Text(label, style: _chipLabel(context, fg, selected));
    return Semantics(
      button: true,
      toggled: selected,
      enabled: onChanged != null,
      label: label,
      onTap: onChanged == null ? null : () => onChanged(!selected),
      excludeSemantics: true,
      child: _ChipFrame(
        fill: fill,
        border: selected ? c.primary : fill,
        radius: _tile ? 12 : null,
        expand: _tile,
        padding: EdgeInsetsDirectional.only(
          start: icon == null ? 16 : 8,
          end: 14,
        ),
        onTap: onChanged == null ? null : () => onChanged(!selected),
        child: Row(
          mainAxisSize: _tile ? MainAxisSize.max : MainAxisSize.min,
          spacing: 8,
          children: [
            if (icon != null)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected ? c.primaryContainer : c.surface,
                  borderRadius: BorderRadius.circular(_tile ? 8 : 14),
                ),
                alignment: Alignment.center,
                child: TavliIcon(icon, size: 18, color: fg),
              ),
            if (_tile) Expanded(child: text) else Flexible(child: text),
            if (selected) TavliIcon(TavliIcons.check, size: 16, color: fg),
          ],
        ),
      ),
    );
  }
}

/// Sviđanje: ništa, „Volim“ ili „Ne volim“.
enum TavliLiking {
  none,
  like,
  dislike;

  /// Sledeće stanje na dodir: ništa → Volim → Ne volim → ništa.
  TavliLiking get next => switch (this) {
    none => like,
    like => dislike,
    dislike => none,
  };

  /// Kako se stanje čita (čitač ekrana).
  String get label => switch (this) {
    none => 'bez izbora',
    like => 'Volim',
    dislike => 'Ne volim',
  };
}

({Color fill, Color border, Color fg}) _likingColors(
  BuildContext context,
  TavliLiking liking,
) {
  final c = Theme.of(context).colorScheme;
  final dislike = TavliStatusColors.of(context).dislike;
  return switch (liking) {
    TavliLiking.like => (
      fill: c.primaryContainer,
      border: c.primary,
      fg: c.onPrimaryContainer,
    ),
    TavliLiking.dislike => (
      fill: dislike.background,
      border: dislike.foreground,
      fg: dislike.foreground,
    ),
    TavliLiking.none => (
      fill: _restingFill(context),
      border: _restingFill(context),
      fg: c.onSurfaceVariant,
    ),
  };
}

/// Ikonica za „Volim“ (srce) i „Ne volim“ (precrtan krug).
TavliIconData? likingIcon(TavliLiking liking) => switch (liking) {
  TavliLiking.like => TavliIcons.like,
  TavliLiking.dislike => TavliIcons.dislike,
  TavliLiking.none => null,
};

/// Čip sa tri stanja, npr. vrsta jela „Testenina“: dodir menja ništa →
/// Volim → Ne volim → ništa.
class TavliLikingChip extends StatelessWidget {
  const TavliLikingChip({
    super.key,
    required this.label,
    required this.liking,
    required this.onChanged,
  });

  final String label;
  final TavliLiking liking;

  /// Dobija sledeće stanje ([TavliLiking.next]); `null` isključuje čip.
  final ValueChanged<TavliLiking>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = _likingColors(context, liking);
    final icon = likingIcon(liking);
    final onChanged = this.onChanged;
    return Semantics(
      button: true,
      enabled: onChanged != null,
      label: '$label: ${liking.label}',
      onTap: onChanged == null ? null : () => onChanged(liking.next),
      excludeSemantics: true,
      child: _ChipFrame(
        fill: colors.fill,
        border: colors.border,
        onTap: onChanged == null ? null : () => onChanged(liking.next),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            if (icon != null) TavliIcon(icon, size: 16, color: colors.fg),
            Flexible(
              child: Text(
                label,
                style: _chipLabel(
                  context,
                  colors.fg,
                  liking != TavliLiking.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Izabrana namirnica u „Volim“ ili „Ne volim“, sa dugmetom za uklanjanje.
class TavliRemovableChip extends StatelessWidget {
  const TavliRemovableChip({
    super.key,
    required this.label,
    required this.liking,
    required this.onRemove,
  }) : assert(liking != TavliLiking.none);

  final String label;
  final TavliLiking liking;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = _likingColors(context, liking);
    final onRemove = this.onRemove;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: _chipHeight + 2 * _touchInset,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: _touchInset),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.fill,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 14),
                  child: Text(
                    label,
                    style: _chipLabel(
                      context,
                      colors.fg,
                      true,
                    )?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Tooltip(
                message: 'Ukloni $label',
                excludeFromSemantics: true,
                child: Semantics(
                  button: true,
                  label: 'Ukloni $label',
                  onTap: onRemove,
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: onRemove,
                    radius: 20,
                    child: SizedBox(
                      width: 44,
                      height: _chipHeight + 2 * _touchInset,
                      child: Center(
                        child: TavliIcon(
                          TavliIcons.close.withStroke(2.4),
                          size: 14,
                          color: colors.fg,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Isprekidana pilula „+ Dodaj“ na kraju liste čipova.
class TavliAddChip extends StatelessWidget {
  const TavliAddChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final x = TavliColors.of(context);
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        excludeFromSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _touchInset),
          child: CustomPaint(
            painter: TavliDashedBorderPainter(color: x.boxLine),
            child: Material(
              type: MaterialType.transparency,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                customBorder: const StadiumBorder(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _chipHeight),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 10,
                      end: 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        TavliIcon(TavliIcons.add, size: 16, color: c.primary),
                        Text(
                          label,
                          style: _chipLabel(context, c.primary, true),
                        ),
                      ],
                    ),
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

/// Isprekidana ivica (1,5 px) oko pilule ili zaobljenog pravougaonika.
class TavliDashedBorderPainter extends CustomPainter {
  const TavliDashedBorderPainter({required this.color, this.radius});

  final Color color;

  /// `null`: zaobljeno do kraja.
  final double? radius;

  @override
  void paint(Canvas canvas, Size size) {
    const width = 1.5;
    final rect = (Offset.zero & size).deflate(width / 2);
    final r = radius ?? rect.shortestSide / 2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    const dash = 4.0;
    const gap = 3.0;
    for (final PathMetric metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(TavliDashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
