import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/animations/egg_timer.dart';
import '../../app/animations/empty_fridge.dart';
import '../../app/animations/ingredient_check.dart';
import '../../app/animations/intro_motif.dart';
import '../../app/animations/photo_scan.dart';
import '../../app/animations/plate_drop.dart';
import '../../app/animations/shopping_bag.dart';
import '../../app/animations/simmering_pot.dart';
import '../../app/animations/spoon_refresh.dart';
import '../../domain/theme_choice.dart';

/// Nazivi animacija u galeriji, redom.
const animationNames = [
  'Uvod — Bosiljak',
  'Uvod — Šafran',
  'Uvod — Borovnica',
  'Skeniranje fotografije',
  'Lonac koji krčka',
  'Štikliranje sastojka',
  'Sve kupljeno',
  'Prazna ostava',
  'Varjača (osvežavanje)',
  'Tanjir u planu',
  'Tajmer sa jajetom',
];

/// Profil → Animacije (samo debug): sve animacije na jednom mestu.
class AnimationsGalleryScreen extends StatelessWidget {
  const AnimationsGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demos = <Widget>[
      for (final t in TavliTheme.values) IntroMotif(motif: t, size: 200),
      const _PhotoScanDemo(),
      const SimmeringPot(),
      const _CheckDemo(),
      const _AllBoughtDemo(),
      const EmptyFridge(),
      const _SpoonDemo(),
      const PlatePlanDrop(),
      const _EggDemo(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Animacije')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: demos.length,
        itemBuilder: (context, i) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _DemoCard(title: animationNames[i], child: demos[i]),
          ),
        ),
      ),
    );
  }
}

/// Kartica sa naslovom i dugmetom "Ponovi" koje pokreće animaciju iznova.
class _DemoCard extends StatefulWidget {
  const _DemoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  State<_DemoCard> createState() => _DemoCardState();
}

class _DemoCardState extends State<_DemoCard> {
  int _run = 0;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _run++),
                  icon: const Icon(Icons.replay),
                  label: const Text('Ponovi'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            KeyedSubtree(key: ValueKey(_run), child: widget.child),
          ],
        ),
      ),
    );
  }
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

class _CheckDemo extends StatefulWidget {
  const _CheckDemo();

  @override
  State<_CheckDemo> createState() => _CheckDemoState();
}

class _CheckDemoState extends State<_CheckDemo> {
  final _from = GlobalKey();
  final _to = GlobalKey();
  bool _checked = false;
  int _count = 2;

  Future<void> _toggle() async {
    setState(() => _checked = !_checked);
    if (!_checked) {
      setState(() => _count--);
      return;
    }
    await flyChipToTarget(
      context: context,
      from: _from,
      to: _to,
      label: 'Mleveno meso',
    );
    if (mounted) setState(() => _count++);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        ListTile(
          onTap: _toggle,
          leading: AnimatedCheckmark(key: _from, checked: _checked),
          title: const Text('Mleveno meso'),
          trailing: const Text('500 g'),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            BumpBadge(
              key: _to,
              count: _count,
              child: Icon(
                Icons.shopping_basket,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            const Text('Kupovina'),
          ],
        ),
      ],
    );
  }
}

class _AllBoughtDemo extends StatelessWidget {
  const _AllBoughtDemo();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const ShoppingBagFull(),
      Text(
        'Sve je kupljeno!',
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
      EggTimer(running: _left > Duration.zero, remaining: _left),
    ],
  );
}
