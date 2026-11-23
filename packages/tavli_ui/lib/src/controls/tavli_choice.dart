import 'package:material_ui/material_ui.dart';

import '../icons/tavli_icons.dart';
import '../motion/motion.dart';
import '../platform.dart';
import '../theme/tavli_colors.dart';
import '../tokens.dart';

/// Jedan izbor u [TavliChoice].
@immutable
class TavliOption<T> {
  const TavliOption(this.value, this.label, {this.glyph});

  final T value;
  final String label;

  /// Ikonica ispred naziva u segmentu (Izgled: sunce, mesec, krug).
  final TavliIconData? glyph;
}

enum _ChoiceStyle { segmented, chips }

/// Izbor jedne od nekoliko mogućnosti.
///
/// * [TavliChoice.segmented]: segmentno dugme sa dva ili tri izbora
///   (Nedelja i Mesec, Po planu i Po receptu). Visina 40, radijus 20,
///   ivica 1 px. Svi segmenti su iste, fiksne širine (prema najdužem
///   nazivu), pa se dugme i sve oko njega ne pomeraju kada se izbor
///   promeni.
/// * [TavliChoice.chips]: čipovi za filter (Nedelja 1, Nedelja 2, Ceo
///   plan). Visina 36, radijus 10; prelaze u novi red kada nema mesta.
class TavliChoice<T> extends StatelessWidget {
  const TavliChoice.segmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.expand = false,
  }) : assert(options.length >= 2 && options.length <= 3),
       _style = _ChoiceStyle.segmented;

  const TavliChoice.chips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  }) : expand = false,
       _style = _ChoiceStyle.chips;

  final List<TavliOption<T>> options;
  final T selected;

  /// `null` isključuje izbor.
  final ValueChanged<T>? onChanged;

  /// Segmentno dugme preko cele širine, segmenti jednake širine (Izgled:
  /// režim). Bez njega je široko koliko traži najduži naziv.
  final bool expand;
  final _ChoiceStyle _style;

  @override
  Widget build(BuildContext context) => switch (_style) {
    _ChoiceStyle.segmented => _Segmented<T>(choice: this),
    _ChoiceStyle.chips => _Chips<T>(choice: this),
  };
}

TextStyle? _label(BuildContext context, Color color) =>
    Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: 14,
      // Ista debljina za izabran i neizabran, da se širina ne menja.
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: color,
    );

class _Segmented<T> extends StatelessWidget {
  const _Segmented({required this.choice});

  final TavliChoice<T> choice;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final x = TavliColors.of(context);
    final enabled = choice.onChanged != null;
    const radius = BorderRadius.all(Radius.circular(TavliRadius.card));
    final decoration = BoxDecoration(
      color: c.surface,
      borderRadius: radius,
      border: Border.all(color: x.line),
    );
    List<Widget> segments({required bool expand}) => [
      for (final o in choice.options)
        if (expand)
          Expanded(child: _segment(context, o, enabled))
        else
          _segment(context, o, enabled),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Kada segmenti ne staju u jedan red (uzak ekran, krupan tekst),
        // ređaju se jedan ispod drugog, preko cele širine.
        if (_rowWidth(context) > constraints.maxWidth) {
          return Semantics(
            container: true,
            explicitChildNodes: true,
            child: Container(
              padding: const EdgeInsets.all(_inset),
              decoration: decoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: segments(expand: false),
              ),
            ),
          );
        }
        if (choice.expand) {
          return Semantics(
            container: true,
            explicitChildNodes: true,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.all(_inset),
              decoration: decoration,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: segments(expand: true),
                ),
              ),
            ),
          );
        }
        // Align: dugme je široko koliko traže segmenti, i u roditelju koji
        // rasteže decu (lista, kolona).
        return Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          heightFactor: 1,
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: IntrinsicWidth(
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.all(_inset),
                decoration: decoration,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: segments(expand: true),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static const double _inset = 3;

  Widget _segment(BuildContext context, TavliOption<T> o, bool enabled) =>
      _Segment(
        label: o.label,
        glyph: o.glyph,
        selected: o.value == choice.selected,
        onTap: enabled
            ? () {
                TavliPlatform.selectionFeedback(context);
                choice.onChanged!(o.value);
              }
            : null,
      );

  /// Širina dugmeta u jednom redu: svi segmenti široki kao najduži naziv.
  double _rowWidth(BuildContext context) {
    final style = _label(context, Theme.of(context).colorScheme.onSurface);
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final o in choice.options) {
      final painter = TextPainter(
        text: TextSpan(text: o.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    final glyph = choice.options.any((o) => o.glyph != null)
        ? _Segment.glyphSize + _Segment.glyphGap
        : 0;
    return choice.options.length * (widest + glyph + 2 * _Segment.padding) +
        2 * (_inset + 1);
  }
}

class _Segment extends StatelessWidget {
  static const double padding = 16;
  static const double glyphSize = 16;
  static const double glyphGap = 6;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.glyph,
  });

  final String label;
  final TavliIconData? glyph;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final fg = !enabled
        ? c.onSurface.withValues(alpha: 0.38)
        : selected
        ? c.onPrimaryContainer
        : c.onSurfaceVariant;
    const radius = BorderRadius.all(
      Radius.circular(TavliRadius.card - _Segmented._inset),
    );
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : TavliMotion.feedback,
        decoration: BoxDecoration(
          color: selected ? c.primaryContainer : c.surface.withValues(alpha: 0),
          borderRadius: radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: selected ? null : onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: padding,
                vertical: 6,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: glyphGap,
                  children: [
                    if (glyph case final g?)
                      TavliIcon(g, size: glyphSize, color: fg),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: _label(context, fg),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chips<T> extends StatelessWidget {
  const _Chips({required this.choice});

  final TavliChoice<T> choice;

  @override
  Widget build(BuildContext context) {
    final onChanged = choice.onChanged;
    return Wrap(
      spacing: TavliSpacing.small,
      runSpacing: TavliSpacing.small,
      children: [
        for (final o in choice.options)
          _Chip(
            label: o.label,
            selected: o.value == choice.selected,
            exclusive: true,
            onTap: onChanged == null || o.value == choice.selected
                ? null
                : () => onChanged(o.value),
            enabled: onChanged != null,
          ),
      ],
    );
  }
}

/// Više izbora odjednom: čipovi (visina 36, radijus 10) koji se pale i
/// gase nezavisno, npr. obroci u planu (Doručak, Ručak, Večera). Prelaze
/// u novi red kada nema mesta.
class TavliMultiChoice<T> extends StatelessWidget {
  const TavliMultiChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<TavliOption<T>> options;
  final Set<T> selected;

  /// Novi skup izabranih; `null` isključuje izbor.
  final ValueChanged<Set<T>>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Wrap(
      spacing: TavliSpacing.small,
      runSpacing: TavliSpacing.small,
      children: [
        for (final o in options)
          _Chip(
            label: o.label,
            selected: selected.contains(o.value),
            exclusive: false,
            enabled: onChanged != null,
            onTap: onChanged == null
                ? null
                : () => onChanged(
                    selected.contains(o.value)
                        ? ({...selected}..remove(o.value))
                        : {...selected, o.value},
                  ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.exclusive,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;

  /// Jedan od izbora (čitač ekrana kaže „jedan od“), ili nezavisan čip.
  final bool exclusive;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final x = TavliColors.of(context);
    // Kao na platnu (Nabavka: „Nedelja 1“): izabran čip je meke boje teme
    // sa tamnim tekstom, kao izabran segment, a ne pun.
    final fg = !enabled
        ? c.onSurface.withValues(alpha: 0.38)
        : selected
        ? c.onPrimaryContainer
        : c.onSurface;
    const radius = BorderRadius.all(Radius.circular(TavliRadius.chip));
    final onTap = this.onTap;
    return Semantics(
      button: true,
      selected: exclusive ? selected : null,
      checked: exclusive ? null : selected,
      inMutuallyExclusiveGroup: exclusive,
      enabled: enabled,
      child: Material(
        color: selected ? c.primaryContainer : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? c.primaryContainer : x.boxLine),
        ),
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  TavliPlatform.selectionFeedback(context);
                  onTap();
                },
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Center(
                widthFactor: 1,
                child: Text(label, style: _label(context, fg)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
