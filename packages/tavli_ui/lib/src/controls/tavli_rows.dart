import 'package:material_ui/material_ui.dart';

import '../theme/tavli_colors.dart';
import '../tokens.dart';

const _rowPadding = EdgeInsets.symmetric(
  horizontal: TavliSpacing.medium,
  vertical: TavliSpacing.small,
);
const _rowRadius = BorderRadius.all(Radius.circular(TavliRadius.field));

/// Polje za štikliranje: 22 x 22, radijus 8. Samo crtež; dodir i opis za
/// čitač ekrana daje red koji ga sadrži.
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
            ? Icon(Icons.check_rounded, size: 16, color: c.onPrimary)
            : null,
      ),
    );
  }
}

/// Red sa poljem za štikliranje (stavka nabavke). Štiklirana stavka je
/// precrtana i prigušena. Ceo red je polje za dodir, visina najmanje 52.
///
/// Red nema pozadinu ni ivicu: stavlja se u grupisanu listu ili karticu.
class TavliCheckRow extends StatelessWidget {
  const TavliCheckRow({
    super.key,
    required this.title,
    required this.checked,
    required this.onChanged,
    this.detail,
  });

  final String title;

  /// Kratak podatak desno, npr. količina „1,5 kg“.
  final String? detail;
  final bool checked;

  /// `null` isključuje red.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final enabled = onChanged != null;
    final muted = checked || !enabled;
    final detail = this.detail;
    return MergeSemantics(
      child: Semantics(
        checked: checked,
        enabled: enabled,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? () => onChanged!(!checked) : null,
            borderRadius: _rowRadius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: _rowPadding,
                child: Row(
                  children: [
                    _CheckBox(checked: checked, enabled: enabled),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: t.bodyLarge?.copyWith(
                          fontSize: 16,
                          height: 1.35,
                          color: muted ? c.onSurfaceVariant : c.onSurface,
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
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
