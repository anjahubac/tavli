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
  'Sastojci: imam / u kupovinu',
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

/// Štikliraju se sastojci koje imamo; samo neštiklirani (oni koji
/// nedostaju) odlaze u Kupovinu dugmetom, a bedž poskoči.
class _CheckDemo extends StatefulWidget {
  const _CheckDemo();

  @override
  State<_CheckDemo> createState() => _CheckDemoState();
}

class _CheckDemoState extends State<_CheckDemo> {
  static const _items = [
    ('Krompir', '1 kg'),
    ('Mleveno meso', '500 g'),
    ('Crni luk', '2 kom'),
  ];
  final _keys = [for (final _ in _items) GlobalKey()];
  final _to = GlobalKey();
  final _have = <int>{1};
  int _count = 0;

  List<int> get _missing => [
    for (var i = 0; i < _items.length; i++)
      if (!_have.contains(i)) i,
  ];

  Future<void> _send() async {
    final missing = _missing;
    await Future.wait([
      for (final i in missing)
        flyChipToTarget(
          context: context,
          from: _keys[i],
          to: _to,
          label: _items[i].$1,
        ),
    ]);
    if (mounted) setState(() => _count += missing.length);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final missing = _missing.length;
    return Column(
      children: [
        Text(
          'Označi sastojke koje već imaš',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        for (final (i, (name, qty)) in _items.indexed)
          ListTile(
            onTap: () => setState(
              () => _have.contains(i) ? _have.remove(i) : _have.add(i),
            ),
            leading: AnimatedCheckmark(
              key: _keys[i],
              checked: _have.contains(i),
            ),
            // Ono što imamo je utišano i ne ide u kupovinu.
            title: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: DefaultTextStyle.of(context).style.copyWith(
                color: _have.contains(i)
                    ? colors.onSurfaceVariant
                    : colors.onSurface,
              ),
              child: Text(name),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_have.contains(i)) ...[
                  const _HaveTag(),
                  const SizedBox(width: 8),
                ],
                Text(qty),
              ],
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: missing == 0 ? null : _send,
          icon: const Icon(Icons.shopping_basket_outlined),
          label: Text('Dodaj u kupovinu ($missing)'),
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

/// Mala oznaka "imam" uz sastojak koji je kod kuće.
class _HaveTag extends StatelessWidget {
  const _HaveTag();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.primaryContainer,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          'imam',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: colors.onPrimaryContainer),
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
