import 'package:material_ui/material_ui.dart';

import '../theme/tavli_colors.dart';
import '../tokens.dart';

/// Donji list: ručica, opcioni naslov i sadržaj. Radijus 24 na gornjim
/// uglovima. Otvara se sa [showTavliSheet]; ekran daje samo sadržaj.
class TavliSheet extends StatelessWidget {
  const TavliSheet({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final x = TavliColors.of(context);
    final title = this.title;
    return Material(
      color: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TavliRadius.sheet),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: SizedBox(
                    width: 36,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: x.boxLine,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TavliSpacing.large,
                    TavliSpacing.small,
                    TavliSpacing.large,
                    TavliSpacing.small,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: t.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.onSurface,
                      ),
                    ),
                  ),
                ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TavliSpacing.large,
                    TavliSpacing.small,
                    TavliSpacing.large,
                    TavliSpacing.large,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Otvara [TavliSheet] odozdo. Vraća vrednost kojom ga sadržaj zatvori
/// (`Navigator.pop(context, value)`), ili `null` kada se povuče nadole.
Future<T?> showTavliSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (context) => TavliSheet(title: title, child: builder(context)),
  );
}
