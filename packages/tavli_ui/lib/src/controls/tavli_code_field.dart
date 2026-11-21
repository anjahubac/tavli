import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tavli_colors.dart';
import '../tokens.dart';

/// Jednokratni kod iz poruke: [length] polja za cifre jedno do drugog
/// (kanvas: „Upiši kod“, „Proveri mejl“). Ispod je jedno obično polje, pa
/// rade nalepljivanje celog koda, automatsko popunjavanje iz poruke i
/// brisanje unazad. Razmaci i crtice iz nalepljenog koda se izbacuju.
class TavliCodeField extends StatefulWidget {
  const TavliCodeField({
    super.key,
    required this.label,
    required this.controller,
    this.onChanged,
    this.helper,
    this.length = 6,
    this.enabled = true,
    this.autofocus = false,
  });

  /// Naziv iznad polja, npr. „Kod iz poruke“.
  final String label;
  final TextEditingController controller;

  /// Posle svake izmene, sa samim ciframa.
  final ValueChanged<String>? onChanged;

  /// Pomoćni tekst ispod polja, npr. „Možeš i da nalepiš ceo kod.“
  final String? helper;
  final int length;
  final bool enabled;
  final bool autofocus;

  @override
  State<TavliCodeField> createState() => _TavliCodeFieldState();
}

class _TavliCodeFieldState extends State<TavliCodeField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void didUpdateWidget(TavliCodeField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final x = TavliColors.of(context);
    final digits = widget.controller.text;
    final active = _focus.hasFocus && widget.enabled;
    final digitStyle = theme.textTheme.headlineSmall?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: widget.enabled ? c.onSurface : c.onSurfaceVariant,
    );

    Widget box(int i) {
      final filled = i < digits.length;
      // Polje u koje ide sledeća cifra (ili poslednje, kad je kod pun).
      final current =
          active &&
          (i == digits.length ||
              (digits.length == widget.length && i == widget.length - 1));
      return DecoratedBox(
        decoration: BoxDecoration(
          color: widget.enabled ? c.surface : Color.lerp(x.bg, x.line, 0.5),
          borderRadius: BorderRadius.circular(TavliRadius.field),
          border: Border.all(
            color: current ? c.primary : (filled ? x.boxLine : x.line),
            width: current ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            filled ? digits[i] : '',
            textAlign: TextAlign.center,
            style: digitStyle,
          ),
        ),
      );
    }

    final helper = widget.helper;
    return Semantics(
      label: widget.label,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                widget.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: widget.enabled ? c.onSurface : c.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Stack(
            children: [
              ExcludeSemantics(
                child: Row(
                  spacing: TavliSpacing.small,
                  children: [
                    for (var i = 0; i < widget.length; i++)
                      Expanded(child: box(i)),
                  ],
                ),
              ),
              // Pravo polje preko kvadrata: prima dodir, tastaturu,
              // nalepljivanje i automatsko popunjavanje; samo je nevidljivo.
              Positioned.fill(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  showCursor: false,
                  style: const TextStyle(color: Colors.transparent),
                  cursorColor: Colors.transparent,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    isCollapsed: true,
                    counterText: '',
                  ),
                  expands: true,
                  maxLines: null,
                  onChanged: widget.onChanged,
                ),
              ),
            ],
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                helper,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  height: 1.4,
                  color: c.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
