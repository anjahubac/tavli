import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../data/cooking_repository.dart';
import '../../domain/cooking_steps.dart';
import '../../domain/meal_plan.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_format.dart';
import '../../domain/shopping_demand.dart' show scaleQuantity;
import '../planning/planning_providers.dart';
import 'keep_screen_on.dart';
import 'recipe_providers.dart';

/// Šta se kuva: recept iz biblioteke ili obrok iz plana (021 FR-010).
/// Porcije su fiksne dok traje kuvanje (Anja, 21.11.2026).
class CookingRecipe {
  const CookingRecipe({
    required this.title,
    required this.servings,
    required this.ingredients,
    required this.steps,
    this.recipeId,
    this.mealId,
  });

  final String title;
  final int servings;
  final List<Ingredient> ingredients;
  final List<String> steps;

  /// Recept iz biblioteke, za „Dodaj korake“.
  final String? recipeId;

  /// Obrok iz plana; samo tada kraj kuvanja je „Skuvano“.
  final String? mealId;
}

/// Režim kuvanja za recept iz biblioteke.
class RecipeCookingRoute extends ConsumerWidget {
  const RecipeCookingRoute({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeProvider(id));
    return switch (recipe) {
      AsyncData(value: final r?) => CookingModeScreen(
        recipe: CookingRecipe(
          title: r.title,
          servings: r.servings,
          ingredients: r.ingredients,
          steps: r.steps,
          recipeId: r.id,
        ),
      ),
      AsyncData() || AsyncError() => const _Missing('Recept više ne postoji.'),
      _ => const _Loading(),
    };
  }
}

/// Režim kuvanja za obrok iz plana: snimak recepta za porcije obroka.
class MealCookingRoute extends ConsumerWidget {
  const MealCookingRoute({
    super.key,
    required this.planId,
    required this.entryId,
  });

  final String planId;
  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(plannedMealsProvider(planId));
    PlannedMeal? meal;
    for (final m in meals.value ?? const <PlannedMeal>[]) {
      if (m.id == entryId) meal = m;
    }
    final snapshot = meal?.snapshot;
    if (meal == null || snapshot == null) {
      return meals.isLoading
          ? const _Loading()
          : const _Missing('Obrok nije pronađen.');
    }
    // Neskuvan obrok prati korake iz biblioteke; skuvan koristi snimak.
    final recipeId = meal.recipeId;
    final library = recipeId == null || meal.isCooked
        ? null
        : ref.watch(recipeProvider(recipeId)).value;
    return CookingModeScreen(
      recipe: CookingRecipe(
        title: snapshot.title,
        servings: meal.servings,
        ingredients: [
          for (final i in snapshot.ingredients)
            Ingredient(
              name: i.name,
              quantity: scaleQuantity(
                i.quantity,
                baseServings: snapshot.baseServings,
                servings: meal.servings,
              ),
              unit: i.unit,
              category: i.category,
              note: i.note,
            ),
        ],
        steps: library?.steps ?? snapshot.steps,
        recipeId: recipeId,
        mealId: meal.id,
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(), body: const TavliLoading());
}

class _Missing extends StatelessWidget {
  const _Missing(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: TavliEmptyState(icon: Icons.menu_book_outlined, title: title),
  );
}

/// Ekran kuvanja sa platna („Predlog: režim kuvanja“): jedan korak krupnim
/// slovima, „Prethodni“ i „Sledeći“ iste veličine, na kraju „Skuvano“.
/// Na telefonu su sastojci u listu odozdo („Sastojci“ gore desno), na
/// širokom ekranu stalno u panelu desno. Glavna navigacija se ne vidi, a
/// ekran ostaje upaljen dok je režim otvoren.
class CookingModeScreen extends ConsumerStatefulWidget {
  const CookingModeScreen({super.key, required this.recipe});

  final CookingRecipe recipe;

  /// Od ove širine sastojci stoje u panelu desno.
  static const panelBreakpoint = 900.0;

  /// Širina panela sa sastojcima na računaru.
  static const panelWidth = 360.0;

  /// Najveća širina koraka, da red ne bude predugačak za čitanje.
  static const stepMaxWidth = 720.0;

  @override
  ConsumerState<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends ConsumerState<CookingModeScreen> {
  late final ScreenWakeLock _lock = ref.read(screenWakeLockProvider);
  var _step = 0;
  final _done = <int>{};
  var _busy = false;

  CookingRecipe get _recipe => widget.recipe;

  @override
  void initState() {
    super.initState();
    unawaited(_wake(on: true));
  }

  @override
  void didUpdateWidget(CookingModeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stepCount = _recipe.steps.length;
    if (stepCount == 0) {
      _step = 0;
    } else if (_step >= stepCount) {
      _step = stepCount - 1;
    }
  }

  @override
  void dispose() {
    unawaited(_wake(on: false));
    super.dispose();
  }

  /// Ako platforma ne podrži zadržavanje ekrana, kuvanje radi dalje.
  Future<void> _wake({required bool on}) async {
    try {
      await (on ? _lock.enable() : _lock.disable());
    } on Exception {
      if (kDebugMode) debugPrint('Kuvanje: zahtev za ekran nije uspeo.');
    }
  }

  void _toggle(int index, bool checked) =>
      setState(() => checked ? _done.add(index) : _done.remove(index));

  void _close() =>
      context.canPop() ? context.pop() : context.go(_fallbackLocation);

  String get _fallbackLocation =>
      _recipe.recipeId == null ? '/plan' : '/recipes/${_recipe.recipeId}';

  Future<void> _finish() async {
    final mealId = _recipe.mealId;
    if (mealId == null) {
      _close();
      return;
    }
    setState(() => _busy = true);
    final cooking = ref.read(cookingRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await cooking.markCooked(mealId);
    } on Exception {
      if (!mounted) return;
      setState(() => _busy = false);
      showTavliMessageOn(
        messenger,
        'Obrok nije označen kao skuvan. Pokušaj ponovo.',
      );
      return;
    }
    if (!mounted) return;
    _close();
    showTavliMessageOn(
      messenger,
      'Obrok je skuvan.',
      actionLabel: 'Poništi',
      onAction: () => unawaited(_undo(cooking, mealId, messenger)),
    );
  }

  static Future<void> _undo(
    CookingRepository cooking,
    String mealId,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      await cooking.undoCooked(mealId);
    } on Exception {
      showTavliMessageOn(messenger, 'Poništavanje nije uspelo.');
    }
  }

  Future<void> _showIngredients() => showTavliSheet<void>(
    context,
    title: 'Sastojci',
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheet) => _IngredientsChecklist(
        recipe: _recipe,
        done: _done,
        onChanged: (i, v) {
          _toggle(i, v);
          setSheet(() {});
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >= CookingModeScreen.panelBreakpoint;
    final steps = _recipe.steps;
    final last = steps.isEmpty || _step == steps.length - 1;
    final finishLabel = _recipe.mealId == null ? 'Gotovo' : 'Skuvano';

    final actions = TavliActionBar(
      actions: [
        if (steps.isNotEmpty)
          TavliButton.secondary(
            label: 'Prethodni',
            glyph: TavliIcons.arrowBack,
            onPressed: _step == 0 ? null : () => setState(() => _step--),
          ),
        if (last)
          TavliButton.primary(
            label: finishLabel,
            glyph: TavliIcons.check,
            onPressed: _busy ? null : _finish,
          )
        else
          TavliButton.primary(
            label: 'Sledeći',
            glyph: TavliIcons.arrowForward,
            onPressed: () => setState(() => _step++),
          ),
      ],
    );

    final content = _CookingContent(
      recipe: _recipe,
      step: _step,
      showIngredients: steps.isEmpty && !wide,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kuvanje'),
        actions: [
          if (!wide)
            TavliButton.text(label: 'Sastojci', onPressed: _showIngredients),
        ],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: content),
                      actions,
                    ],
                  ),
                ),
                const TavliDivider(vertical: true),
                SizedBox(
                  width: CookingModeScreen.panelWidth,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(TavliSpacing.large),
                    child: _IngredientsChecklist(
                      recipe: _recipe,
                      done: _done,
                      onChanged: _toggle,
                      header: true,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(child: content),
                SafeArea(top: false, child: actions),
              ],
            ),
    );
  }
}

class _CookingContent extends StatelessWidget {
  const _CookingContent({
    required this.recipe,
    required this.step,
    required this.showIngredients,
  });

  final CookingRecipe recipe;
  final int step;

  /// Recept bez koraka na telefonu: sastojci su na samom ekranu.
  final bool showIngredients;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final steps = recipe.steps;
    final hasSteps = steps.isNotEmpty;
    final used = hasSteps
        ? ingredientsInStep(steps[step], recipe.ingredients)
        : const <Ingredient>[];
    final recipeId = recipe.recipeId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(TavliSpacing.large),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: CookingModeScreen.stepMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${recipe.title} · ${servingsLabel(recipe.servings)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  hasSteps
                      ? 'Korak ${step + 1} od ${steps.length}'.toUpperCase()
                      : 'Bez koraka'.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: c.primary,
                  ),
                ),
              ),
              const SizedBox(height: TavliSpacing.medium),
              if (hasSteps) ...[
                TavliCard(
                  child: Text(
                    steps[step],
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                if (used.isNotEmpty) ...[
                  const SizedBox(height: TavliSpacing.medium),
                  const TavliSectionHeader('U ovom koraku'),
                  const SizedBox(height: TavliSpacing.small),
                  TavliListGroup(
                    children: [
                      for (final i in used)
                        TavliListRow(title: i.name, quantity: _amount(i)),
                    ],
                  ),
                ],
                const SizedBox(height: TavliSpacing.medium),
                Row(
                  children: [
                    TavliIcon(
                      TavliIcons.lightMode,
                      size: 16,
                      color: c.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ekran ostaje upaljen dok kuvaš.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                TavliNotice(
                  message: 'Koraci pripreme nisu uneti.',
                  tone: TavliNoticeTone.warning,
                  linkLabel: recipeId == null ? null : 'Dodaj korake',
                  onLink: recipeId == null
                      ? null
                      : () => context.go('/recipes/$recipeId/edit'),
                ),
                if (showIngredients) ...[
                  const SizedBox(height: TavliSpacing.medium),
                  const TavliSectionHeader('Sastojci'),
                  const SizedBox(height: TavliSpacing.small),
                  TavliListGroup(
                    children: [
                      for (final i in recipe.ingredients)
                        TavliListRow(title: i.name, quantity: _amount(i)),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista sastojaka sa kvačicama: list odozdo na telefonu, panel desno na
/// računaru. Kvačice važe samo dok traje kuvanje.
class _IngredientsChecklist extends StatelessWidget {
  const _IngredientsChecklist({
    required this.recipe,
    required this.done,
    required this.onChanged,
    this.header = false,
  });

  final CookingRecipe recipe;
  final Set<int> done;
  final void Function(int index, bool checked) onChanged;

  /// Naslov „Sastojci“ i porcije (panel; list ima svoj naslov).
  final bool header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header) ...[
          Semantics(
            header: true,
            child: Text(
              'Sastojci',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            servingsLabel(recipe.servings),
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: TavliSpacing.medium),
        ] else ...[
          Text(
            '${recipe.title} · ${servingsLabel(recipe.servings)}',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: TavliSpacing.medium),
        ],
        TavliListGroup(
          children: [
            for (final (n, i) in recipe.ingredients.indexed)
              TavliCheckRow(
                title: i.name,
                detail: _amount(i),
                checked: done.contains(n),
                onChanged: (v) => onChanged(n, v),
              ),
          ],
        ),
        const SizedBox(height: TavliSpacing.medium),
        Text(
          'Štikliraj ono što je već spremno. Važi samo dok kuvaš.',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}

/// „1,5 kg“, „3 kom“, „po ukusu“ (napomena kad nema količine).
String? _amount(Ingredient i) {
  final q = i.quantity;
  if (q == null) return i.note;
  return [formatQuantity(q), ?i.unit].join(' ');
}
