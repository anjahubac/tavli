import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../icons/tavli_icons.dart';
import '../platform.dart';
import '../theme/tavli_colors.dart';
import '../tokens.dart';

const _rowPadding = EdgeInsets.symmetric(
  horizontal: TavliSpacing.medium,
  vertical: TavliSpacing.small,
);
const _rowRadius = BorderRadius.all(Radius.circular(TavliRadius.field));

/// Polje za štikliranje: 22 x 22, radijus 6, kvačica iz Tavli seta (linija
/// 3). Samo crtež; dodir i opis za čitač ekrana daje red koji ga sadrži.
class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked, required this.enabled});

  final bool checked;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final x = TavliColors.of(context);
    final on = enabled ? c.primary : c.onSurface.withValues(alpha: 0.38);
    return SizedBox.square(
      dimension: 22,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: checked ? on : c.surface,
          borderRadius: BorderRadius.circular(TavliRadius.checkbox),
          border: checked ? null : Border.all(color: x.boxLine, width: 2),
        ),
        child: checked
            ? Center(
                child: TavliIcon(
                  TavliIcons.check.withStroke(3),
                  size: 16,
                  color: c.onPrimary,
                ),
              )
            : null,
      ),
    );
  }
}

/// Red sa poljem za štikliranje (stavka nabavke). Štiklirana stavka je
/// precrtana i prigušena. Visina najmanje 52.
///
/// Red nema pozadinu ni ivicu: stavlja se u grupisanu listu ili karticu.
///
/// - Bez [onSelect] ceo red štiklira.
/// - Sa [onSelect] (lista i detalj na računaru) dodir na red bira stavku za
///   detalj, a štiklira se samo poljem (polje za dodir 48). Izabran red ima
///   meku pozadinu boje teme ([selected]).
/// - [onLongPress] (npr. „Za koje obroke“ na telefonu) se otvara dugim
///   pritiskom; čitač ekrana ga dobija kao radnju [longPressLabel].
/// - [trailing]: dugme desno (npr. „Obriši“ za ručnu stavku).
class TavliCheckRow extends StatelessWidget {
  const TavliCheckRow({
    super.key,
    required this.title,
    required this.checked,
    required this.onChanged,
    this.detail,
    this.onSelect,
    this.selected = false,
    this.onLongPress,
    this.longPressLabel,
    this.trailing,
  }) : assert(
         (onLongPress == null) == (longPressLabel == null),
         'dug pritisak traži i naziv radnje',
       );

  final String title;

  /// Kratak podatak desno, npr. količina „1,5 kg“.
  final String? detail;
  final bool checked;

  /// `null` isključuje štikliranje.
  final ValueChanged<bool>? onChanged;

  /// Bira red za detalj (lista i detalj); tada štiklira samo polje.
  final VoidCallback? onSelect;

  /// Red je izabran za detalj.
  final bool selected;
  final VoidCallback? onLongPress;
  final String? longPressLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final enabled = onChanged != null;
    final muted = checked || !enabled;
    final detail = this.detail;
    final onSelect = this.onSelect;
    final onLongPress = this.onLongPress;
    final trailing = this.trailing;
    void toggle() {
      TavliPlatform.selectionFeedback(context);
      onChanged!(!checked);
    }

    final box = _CheckBox(checked: checked, enabled: enabled);
    final texts = <Widget>[
      Expanded(
        child: Text(
          title,
          style: t.bodyLarge?.copyWith(
            fontSize: 16,
            height: 1.35,
            color: muted ? c.onSurfaceVariant : c.onSurface,
            decoration: checked ? TextDecoration.lineThrough : null,
            decorationColor: c.onSurfaceVariant,
          ),
        ),
      ),
      if (detail != null) ...[
        const SizedBox(width: TavliSpacing.small),
        Text(
          detail,
          style: t.bodyMedium?.copyWith(
            fontSize: 15,
            height: 1.35,
            color: c.onSurfaceVariant,
          ),
        ),
      ],
    ];
    final actions = onLongPress == null
        ? null
        : {CustomSemanticsAction(label: longPressLabel!): onLongPress};

    if (onSelect == null) {
      final row = MergeSemantics(
        child: Semantics(
          checked: checked,
          enabled: enabled,
          customSemanticsActions: actions,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? toggle : null,
              onLongPress: onLongPress,
              borderRadius: _rowRadius,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: _rowPadding,
                  child: Row(
                    children: [box, const SizedBox(width: 12), ...texts],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      if (trailing == null) return row;
      // Dugme desno je posebna radnja, ne deo reda za čitač ekrana.
      return Row(
        children: [
          Expanded(child: row),
          trailing,
        ],
      );
    }

    // Lista i detalj: polje štiklira, ostatak reda bira.
    return Material(
      color: selected ? c.primaryContainer : Colors.transparent,
      child: Row(
        children: [
          Semantics(
            checked: checked,
            enabled: enabled,
            label: title,
            child: InkWell(
              onTap: enabled ? toggle : null,
              customBorder: const CircleBorder(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                child: Center(child: box),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              customSemanticsActions: actions,
              child: InkWell(
                onTap: onSelect,
                onLongPress: onLongPress,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: TavliSpacing.medium,
                      top: TavliSpacing.small,
                      bottom: TavliSpacing.small,
                    ),
                    child: Row(children: texts),
                  ),
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Red sa prekidačem (podešavanja): naziv, opcioni podnaslov ispod i
/// prekidač desno. Ceo red menja vrednost, visina najmanje 52.
class TavliSwitchRow extends StatelessWidget {
  const TavliSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;

  /// Objašnjenje ispod naziva, npr. „Kalorije se ne prikazuju u planu“.
  final String? subtitle;
  final bool value;

  /// `null` isključuje red.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final enabled = onChanged != null;
    final subtitle = this.subtitle;
    return MergeSemantics(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? () => onChanged!(!value) : null,
          borderRadius: _rowRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: _rowPadding,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: t.bodyLarge?.copyWith(
                            fontSize: 16,
                            height: 1.35,
                            color: enabled ? c.onSurface : c.onSurfaceVariant,
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
                  const SizedBox(width: 12),
                  Switch(value: value, onChanged: onChanged),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
