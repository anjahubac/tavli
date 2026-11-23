import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../app/animations/all_bought.dart';
import '../../app/animations/egg_timer.dart';
import '../../app/animations/empty_basket.dart';
import '../../app/animations/empty_fridge.dart';
import '../../app/animations/empty_tabs.dart';
import '../../app/animations/intro_skillet.dart';
import '../../app/animations/photo_scan.dart';
import '../../app/animations/simmering_pot.dart';
import '../../app/animations/spoon_refresh.dart';
import '../recipes/keep_screen_on.dart';

/// Jedna animacija u galeriji: naslov, gde i kada se koristi i sam prikaz.
class AnimationEntry {
  const AnimationEntry(this.title, this.where, this.build);

  final String title;

  /// Gde u aplikaciji i kada se pojavljuje.
  final String where;
  final WidgetBuilder build;
}

/// Sve animacije u aplikaciji, redom kojim se pojavljuju.
final animationEntries = <AnimationEntry>[
  AnimationEntry(
    'Uvod sa tiganjem',
    'Pri pokretanju aplikacije, dok se učitava prethodna prijava.',
    (_) => const IntroSkillet(),
  ),
  AnimationEntry(
    'Ne gasi ekran (sunce i mesec)',
    'Detalj recepta i režim kuvanja, kad se opcija „Ne gasi ekran“ uključi '
        'ili isključi.',
    (_) => const _SunMoonDemo(),
  ),
  AnimationEntry(
    'Prazan sto (Početna)',
    'Tab Početna, dok još nema šta da se prikaže (prva prijava).',
    (_) => const EmptyTable(),
  ),
  AnimationEntry(
    'Prazna nedelja (Plan)',
    'Tab Plan, dok nijedan obrok nije planiran.',
    (_) => const EmptyWeek(),
  ),
  AnimationEntry(
    'Prazna kuvarica (Recepti)',
    'Tab Recepti, dok još nema nijednog recepta (ne i kad pretraga ili '
        'filter ništa ne nađu).',
    (_) => const EmptyCookbook(),
  ),
  AnimationEntry(
    'Prazna korpa (Nabavka)',
    'Tab Nabavka, dok je spisak prazan.',
    (_) => const EmptyBasket(),
  ),
  AnimationEntry(
    'Prazan frižider (Ostava)',
    'Tab Ostava, dok nema unetih namirnica.',
    (_) => const EmptyFridge(),
  ),
  AnimationEntry(
    'Lonac koji krčka',
    'Recepti → Novi recept → Po nazivu jela, i u četu „Izmeni sa AI“, dok AI '
        'piše recept. Vrti se dok odgovor ne stigne, a ispod se smenjuju '
        'poruke.',
    (_) => const SimmeringPot(),
  ),
  AnimationEntry(
    'Skeniranje fotografije',
    'Recepti → Novi recept → Iz slike, preko izabrane fotografije dok AI '
        'čita sliku. Kad sastojci stignu, iskaču ispod slike jedan po jedan.',
    (_) => const _PhotoScanDemo(),
  ),
  AnimationEntry(
    'Varjača (osvežavanje)',
    'Recepti, kad se lista povuče nadole radi osvežavanja. Vrti se dok '
        'osvežavanje traje.',
    (_) => const _SpoonDemo(),
  ),
  AnimationEntry(
    'Sve kupljeno',
    'Nabavka, kad se štiklira poslednja stavka sa spiska. Igra jednom.',
    (_) => const _AllBoughtDemo(),
  ),
  AnimationEntry(
    'Tajmer sa jajetom',
    'Još nije u aplikaciji. Planirano za režim kuvanja, kad korak ima '
        'vreme i tajmer je uključen.',
    (_) => const _EggDemo(),
  ),
];

/// Nazivi animacija u galeriji, redom.
List<String> get animationNames => [for (final e in animationEntries) e.title];

/// Profil → Animacije (samo debug): sve animacije na jednom mestu, svaka sa
/// opisom gde i kada se pojavljuje.
class AnimationsGalleryScreen extends StatelessWidget {
  const AnimationsGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Animacije')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: animationEntries.length,
        itemBuilder: (context, i) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _DemoCard(entry: animationEntries[i]),
          ),
        ),
      ),
    );
  }
}

/// Kartica sa naslovom, opisom i dugmetom "Ponovi" koje pokreće animaciju
/// iznova.
class _DemoCard extends StatefulWidget {
  const _DemoCard({required this.entry});

  final AnimationEntry entry;

  @override
  State<_DemoCard> createState() => _DemoCardState();
}

class _DemoCardState extends State<_DemoCard> {
  int _run = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final title = Text(
                  widget.entry.title,
                  style: theme.textTheme.titleMedium,
                );
                final replay = TextButton.icon(
                  onPressed: () => setState(() => _run++),
                  icon: const Icon(Icons.replay),
                  label: const Text('Ponovi'),
                );
                if (constraints.maxWidth < 360 &&
                    MediaQuery.textScalerOf(context).scale(16) > 20) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      Align(alignment: Alignment.centerRight, child: replay),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    replay,
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              widget.entry.where,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: KeyedSubtree(
                key: ValueKey(_run),
                child: Builder(builder: widget.entry.build),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sunce i mesec se smenjuju kao kad se opcija uključuje i isključuje.
class _SunMoonDemo extends StatefulWidget {
  const _SunMoonDemo();

  @override
  State<_SunMoonDemo> createState() => _SunMoonDemoState();
}

class _SunMoonDemoState extends State<_SunMoonDemo> {
  bool _on = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (mounted) setState(() => _on = !_on);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeepScreenOnToggle(on: _on, onPressed: () => setState(() => _on = !_on));
}

class _PhotoScanDemo extends StatefulWidget {
  const _PhotoScanDemo();

  @override
  State<_PhotoScanDemo> createState() => _PhotoScanDemoState();
}

class _PhotoScanDemoState extends State<_PhotoScanDemo> {
  bool _scanning = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _scanning = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PhotoScan(
      height: 180,
      scanning: _scanning,
      ingredients: const ['Kupus', 'Mleveno meso', 'Pirinač', 'Crni luk'],
      // Umesto prave slike: stranica kuvara nacrtana bojama teme.
      photo: ColoredBox(
        color: colors.tertiaryContainer,
        child: Icon(
          Icons.menu_book,
          size: 72,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _AllBoughtDemo extends StatelessWidget {
  const _AllBoughtDemo();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const AllBoughtArt(),
      Text(
        'Sve je kupljeno.',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    ],
  );
}

class _SpoonDemo extends StatelessWidget {
  const _SpoonDemo();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 200,
    child: SpoonRefresh(
      onRefresh: () => Future<void>.delayed(const Duration(seconds: 2)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              'Povuci nadole',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    ),
  );
}

class _EggDemo extends StatefulWidget {
  const _EggDemo();

  @override
  State<_EggDemo> createState() => _EggDemoState();
}

class _EggDemoState extends State<_EggDemo> {
  static const _total = Duration(minutes: 6);
  Duration _left = _total;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left -= const Duration(seconds: 1));
      if (_left <= Duration.zero) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('Kuvam jaje', style: Theme.of(context).textTheme.titleMedium),
      EggTimer(running: _left > Duration.zero, remaining: _left, total: _total),
    ],
  );
}
