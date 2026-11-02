import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';

import '../../account/auth_controller.dart';
import '../../app/animations/egg_timer.dart';
import '../../app/animations/empty_fridge.dart';
import '../../app/animations/ingredient_check.dart';
import '../../app/animations/intro_motif.dart';
import '../../app/animations/motion.dart';
import '../../app/animations/photo_scan.dart';
import '../../app/animations/plate_drop.dart';
import '../../app/animations/shopping_bag.dart';
import '../../app/animations/simmering_pot.dart';
import '../../app/animations/spoon_refresh.dart';
import '../../app/theme/tavli_status_colors.dart';
import '../../data/database.dart';
import '../../data/shopping_repository.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_format.dart';
import '../../domain/theme_choice.dart';
import '../../sync/synced_writer.dart';

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
            LayoutBuilder(
              builder: (context, constraints) {
                final title = Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
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

/// Štikliraju se sastojci koje imamo. "Dodaj u kupovinu" šalje samo
/// razliku (neštiklirane kojih još nema u kupovini), a "imam" za stavku koju
/// je recept već dodao je tiho skida. Demo radi nad bazom u memoriji, da ne
/// dira pravu listu.
class _CheckDemo extends StatefulWidget {
  const _CheckDemo();

  @override
  State<_CheckDemo> createState() => _CheckDemoState();
}

class _CheckDemoState extends State<_CheckDemo> {
  static const _recipeId = 'demo-musaka';
  static const _items = [
    Ingredient(name: 'Krompir', quantity: 1, unit: 'kg'),
    Ingredient(name: 'Mleveno meso', quantity: 500, unit: 'g'),
    Ingredient(name: 'Crni luk', quantity: 2, unit: 'kom'),
  ];
  final _db = AppDatabase(NativeDatabase.memory());
  late final _repo = ShoppingRepository(
    _db,
    scope: const AccountScope(userId: 'demo', householdId: 'demo'),
    writer: SyncedWriter(_db, accountId: 'demo'),
  );
  final _have = <int>{1};
  int _inCart = 0;
  int _toAdd = 2;
  bool _saving = false;
  String? _feedback;
  bool _failed = false;

  List<Ingredient> get _missing => [
    for (final (i, item) in _items.indexed)
      if (!_have.contains(i)) item,
  ];
  List<Ingredient> get _haveItems => [
    for (final (i, item) in _items.indexed)
      if (_have.contains(i)) item,
  ];

  @override
  void dispose() {
    unawaited(_db.close());
    super.dispose();
  }

  Future<void> _refresh() async {
    final plan = await _repo.plan(
      _recipeId,
      missing: _missing,
      have: _haveItems,
    );
    if (!mounted) return;
    final count = await _repo.openCount();
    if (!mounted) return;
    setState(() {
      _toAdd = plan.toAdd.length;
      _inCart = count;
    });
  }

  Future<void> _toggle(int i) async {
    if (_saving) return;
    final nowHave = !_have.contains(i);
    setState(() {
      _saving = true;
      _feedback = null;
      _failed = false;
      if (nowHave) {
        _have.add(i);
      } else {
        _have.remove(i);
      }
    });
    try {
      if (nowHave) await _repo.markHave(_recipeId, _items[i]);
      if (!mounted) return;
      await _refresh();
    } on Exception {
      if (!mounted) return;
      setState(() {
        if (nowHave) {
          _have.remove(i);
        } else {
          _have.add(i);
        }
        _failed = true;
        _feedback = 'Izmena nije uspela. Pokušaj ponovo.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _send() async {
    if (_saving || _toAdd == 0) return;
    setState(() {
      _saving = true;
      _feedback = null;
      _failed = false;
    });
    try {
      final plan = await _repo.plan(
        _recipeId,
        missing: _missing,
        have: _haveItems,
      );
      if (!mounted) return;
      await _repo.addMissing(_recipeId, missing: _missing, have: _haveItems);
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      setState(() => _feedback = 'Dodato u nabavku: ${plan.toAdd.length}');
    } on Exception {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _feedback = 'Dodavanje nije uspelo. Pokušaj ponovo.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = _missing.isEmpty
        ? 'Imaš sve sastojke'
        : _toAdd == 0
        ? 'Sve je u kupovini'
        : 'Dodaj u kupovinu ($_toAdd)';
    return Column(
      children: [
        Text(
          'Označi sastojke koje već imaš',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        for (final (i, item) in _items.indexed)
          Semantics(
            checked: _have.contains(i),
            child: ListTile(
              enabled: !_saving,
              onTap: _saving ? null : () => _toggle(i),
              leading: AnimatedCheckmark(checked: _have.contains(i)),
              // Ono što imamo je utišano i ne ide u kupovinu.
              title: AnimatedDefaultTextStyle(
                key: ValueKey(reduceMotion(context)),
                duration: TavliMotion.duration(context, TavliMotion.feedback),
                style: DefaultTextStyle.of(context).style.copyWith(
                  color: _have.contains(i)
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                ),
                child: Text(item.name),
              ),
              subtitle: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_have.contains(i)) const _HaveTag(),
                  Text(
                    [
                      if (item.quantity case final q?) formatQuantity(q),
                      ?item.unit,
                    ].join(' '),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving || _toAdd == 0 || _missing.isEmpty ? null : _send,
          icon: const Icon(Icons.shopping_basket_outlined),
          label: Text(_saving ? 'Čuvanje…' : label),
        ),
        if (_feedback case final feedback?) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _failed ? Icons.error_outline : Icons.check_circle_outline,
                  color: _failed
                      ? colors.error
                      : TavliStatusColors.of(context).success.foreground,
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(feedback)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Column(
          children: [
            BumpBadge(
              count: _inCart,
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
    final success = TavliStatusColors.of(context).success;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: success.background,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          'imam',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: success.foreground),
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
