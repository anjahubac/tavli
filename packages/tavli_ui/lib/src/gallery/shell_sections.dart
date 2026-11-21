import 'package:material_ui/material_ui.dart';

import '../controls/tavli_button.dart';
import '../controls/tavli_choice.dart';
import '../icons/tavli_icons.dart';
import '../platform.dart';
import '../shell/tavli_action_bar.dart';
import '../shell/tavli_app_bar.dart';
import '../shell/tavli_floating_button.dart';
import '../shell/tavli_navigation.dart';
import '../shell/tavli_page_header.dart';
import '../shell/tavli_window_frame.dart';
import '../theme/tavli_colors.dart';
import '../tokens.dart';
import 'gallery_section.dart';

/// Tabovi iz platna, u redosledu donje navigacije.
const galleryDestinations = [
  TavliDestination(icon: TavliIcons.plan, label: 'Plan'),
  TavliDestination(icon: TavliIcons.shopping, label: 'Nabavka'),
  TavliDestination(icon: TavliIcons.home, label: 'Početna', home: true),
  TavliDestination(icon: TavliIcons.recipes, label: 'Recepti'),
  TavliDestination(icon: TavliIcons.pantry, label: 'Ostava'),
];

/// Odeljci galerije za kostur ekrana i navigaciju.
class TavliShellGallerySections extends StatelessWidget {
  const TavliShellGallerySections({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = TavliPlatform.of(context).isDesktop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GallerySection(
          title: 'Kostur ekrana',
          child: desktop ? const _DesktopPreview() : const _PhonePreview(),
        ),
        GallerySection(
          title: 'Gornja traka',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Framed(child: TavliAppBar(initials: 'AH')),
              const SizedBox(height: TavliSpacing.medium),
              _Framed(
                child: TavliBackAppBar(
                  title: 'Izgled',
                  backLabel: 'Profil',
                  onBack: () {},
                ),
              ),
            ],
          ),
        ),
        GallerySection(
          title: 'Zaglavlje ekrana',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TavliPageHeader(
                overline: 'Petak, 13. novembar',
                title: 'Danas',
              ),
              const SizedBox(height: TavliSpacing.large),
              TavliPageHeader(
                title: 'Izgled',
                backLabel: 'Profil',
                onBack: () {},
              ),
              const SizedBox(height: TavliSpacing.large),
              TavliPageHeader(
                title: 'Recepti',
                actions: [
                  TavliButton.primary(
                    onPressed: () {},
                    icon: Icons.add,
                    label: 'Dodaj recept',
                  ),
                ],
              ),
            ],
          ),
        ),
        const GallerySection(
          title: 'Donja navigacija',
          child: _Framed(child: _NavigationDemo(TavliNavigationLayout.bottom)),
        ),
        const GallerySection(
          title: 'Bočna navigacija',
          child: _Framed(
            child: SizedBox(
              height: 400,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _NavigationDemo(TavliNavigationLayout.side),
              ),
            ),
          ),
        ),
        const GallerySection(
          title: 'Traka sa akcijama',
          child: _Framed(child: _PlanActions()),
        ),
        GallerySection(
          title: 'Plutajuće dugme',
          child: Align(
            alignment: Alignment.centerLeft,
            child: TavliFloatingButton(
              icon: Icons.add,
              label: 'Dodaj recept',
              onPressed: () {},
            ),
          ),
        ),
        GallerySection(
          title: 'Okvir prozora',
          child: _Framed(
            child: SizedBox(
              height: 120,
              child: TavliWindowFrame(
                child: Center(
                  child: Text(
                    switch (TavliPlatform.of(context)) {
                      TavliPlatform.windows => 'Sadržaj prozora',
                      TavliPlatform.macos => 'macOS: providna traka, semafori iznad sadržaja ili u bočnoj navigaciji',
                      _ => 'Telefon: bez okvira',
                    },
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ivica oko primera, da se vidi gde komponenta počinje i završava.
class _Framed extends StatelessWidget {
  const _Framed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: TavliColors.of(context).line),
        borderRadius: BorderRadius.circular(TavliRadius.compact),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TavliRadius.compact),
        child: ColoredBox(color: TavliColors.of(context).bg, child: child),
      ),
    );
  }
}

class _NavigationDemo extends StatefulWidget {
  const _NavigationDemo(this.layout);

  final TavliNavigationLayout layout;

  @override
  State<_NavigationDemo> createState() => _NavigationDemoState();
}

class _NavigationDemoState extends State<_NavigationDemo> {
  int? _selected = 2;
  bool _profile = false;

  @override
  Widget build(BuildContext context) => TavliNavigation(
    layout: widget.layout,
    destinations: galleryDestinations,
    selectedIndex: _selected,
    onSelected: (i) => setState(() {
      _selected = i;
      _profile = false;
    }),
    initials: 'AH',
    profileSelected: _profile,
    onProfile: () => setState(() {
      _selected = null;
      _profile = true;
    }),
  );
}

class _PlanActions extends StatelessWidget {
  const _PlanActions();

  @override
  Widget build(BuildContext context) => TavliActionBar(
    actions: [
      TavliButton.secondary(onPressed: () {}, label: 'Ponovo predloži'),
      TavliButton.primary(onPressed: () {}, label: 'Otvori nabavku'),
    ],
  );
}

/// Sadržaj taba u primeru kostura: zaglavlje i nekoliko praznih kartica.
/// Plan ima prekidač Nedelja i Mesec koji menja dužinu sadržaja, da se vidi
/// da traka sa akcijama ostaje na mestu.
class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.tab,
    required this.month,
    required this.onMonth,
    this.headerActions = const [],
  });

  final int tab;
  final bool month;
  final ValueChanged<bool> onMonth;
  final List<Widget> headerActions;

  @override
  Widget build(BuildContext context) {
    final label = galleryDestinations[tab].label;
    final home = galleryDestinations[tab].home;
    final cards = tab == 0 ? (month ? 8 : 3) : 3;
    final x = TavliColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TavliSpacing.large,
        TavliSpacing.small,
        TavliSpacing.large,
        TavliSpacing.large,
      ),
      children: [
        TavliPageHeader(
          overline: home ? 'Petak, 13. novembar' : null,
          title: home ? 'Danas' : label,
          actions: headerActions,
        ),
        if (tab == 0) ...[
          const SizedBox(height: TavliSpacing.medium),
          TavliChoice<bool>.segmented(
            options: const [
              TavliOption(false, 'Nedelja'),
              TavliOption(true, 'Mesec'),
            ],
            selected: month,
            onChanged: onMonth,
          ),
        ],
        for (var i = 0; i < cards; i++)
          Padding(
            padding: const EdgeInsets.only(top: TavliSpacing.medium),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: x.line),
                borderRadius: BorderRadius.circular(TavliRadius.card),
              ),
            ),
          ),
      ],
    );
  }
}

class _PhonePreview extends StatefulWidget {
  const _PhonePreview();

  @override
  State<_PhonePreview> createState() => _PhonePreviewState();
}

class _PhonePreviewState extends State<_PhonePreview> {
  int _tab = 0;
  bool _month = false;

  @override
  Widget build(BuildContext context) {
    final recipes = _tab == 3;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: _Framed(
          child: SizedBox(
            height: 700,
            // Primer nije ceo ekran: bez statusne trake i home indikatora.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              child: Scaffold(
                body: Column(
                  children: [
                    const TavliAppBar(initials: 'AH'),
                    Expanded(
                      child: _TabContent(
                        tab: _tab,
                        month: _month,
                        onMonth: (v) => setState(() => _month = v),
                      ),
                    ),
                    if (_tab == 0) const _PlanActions(),
                  ],
                ),
                floatingActionButton: recipes
                    ? TavliFloatingButton(
                        icon: Icons.add,
                        label: 'Dodaj recept',
                        onPressed: () {},
                      )
                    : null,
                bottomNavigationBar: TavliNavigation(
                  layout: TavliNavigationLayout.bottom,
                  destinations: galleryDestinations,
                  selectedIndex: _tab,
                  onSelected: (i) => setState(() => _tab = i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopPreview extends StatefulWidget {
  const _DesktopPreview();

  @override
  State<_DesktopPreview> createState() => _DesktopPreviewState();
}

class _DesktopPreviewState extends State<_DesktopPreview> {
  int? _tab = 2;
  bool _month = false;

  @override
  Widget build(BuildContext context) {
    final tab = _tab;
    final actions = switch (tab) {
      0 => [
        TavliButtonRow(
          children: [
            TavliButton.secondary(onPressed: () {}, label: 'Ponovo predloži'),
            TavliButton.primary(onPressed: () {}, label: 'Otvori nabavku'),
          ],
        ),
      ],
      3 => [
        TavliButton.primary(
          onPressed: () {},
          icon: Icons.add,
          label: 'Dodaj recept',
        ),
      ],
      _ => <Widget>[],
    };
    // Prozor 1100 x 680 smanjen da stane u galeriju.
    return _Framed(
      child: AspectRatio(
        aspectRatio: 1100 / 680,
        child: FittedBox(
          child: SizedBox(
            width: 1100,
            height: 680,
            child: TavliWindowFrame(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TavliNavigation(
                    layout: TavliNavigationLayout.side,
                    destinations: galleryDestinations,
                    selectedIndex: tab,
                    onSelected: (i) => setState(() => _tab = i),
                    initials: 'AH',
                    profileSelected: tab == null,
                    onProfile: () => setState(() => _tab = null),
                  ),
                  Expanded(
                    child: TavliBesideNavigation(
                      child: tab == null
                          ? const Padding(
                              padding: EdgeInsets.all(28),
                              child: TavliPageHeader(title: 'Profil'),
                            )
                          : _TabContent(
                              tab: tab,
                              month: _month,
                              onMonth: (v) => setState(() => _month = v),
                              headerActions: actions,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
