import 'package:material_ui/material_ui.dart';

import '../motion/motion.dart';
import '../theme/tavli_colors.dart';
import '../tokens.dart';

/// Jedan izbor u [TavliChoice].
@immutable
class TavliOption<T> {
  const TavliOption(this.value, this.label);

  final T value;
  final String label;
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
  }) : assert(options.length >= 2 && options.length <= 3),
       _style = _ChoiceStyle.segmented;

  const TavliChoice.chips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  }) : _style = _ChoiceStyle.chips;

  final List<TavliOption<T>> options;
  final T selected;

  /// `null` isključuje izbor.
  final ValueChanged<T>? onChanged;
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
          Expanded(child: _segment(o, enabled))
        else
          _segment(o, enabled),
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

  Widget _segment(TavliOption<T> o, bool enabled) => _Segment(
    label: o.label,
    selected: o.value == choice.selected,
    onTap: enabled ? () => choice.onChanged!(o.value) : null,
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
    return choice.options.length * (widest + 2 * _Segment.padding) +
        2 * (_inset + 1);
  }
}

class _Segment extends StatelessWidget {
  static const double padding = 16;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: _label(context, fg),
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
    final c = Theme.of(context).colorScheme;
    final x = TavliColors.of(context);
    final enabled = choice.onChanged != null;
    return Wrap(
      spacing: TavliSpacing.small,
      runSpacing: TavliSpacing.small,
      children: [
        for (final o in choice.options)
          Builder(
            builder: (context) {
              final selected = o.value == choice.selected;
              final fg = !enabled
                  ? c.onSurface.withValues(alpha: 0.38)
                  : selected
                  ? c.onPrimary
                  : c.onSurface;
              const radius = BorderRadius.all(
                Radius.circular(TavliRadius.chip),
              );
              return Semantics(
                button: true,
                selected: selected,
                inMutuallyExclusiveGroup: true,
                enabled: enabled,
                child: Material(
                  color: selected ? c.primary : c.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: radius,
                    side: selected
                        ? BorderSide.none
                        : BorderSide(color: x.line),
                  ),
                  child: InkWell(
                    onTap: enabled && !selected
                        ? () => choice.onChanged!(o.value)
                        : null,
                    borderRadius: radius,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 36),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: Text(o.label, style: _label(context, fg)),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
