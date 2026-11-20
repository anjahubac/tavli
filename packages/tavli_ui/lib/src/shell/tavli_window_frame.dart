import 'package:material_ui/material_ui.dart';

import '../platform.dart';
import '../theme/tavli_colors.dart';
import 'shell_parts.dart';

/// Okvir prozora na računaru, za sada prazan.
///
/// Windows: naslovna traka visine 40 sa nazivom aplikacije levo i praznim
/// mestom desno za dugmad prozora (umanji, uvećaj, zatvori). Meni u
/// prozoru (Datoteka, Uređivanje, Prikaz, Pomoć) i prava dugmad stižu sa
/// Windows fazom.
/// macOS: bez trake; semafori prozora stoje u vrhu bočne navigacije, koja za
/// njih ostavlja prostor. Izgled prozora stiže sa fazom za Apple platforme.
/// Telefon: samo sadržaj.
class TavliWindowFrame extends StatelessWidget {
  const TavliWindowFrame({
    super.key,
    this.title = 'Tavli',
    required this.child,
  });

  final String title;
  final Widget child;

  /// Visina naslovne trake na Windows-u.
  static const windowsTitleBarHeight = 40.0;

  /// Širina tri dugmeta prozora na Windows-u (3 x 46).
  static const _windowsButtons = 138.0;

  @override
  Widget build(BuildContext context) {
    if (TavliPlatform.of(context) != TavliPlatform.windows) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: windowsTitleBarHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: shellSurface(context),
              border: Border(
                bottom: BorderSide(color: TavliColors.of(context).line),
              ),
            ),
            child: MediaQuery.withNoTextScaling(
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _windowsButtons),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
