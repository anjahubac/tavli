import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// Koliko dugo kratka poruka ostaje na ekranu.
const tavliMessageDuration = Duration(seconds: 5);

/// Izgled kratke poruke: tamna traka radijusa 16, tekst i opciona akcija
/// („Vrati“). Prikazuje se sa [showTavliMessage].
class TavliMessageBar extends StatelessWidget {
  const TavliMessageBar({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final actionLabel = this.actionLabel;
    return Material(
      color: c.inverseSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TavliRadius.field),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: TavliSpacing.large - 4,
          end: TavliSpacing.small,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    message,
                    style: t.bodyMedium?.copyWith(
                      fontSize: 15,
                      height: 1.35,
                      color: c.onInverseSurface,
                    ),
                  ),
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: c.inversePrimary,
                    minimumSize: const Size(48, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(TavliRadius.compact),
                    ),
                    textStyle: t.labelLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(actionLabel),
                )
              else
                const SizedBox(width: TavliSpacing.small),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kratka poruka na dnu ekrana sa opcionom akcijom. Nestaje posle 5 s,
/// i kada ima akciju; nova poruka zamenjuje prethodnu.
void showTavliMessage(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) => showTavliMessageOn(
  ScaffoldMessenger.of(context),
  message,
  actionLabel: actionLabel,
  onAction: onAction,
);

/// Isto što i [showTavliMessage], preko [messenger] uzetog ranije: za
/// poruku posle radnje koja zatvara ekran (npr. brisanje recepta).
void showTavliMessageOn(
  ScaffoldMessengerState messenger,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: tavliMessageDuration,
        persist: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        content: TavliMessageBar(
          message: message,
          actionLabel: actionLabel,
          onAction: onAction == null
              ? null
              : () {
                  messenger.hideCurrentSnackBar(
                    reason: SnackBarClosedReason.action,
                  );
                  onAction();
                },
        ),
      ),
    );
}
