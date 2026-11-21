import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tavli_colors.dart';
import '../tokens.dart';
import 'tavli_icon_button.dart';

/// Zajednički izgled polja: visina 48 (60 za [tall]), radijus 16, tekst 16.
InputDecoration _decoration(
  BuildContext context, {
  bool tall = false,
  String? hint,
  String? error,
  bool enabled = true,
  Widget? prefix,
  Widget? suffix,
}) {
  final c = Theme.of(context).colorScheme;
  final x = TavliColors.of(context);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(TavliRadius.field),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    errorText: error,
    errorMaxLines: 3,
    hintStyle: TextStyle(color: c.onSurfaceVariant),
    filled: true,
    fillColor: enabled ? c.surface : Color.lerp(x.bg, x.line, 0.5),
    isDense: true,
    constraints: BoxConstraints(minHeight: tall ? 60 : 48),
    contentPadding: EdgeInsets.symmetric(
      horizontal: 16,
      vertical: tall ? 18 : 12,
    ),
    prefixIcon: prefix,
    prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 48),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    border: border(x.line),
    enabledBorder: border(x.line),
    disabledBorder: border(x.line),
    focusedBorder: border(c.primary, 2),
    errorBorder: border(c.error),
    focusedErrorBorder: border(c.error, 2),
  );
}

TextStyle? _textStyle(BuildContext context, {bool enabled = true}) {
  final c = Theme.of(context).colorScheme;
  return Theme.of(context).textTheme.bodyLarge?.copyWith(
    fontSize: 16,
    height: 1.5,
    color: enabled ? c.onSurface : c.onSurfaceVariant,
  );
}

/// Polje za unos sa nazivom iznad. Varijante: obično, sa greškom
/// ([errorText]) i isključeno ([enabled]).
class TavliTextField extends StatelessWidget {
  const TavliTextField({
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofocus = false,
    this.obscureText = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.autofillHints,
    this.focusNode,
    this.autocorrect = true,
    this.isCode = false,
    this.trailing,
    this.textCapitalization = TextCapitalization.none,
    this.tall = false,
  }) : assert(controller == null || initialValue == null),
       assert(minLines <= maxLines);

  /// Naziv iznad polja, npr. „Naziv recepta“.
  final String? label;

  /// Primer u praznom polju, npr. „npr. Sarma“.
  final String? hint;

  /// Greška ispod polja; polje dobija crvenu ivicu.
  final String? errorText;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final bool obscureText;

  /// Više redova za duži tekst (npr. napomena); polje raste do toliko.
  final int maxLines;

  /// Koliko redova polje ima i kad je prazno (npr. koraci pripreme).
  final int minLines;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;

  /// `false` za e-poštu, kodove i nazive koje ne treba ispravljati.
  final bool autocorrect;

  /// Jednokratni kod iz poruke: veće cifre sa razmakom između njih.
  final bool isCode;

  /// Dugme na desnom kraju polja, npr. `TavliIconButton` „Prikaži“.
  final Widget? trailing;

  /// npr. [TextCapitalization.words] za ime.
  final TextCapitalization textCapitalization;

  /// Visoko polje (60) za jedino polje na ekranu, kao na prijavi i
  /// registraciji (kanvas).
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final style = _textStyle(context, enabled: enabled);
    final field = TextFormField(
      focusNode: focusNode,
      autocorrect: autocorrect,
      controller: controller,
      initialValue: initialValue,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      autofocus: autofocus,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      minLines: obscureText ? 1 : minLines,
      maxLines: obscureText ? 1 : maxLines,
      autofillHints: autofillHints,
      style: isCode
          ? style?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 8,
              height: 1.2,
            )
          : style,
      decoration: _decoration(
        context,
        tall: tall,
        hint: hint,
        error: errorText,
        enabled: enabled,
        // Svoj čvor za čitač ekrana: bez njega dugme u polju koje je
        // izašlo iz vidnog dela liste ostaje kao nevidljiv čvor.
        suffix: trailing == null
            ? null
            : Semantics(container: true, child: trailing),
      ),
    );
    final label = this.label;
    if (label == null) return field;
    final c = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: enabled ? c.onSurface : c.onSurfaceVariant,
                ),
              ),
            ),
          ),
          field,
        ],
      ),
    );
  }
}

/// Polje za pretragu: lupa levo, a „Obriši pretragu“ desno kada ima teksta.
class TavliSearchField extends StatefulWidget {
  const TavliSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  /// Npr. „Pretraži recepte“; čita ga i čitač ekrana.
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<TavliSearchField> createState() => _TavliSearchFieldState();
}

class _TavliSearchFieldState extends State<TavliSearchField> {
  TextEditingController? _own;

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(TavliSearchField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own)?.removeListener(_changed);
      _controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _own?.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      style: _textStyle(context),
      decoration: _decoration(
        context,
        hint: widget.hint,
        prefix: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 14,
            end: TavliSpacing.small - 2,
          ),
          child: Icon(Icons.search, size: 22, color: c.onSurfaceVariant),
        ),
        suffix: _controller.text.isEmpty
            ? null
            : TavliIconButton(
                icon: Icons.close,
                semanticLabel: 'Obriši pretragu',
                onPressed: _clear,
              ),
      ),
    );
  }
}
