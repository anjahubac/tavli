import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../motion/motion.dart';
import '../theme/tavli_colors.dart';
import '../tokens.dart';

/// Grupisana lista: jedna kartica (radijus 16, ivica 1 px) sa redovima i
/// razdelnicima od 1 px između njih.
///
/// Redovi ([TavliListRow], `TavliCheckRow`, `TavliSwitchRow`) nemaju svoju
/// pozadinu ni radijus; red koji stoji sam stavlja se u grupu sa jednim
/// redom.
class TavliListGroup extends StatelessWidget {
  const TavliListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final x = TavliColors.of(context);
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TavliRadius.field),
        side: BorderSide(color: x.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, row) in children.indexed) ...[
            if (i > 0) TavliDivider(color: x.line),
            row,
          ],
        ],
      ),
    );
  }
}

/// Razdelnik: 1 px, boja ivice iz teme.
class TavliDivider extends StatelessWidget {
  const TavliDivider({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    child: ColoredBox(color: color ?? TavliColors.of(context).line),
  );
}

/// Širina dugmeta „Ukloni“ koje otkriva prevlačenje reda.
const double _removeWidth = 96;

/// Red liste: naziv levo, količina desno („1,5 kg“); bez količine samo
/// naziv. Visina najmanje 52.
///
/// - [leading]: npr. `TavliThumbnail.row` ili `TavliAvatar`.
/// - [showChevron]: strelica desno kada dodir otvara detalj.
/// - [onRemove]: prevlačenje ulevo otkriva crveno dugme „Ukloni“ (96 px);
///   čitač ekrana dobija istu akciju.
class TavliListRow extends StatefulWidget {
  const TavliListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.quantity,
    this.leading,
    this.onTap,
    this.showChevron = false,
    this.onRemove,
    this.removeLabel = 'Ukloni',
  });

  final String title;

  /// Drugi red ispod naziva, npr. „35 min · 4 porcije“.
  final String? subtitle;

  /// Količina desno; `null` ili prazno znači samo naziv.
  final String? quantity;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool showChevron;
  final VoidCallback? onRemove;
  final String removeLabel;

  @override
  State<TavliListRow> createState() => _TavliListRowState();
}

class _TavliListRowState extends State<TavliListRow>
    with SingleTickerProviderStateMixin {
  // 0 = zatvoreno, 1 = dugme „Ukloni“ potpuno otkriveno.
  late final _reveal = AnimationController(
    vsync: this,
    duration: TavliMotion.feedback,
  );

  @override
  void didUpdateWidget(TavliListRow old) {
    super.didUpdateWidget(old);
    if (widget.onRemove == null) _reveal.value = 0;
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails d) {
    final dx = Directionality.of(context) == TextDirection.rtl
        ? -d.primaryDelta!
        : d.primaryDelta!;
    _reveal.value -= dx / _removeWidth;
  }

  void _settle(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final open = v.abs() > 300 ? v < 0 : _reveal.value > 0.5;
    _animate(open);
  }

  void _animate(bool open) {
    if (reduceMotion(context)) {
      _reveal.value = open ? 1 : 0;
    } else {
      unawaited(open ? _reveal.forward() : _reveal.reverse());
    }
  }

  void _remove() {
    _animate(false);
    widget.onRemove?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final quantity = widget.quantity;
    final subtitle = widget.subtitle;
    final hasQuantity = quantity != null && quantity.isNotEmpty;

    final row = Material(
      color: c.surface,
      child: InkWell(
        onTap: widget.onTap == null
            ? null
            : () {
                if (_reveal.value > 0) {
                  _animate(false);
                } else {
                  widget.onTap!();
                }
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TavliSpacing.medium,
              vertical: TavliSpacing.small,
            ),
            child: Row(
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: t.bodyLarge?.copyWith(
                          fontSize: 16,
                          height: 1.35,
                          color: c.onSurface,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle,
                            style: t.bodyMedium?.copyWith(
                              fontSize: 14,
                              height: 1.4,
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasQuantity) ...[
                  const SizedBox(width: TavliSpacing.small),
                  Text(
                    quantity,
                    style: t.bodyMedium?.copyWith(
                      fontSize: 15,
                      height: 1.35,
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ],
                if (widget.showChevron) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: c.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    final onRemove = widget.onRemove;
    if (onRemove == null) return MergeSemantics(child: row);

    return MergeSemantics(
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: widget.removeLabel): _remove,
        },
        child: GestureDetector(
          onHorizontalDragUpdate: _drag,
          onHorizontalDragEnd: _settle,
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _RemoveAction(
                    label: widget.removeLabel,
                    reveal: _reveal,
                    onPressed: _remove,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _reveal,
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                    (Directionality.of(context) == TextDirection.rtl ? 1 : -1) *
                        _reveal.value *
                        _removeWidth,
                    0,
                  ),
                  child: child,
                ),
                child: row,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveAction extends StatelessWidget {
  const _RemoveAction({
    required this.label,
    required this.reveal,
    required this.onPressed,
  });

  final String label;
  final Animation<double> reveal;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        width: _removeWidth,
        height: double.infinity,
        child: Material(
          color: c.error,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: c.onError,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
