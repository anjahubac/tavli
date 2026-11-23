import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/recipe_format.dart';

/// Jedinice za izbor kod količine u ostavi.
const pantryUnits = ['kom', 'g', 'kg', 'ml', 'l'];

/// Količina (nije obavezna) sa minus/plus i jedinicom, i dugme za čuvanje.
/// Zajedničko za „Dodaj namirnicu“ i izmenu količine.
/// [onSave] dobija količinu (`null` kad je polje prazno ili 0) i jedinicu
/// (`null` bez količine).
class PantryAmountForm extends StatefulWidget {
  const PantryAmountForm({
    super.key,
    required this.saveLabel,
    required this.onSave,
    this.initialQuantity,
    this.initialUnit = 'kom',
    this.note,
  });

  final double? initialQuantity;
  final String initialUnit;
  final String saveLabel;
  final void Function(double? quantity, String? unit) onSave;

  /// Napomena ispod izbora jedinice.
  final String? note;

  @override
  State<PantryAmountForm> createState() => _PantryAmountFormState();
}

class _PantryAmountFormState extends State<PantryAmountForm> {
  late final _quantity = TextEditingController(
    text: widget.initialQuantity == null
        ? ''
        : formatQuantity(widget.initialQuantity!),
  );
  late String _unit = widget.initialUnit;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  double? get _value {
    final v = double.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    return v != null && v.isFinite && v > 0 ? v : null;
  }

  void _step(double by) {
    final next = ((_value ?? 0) + by).clamp(0, 1e6).toDouble();
    setState(() => _quantity.text = next <= 0 ? '' : formatQuantity(next));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TavliSpacing.medium,
      children: [
        Text('Količina (nije obavezna)', style: theme.textTheme.titleSmall),
        Row(
          spacing: TavliSpacing.small,
          children: [
            TavliIconButton(
              glyph: const TavliIconData('minus', ['M5 12h14']),
              semanticLabel: 'Manje',
              onPressed: () => _step(-1),
            ),
            Expanded(
              child: TavliTextField(
                controller: _quantity,
                hint: '0',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
            TavliIconButton(
              glyph: TavliIcons.add,
              semanticLabel: 'Više',
              onPressed: () => _step(1),
            ),
          ],
        ),
        Text('Jedinica', style: theme.textTheme.titleSmall),
        TavliChoice<String>.chips(
          options: [
            for (final u in {...pantryUnits, widget.initialUnit})
              TavliOption(u, u),
          ],
          selected: _unit,
          onChanged: (u) => setState(() => _unit = u),
        ),
        if (widget.note case final note?)
          Text(
            note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        TavliButton.primary(
          label: widget.saveLabel,
          onPressed: () {
            final q = _value;
            widget.onSave(q, q == null ? null : _unit);
          },
        ),
      ],
    );
  }
}
