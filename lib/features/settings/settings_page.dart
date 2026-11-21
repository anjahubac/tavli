import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/home_shell.dart' show wideLayoutWidth;

/// Da li ekran ima mesta za raspored kao na računaru (isto kao bočni meni).
bool isWideSettings(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= wideLayoutWidth;

/// Kostur ekrana Profil, Izgled i AI ključevi, kao na platnu.
///
/// Telefon: gornja traka sa povratkom i naslovom, sadržaj ispod.
/// Širok ekran: bez gornje trake; povratak i veliki naslov su na vrhu
/// sadržaja, a sadržaj je najviše [TavliWidth.page] širok.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.children,
    required this.fallbackLocation,
    this.backLabel,
  });

  final String title;

  /// Odeljci ekrana, odozgo nadole.
  final List<Widget> children;

  /// Kuda vodi povratak kad je ekran otvoren direktnom adresom.
  final String fallbackLocation;

  /// Naziv prethodnog ekrana (iOS traka i povratak na širokom ekranu).
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    void back() =>
        context.canPop() ? context.pop() : context.go(fallbackLocation);
    final wide = isWideSettings(context);
    final label = backLabel ?? 'Nazad';
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!wide)
            TavliBackAppBar(title: title, onBack: back, backLabel: label),
          Expanded(
            child: SafeArea(
              top: wide,
              child: ListView(
                padding: const EdgeInsets.all(TavliSpacing.large),
                children: [
                  Align(
                    alignment: AlignmentDirectional.topStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: TavliWidth.page,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: TavliSpacing.large,
                        children: [
                          if (wide)
                            TavliPageHeader(
                              title: title,
                              backLabel: label,
                              onBack: back,
                            ),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Odeljak: naslov velikim slovima („PODEŠAVANJA“) i sadržaj ispod.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: TavliSpacing.small,
    children: [TavliSectionHeader(title), ...children],
  );
}

/// Dve kolone na širokom ekranu, jedna ispod druge na telefonu.
class SettingsColumns extends StatelessWidget {
  const SettingsColumns({super.key, required this.start, required this.end});

  final List<Widget> start;
  final List<Widget> end;

  @override
  Widget build(BuildContext context) {
    Widget column(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TavliSpacing.large,
      children: children,
    );
    if (!isWideSettings(context)) return column([...start, ...end]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: TavliSpacing.large,
      children: [
        Expanded(child: column(start)),
        Expanded(child: column(end)),
      ],
    );
  }
}
