import 'package:material_ui/material_ui.dart';

import '../theme/tavli_colors.dart';
import '../tokens.dart';

/// Vrsta dugmeta iz standarda komponenti.
enum TavliButtonVariant {
  /// Glavno: visina 56, radijus 18, tekst 16 podebljan, boja teme.
  primary,

  /// Sporedno: visina 48 (56 pored glavnog), radijus 16, ivica 1 px.
  secondary,

  /// Tekstualno: visina 48, radijus 14, bez pozadine.
  text,

  /// Tekstualno za brisanje: kao tekstualno, u boji greške.
  destructive,
}

/// Dugme iz biblioteke. Ekran bira samo vrstu, tekst i ikonicu; boja,
/// radijus i visina dolaze iz standarda.
///
/// Dva ili više dugmadi u istom redu idu u [TavliButtonRow], da budu iste
/// visine (sporedno pored glavnog dobija 56).
class TavliButton extends StatelessWidget {
  const TavliButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  }) : variant = TavliButtonVariant.primary;

  const TavliButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  }) : variant = TavliButtonVariant.secondary;

  const TavliButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  }) : variant = TavliButtonVariant.text;

  /// Tekstualno dugme za brisanje („Obriši ceo dnevnik ishrane“). Potvrdu
  /// pre brisanja pravi ekran.
  const TavliButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  }) : variant = TavliButtonVariant.destructive;

  final TavliButtonVariant variant;
  final String label;
  final IconData? icon;

  /// `null` isključuje dugme.
  final VoidCallback? onPressed;

  /// Visina bez obzira na red: 56 za glavno, 48 za ostala.
  double get baseHeight => variant == TavliButtonVariant.primary ? 56 : 48;

  @override
  Widget build(BuildContext context) {
    final scope = _TavliButtonScope.maybeOf(context);
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final x = TavliColors.of(context);
    final compact = scope?.compact ?? false;
    final height = scope?.height ?? baseHeight;

    final radius = switch (variant) {
      TavliButtonVariant.primary => TavliRadius.button,
      TavliButtonVariant.secondary => TavliRadius.field,
      TavliButtonVariant.text ||
      TavliButtonVariant.destructive => TavliRadius.compact,
    };
    final textStyle = theme.textTheme.labelLarge?.copyWith(
      fontSize: compact ? 15 : 16,
      fontWeight: variant == TavliButtonVariant.primary || compact
          ? FontWeight.w700
          : FontWeight.w600,
      height: 1.25,
    );
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(height, height)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: compact ? 12 : (variant.isText ? 12 : 20),
          vertical: TavliSpacing.small,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      textStyle: WidgetStatePropertyAll(textStyle),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      // Na računaru pod mišem.
      mouseCursor: WidgetStateMouseCursor.clickable,
      side: variant == TavliButtonVariant.secondary
          ? WidgetStateBorderSide.resolveWith(
              (s) => BorderSide(
                color: s.contains(WidgetState.disabled) ? x.line : x.boxLine,
              ),
            )
          : null,
      foregroundColor: switch (variant) {
        TavliButtonVariant.secondary => _enabled(c.onSurface, c),
        TavliButtonVariant.text => _enabled(c.primary, c),
        TavliButtonVariant.destructive => _enabled(c.error, c),
        TavliButtonVariant.primary => null,
      },
    );

    final text = Text(label, textAlign: TextAlign.center);
    final child = icon == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: TavliSpacing.small),
              Flexible(child: text),
            ],
          );

    return switch (variant) {
      TavliButtonVariant.primary => FilledButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
      TavliButtonVariant.secondary => OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
      TavliButtonVariant.text || TavliButtonVariant.destructive => TextButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
    };
  }

  static WidgetStateProperty<Color> _enabled(Color color, ColorScheme c) =>
      WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? c.onSurface.withValues(alpha: 0.38)
            : color,
      );
}

extension on TavliButtonVariant {
  bool get isText =>
      this == TavliButtonVariant.text || this == TavliButtonVariant.destructive;
}

/// Dugmad u jednom redu, uvek iste visine.
///
/// Ako je u redu glavno dugme, sva dugmad su visine 56 (sporedno pored
/// glavnog), inače 48. Kada veći tekst ili prelom poveća jedno dugme, i
/// ostala rastu sa njim.
///
/// [expand] deli širinu podjednako (traka sa akcijama, „Kuvaj“ i
/// „Skuvano“ na kartici); bez njega dugmad su široka koliko tekst traži.
class TavliButtonRow extends StatelessWidget {
  const TavliButtonRow({
    super.key,
    required this.children,
    this.expand = false,
    this.alignment = MainAxisAlignment.start,
  });

  final List<TavliButton> children;
  final bool expand;

  /// Raspored kada [expand] nije uključen.
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final height = children.any((b) => b.variant == TavliButtonVariant.primary)
        ? 56.0
        : 48.0;
    return _TavliButtonScope(
      height: _TavliButtonScope.maybeOf(context)?.height ?? height,
      compact: _TavliButtonScope.maybeOf(context)?.compact ?? false,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: alignment,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, b) in children.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              if (expand) Expanded(child: b) else b,
            ],
          ],
        ),
      ),
    );
  }
}

/// Zadaje visinu dugmadi ispod sebe; koriste ga [TavliButtonRow] i
/// traka sa akcijama.
class TavliButtonScope extends StatelessWidget {
  /// Dugmad u traci sa akcijama: uvek 56, manji unutrašnji razmak i tekst
  /// 15, da „Ponovo predloži“ i „Otvori nabavku“ stanu u jedan red.
  const TavliButtonScope.actionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _TavliButtonScope(height: 56, compact: true, child: child);
}

class _TavliButtonScope extends InheritedWidget {
  const _TavliButtonScope({
    required this.height,
    required this.compact,
    required super.child,
  });

  final double height;
  final bool compact;

  static _TavliButtonScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TavliButtonScope>();

  @override
  bool updateShouldNotify(_TavliButtonScope old) =>
      height != old.height || compact != old.compact;
}
