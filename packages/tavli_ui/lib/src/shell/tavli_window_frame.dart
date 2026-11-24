import 'package:material_ui/material_ui.dart';

import '../platform.dart';
import 'tavli_menu_bar.dart';
import 'windows_title_bar.dart';

/// Okvir prozora na računaru.
///
/// Windows: naslovna traka visine 40 koju crta aplikacija: naziv levo, meni
/// u prozoru (Datoteka, Uređivanje, Prikaz, Pomoć, iz [TavliMenuBar]) i
/// dugmad prozora desno (umanji, uvećaj ili vrati, zatvori). Prazan deo
/// trake pomera prozor, dvoklik ga uvećava, desni klik otvara sistemski
/// meni, a gornja ivica menja visinu.
/// macOS: bez trake; prozor crta sadržaj ispod providne naslovne trake, pa
/// semafori stoje u vrhu bočne navigacije, koja za njih ostavlja prostor.
/// Ekrani bez bočne navigacije (prijava, uzan prozor) dobijaju gornju
/// marginu [macosTitleBarHeight] kroz `MediaQuery.padding`, kao `SafeArea`.
/// Telefon: samo sadržaj.
class TavliWindowFrame extends StatelessWidget {
  const TavliWindowFrame({
    super.key,
    this.title = 'Tavli',
    this.macosFullScreen = false,
    this.windowControls = const TavliWindowControls(),
    required this.child,
  });

  final String title;
  final bool macosFullScreen;

  /// Radnje dugmadi i trake prozora na Windows-u.
  final TavliWindowControls windowControls;
  final Widget child;

  /// Visina naslovne trake na Windows-u.
  static const windowsTitleBarHeight = 40.0;

  /// Prostor za semafore prozora na macOS-u, iznad sadržaja ili u vrhu
  /// bočne navigacije.
  static const macosTitleBarHeight = 52.0;

  /// Prostor za semafore nestaje kada prozor pređe preko celog ekrana.
  static double macosTitleBarInsetOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MacosWindowChrome>()?.inset ??
      macosTitleBarHeight;

  @override
  Widget build(BuildContext context) {
    final platform = TavliPlatform.of(context);
    if (platform == TavliPlatform.macos) {
      final media = MediaQuery.of(context);
      EdgeInsets top(EdgeInsets e) => e.copyWith(
        top: e.top < macosTitleBarHeight ? macosTitleBarHeight : e.top,
      );
      return _MacosWindowChrome(
        inset: macosFullScreen ? 0 : macosTitleBarHeight,
        child: MediaQuery(
          data: macosFullScreen
              ? media
              : media.copyWith(
                  padding: top(media.padding),
                  viewPadding: top(media.viewPadding),
                ),
          child: child,
        ),
      );
    }
    if (platform != TavliPlatform.windows) return child;
    // Meniji i opisi dugmadi prozora otvaraju se iznad sadržaja, a okvir
    // stoji iznad navigatora aplikacije.
    return Overlay.wrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WindowsTitleBar(title: title, controls: windowControls),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MacosWindowChrome extends InheritedWidget {
  const _MacosWindowChrome({required this.inset, required super.child});

  final double inset;

  @override
  bool updateShouldNotify(_MacosWindowChrome oldWidget) =>
      inset != oldWidget.inset;
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
    removeTop:
        TavliPlatform.of(context) == TavliPlatform.macos &&
        TavliWindowFrame.macosTitleBarInsetOf(context) > 0,
    child: child,
  );
}
