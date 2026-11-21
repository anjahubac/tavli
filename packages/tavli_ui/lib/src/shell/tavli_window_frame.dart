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
/// macOS: bez trake; prozor crta sadržaj ispod providne naslovne trake, pa
/// semafori stoje u vrhu bočne navigacije, koja za njih ostavlja prostor.
/// Ekrani bez bočne navigacije (prijava, uzan prozor) dobijaju gornju
/// marginu [macosTitleBarHeight] kroz `MediaQuery.padding`, kao `SafeArea`.
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

  /// Prostor za semafore prozora na macOS-u, iznad sadržaja ili u vrhu
  /// bočne navigacije.
  static const macosTitleBarHeight = 52.0;

  /// Širina tri dugmeta prozora na Windows-u (3 x 46).
  static const _windowsButtons = 138.0;

  @override
  Widget build(BuildContext context) {
    final platform = TavliPlatform.of(context);
    if (platform == TavliPlatform.macos) {
      final media = MediaQuery.of(context);
      EdgeInsets top(EdgeInsets e) => e.copyWith(
        top: e.top < macosTitleBarHeight ? macosTitleBarHeight : e.top,
      );
      return MediaQuery(
        data: media.copyWith(
          padding: top(media.padding),
          viewPadding: top(media.viewPadding),
        ),
        child: child,
      );
    }
    if (platform != TavliPlatform.windows) return child;
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

/// Sadržaj pored bočne navigacije. Na macOS-u semafori stoje u vrhu bočne
/// trake, pa sadržaj pored nje počinje od vrha prozora, bez gornje margine
/// koju dodaje [TavliWindowFrame].
class TavliBesideNavigation extends StatelessWidget {
  const TavliBesideNavigation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.removePadding(
    context: context,
    removeTop: TavliPlatform.of(context) == TavliPlatform.macos,
    child: child,
  );
}
