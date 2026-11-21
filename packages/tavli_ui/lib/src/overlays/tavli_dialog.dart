import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../controls/tavli_button.dart';
import '../platform.dart';
import '../tokens.dart';

/// Dugme u dijalogu: tekst i vrednost koju dijalog vraća.
class TavliDialogAction<T> {
  const TavliDialogAction(
    this.label,
    T value, {
    this.isDefault = false,
    this.isDestructive = false,
    this.enabled = true,
  }) : _value = value,
       _compute = null;

  /// Vrednost se uzima tek na dodir, npr. tekst iz polja u dijalogu.
  const TavliDialogAction.computed(
    this.label,
    ValueGetter<T> value, {
    this.isDefault = false,
    this.isDestructive = false,
    this.enabled = true,
  }) : _value = null,
       _compute = value;

  final String label;
  final T? _value;
  final ValueGetter<T>? _compute;

  /// Vrednost koju dijalog vraća kad se dodirne ovo dugme.
  T get value => _compute != null ? _compute() : _value as T;

  /// Glavna radnja (podebljana; na Androidu glavno dugme).
  final bool isDefault;

  /// Brisanje i druge nepovratne radnje (crveno).
  final bool isDestructive;

  /// `false` isključuje dugme (npr. „Sačuvaj“ dok je polje prazno).
  final bool enabled;
}

/// Dijalog: naslov, tekst ili sadržaj (forma) i dugmad.
///
/// Na iOS-u i macOS-u izgleda kao sistemski dijalog; na Androidu i
/// Windows-u radijus 24, dugmad desno, iste visine. Otvara se sa
/// [showTavliDialog] ili [showTavliConfirm].
class TavliDialog<T> extends StatelessWidget {
  const TavliDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    required this.actions,
  });

  final String title;
  final String? message;

  /// Polja ili izbor ispod teksta.
  final Widget? content;
  final List<TavliDialogAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    void pop(T value) => Navigator.of(context).pop(value);
    final message = this.message;
    final content = this.content;

    if (TavliPlatform.of(context).isApple) {
      return CupertinoAlertDialog(
        title: Text(title),
        content: message == null && content == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message != null) Text(message),
                  if (content != null) ...[
                    if (message != null) const SizedBox(height: 12),
                    Material(type: MaterialType.transparency, child: content),
                  ],
                ],
              ),
        actions: [
          for (final a in actions)
            CupertinoDialogAction(
              isDefaultAction: a.isDefault,
              isDestructiveAction: a.isDestructive,
              onPressed: a.enabled ? () => pop(a.value) : null,
              child: Text(a.label),
            ),
        ],
      );
    }

    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TavliRadius.sheet),
      ),
      insetPadding: const EdgeInsets.all(TavliSpacing.large),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TavliWidth.dialog),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: t.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: c.onSurface,
                  ),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: TavliSpacing.small),
                Text(
                  message,
                  style: t.bodyMedium?.copyWith(
                    fontSize: 15,
                    height: 1.45,
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
              if (content != null) ...[
                const SizedBox(height: TavliSpacing.medium),
                content,
              ],
              const SizedBox(height: TavliSpacing.large),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                // Kad dugmad ne staju u red (uzak ekran, krupan tekst), idu
                // jedno ispod drugog, poravnata desno.
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  // Isti razmak kao u `TavliButtonRow`.
                  spacing: 10,
                  overflowSpacing: TavliSpacing.small,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: [
                    for (final a in actions)
                      if (a.isDestructive)
                        TavliButton.destructive(
                          label: a.label,
                          onPressed: a.enabled ? () => pop(a.value) : null,
                        )
                      else if (a.isDefault)
                        TavliButton.primary(
                          label: a.label,
                          onPressed: a.enabled ? () => pop(a.value) : null,
                        )
                      else
                        TavliButton.text(
                          label: a.label,
                          onPressed: a.enabled ? () => pop(a.value) : null,
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Otvara [TavliDialog]. Vraća vrednost izabranog dugmeta, ili `null` kada
/// se dijalog zatvori dodirom van njega (Android, Windows) ili tasterom Esc.
Future<T?> showTavliDialog<T>(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  required List<TavliDialogAction<T>> actions,
}) {
  final dialog = TavliDialog<T>(
    title: title,
    message: message,
    content: content,
    actions: actions,
  );
  if (TavliPlatform.of(context).isApple) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (_) => dialog,
    );
  }
  return showDialog<T>(context: context, builder: (_) => dialog);
}

/// Potvrda pre radnje: „Otkaži“ i [confirmLabel]. Vraća `true` samo kada je
/// radnja potvrđena.
Future<bool> showTavliConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Otkaži',
  bool destructive = false,
}) async {
  final result = await showTavliDialog<bool>(
    context,
    title: title,
    message: message,
    actions: [
      TavliDialogAction(cancelLabel, false),
      TavliDialogAction(
        confirmLabel,
        true,
        isDefault: !destructive,
        isDestructive: destructive,
      ),
    ],
  );
  return result ?? false;
}
