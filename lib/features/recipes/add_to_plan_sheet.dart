import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/home_shell.dart' show wideLayoutWidth;
import '../../data/meal_plan_repository.dart';
import '../../domain/meal_plan.dart';
import '../../domain/plan_calendar.dart';
import '../../domain/recipe.dart';
import '../../domain/shopping_demand.dart' show maxServings, minServings;
import '../planning/plan_format.dart';
import '../planning/planning_providers.dart';
import 'recipe_providers.dart' show clockProvider;

/// Izbor u listu „Dodaj u plan“: mesto, porcije i da li je zamena potvrđena.
typedef AddToPlanChoice = ({MealSlot slot, int servings, bool replace});

/// Redosled kojim se predlaže prvo slobodno mesto u danu: glavni obroci
/// pre užina.
const _preferred = [
  MealType.lunch,
  MealType.dinner,
  MealType.breakfast,
  MealType.afternoonSnack,
  MealType.morningSnack,
];

/// Prvo slobodno mesto dana ([_preferred]); null kad su sva zauzeta.
MealType? firstFreeMeal(CivilDate day, Map<MealSlot, PlannedMeal> taken) {
  for (final t in _preferred) {
    if (!taken.containsKey(MealSlot(day, t))) return t;
  }
  return null;
}

/// „Dodaj u plan“ sa ekrana recepta: izbor dana i obroka, potvrda zamene,
/// upis i poruka sa „Prikaži“. Na telefonu donji list, na širokom ekranu
/// dijalog.
Future<void> addRecipeToPlan(
  BuildContext context,
  WidgetRef ref,
  Recipe recipe,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
  // List već ima ručicu i bočni razmak; dijalog dobija svoj razmak.
  final panel = _AddToPlanPanel(recipe: recipe, inset: wide);
  final AddToPlanChoice? choice;
  if (wide) {
    choice = await showDialog<AddToPlanChoice>(
      context: context,
      builder: (_) => Dialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(TavliRadius.sheet)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: TavliWidth.dialog * 1.3),
          child: panel,
        ),
      ),
    );
  } else {
    choice = await showTavliSheet<AddToPlanChoice>(
      context,
      builder: (_) => panel,
    );
  }
  if (choice == null || !context.mounted) return;

  final repo = ref.read(mealPlanRepositoryProvider);
  Future<String> add({required bool replace}) => repo.addRecipe(
    recipe: recipe,
    slot: choice!.slot,
    servings: choice.servings,
    replace: replace,
  );
  String planId;
  try {
    try {
      planId = await add(replace: choice.replace);
    } on SlotTakenException {
      // Mesto je zauzeto u međuvremenu (npr. sa drugog uređaja).
      if (!context.mounted) return;
      if (!await _confirmReplace(context, choice.slot, null, recipe)) return;
      planId = await add(replace: true);
    }
  } on ProtectedMealException {
    showTavliMessageOn(messenger, 'Taj obrok se više ne može menjati.');
    return;
  } on Object {
    showTavliMessageOn(messenger, 'Recept nije dodat u plan. Pokušaj ponovo.');
    return;
  }
  final slot = choice.slot;
  showTavliMessageOn(
    messenger,
    'Dodato u plan: ${_dayName(slot.date)}, ${slot.type.label.toLowerCase()}. '
    'Nabavka je osvežena.',
    actionLabel: 'Prikaži',
    onAction: () {
      ref.read(planViewProvider.notifier)
        ..selectPlan(planId)
        ..selectDate(slot.date);
      router.go('/plan');
    },
  );
}

/// „petak“
String _dayName(CivilDate d) => dayLabel(d).split(',').first.toLowerCase();

/// Pitanje pre zamene zauzetog mesta: „Zadrži“ ili „Zameni“. [currentTitle]
/// je jelo koje je sada na tom mestu (null kad ga ne znamo).
Future<bool> _confirmReplace(
  BuildContext context,
  MealSlot slot,
  String? currentTitle,
  Recipe recipe,
) async {
  final meal = slot.type.label.toLowerCase();
  final what = currentTitle == null ? 'već ima jelo' : 'je „$currentTitle“';
  final result = await showTavliDialog<bool>(
    context,
    title: '${slot.type.label} je već u planu',
    message:
        '${dayLabel(slot.date)}, za $meal $what. '
        'Da ga zamenim receptom „${recipe.title}“?',
    actions: const [
      TavliDialogAction('Zadrži', false),
      TavliDialogAction('Zameni', true, isDefault: true),
    ],
  );
  return result ?? false;
}

class _AddToPlanPanel extends ConsumerStatefulWidget {
  const _AddToPlanPanel({required this.recipe, required this.inset});

  final Recipe recipe;

  /// Sopstveni bočni razmak (dijalog); u donjem listu ga daje list.
  final bool inset;

  @override
  ConsumerState<_AddToPlanPanel> createState() => _AddToPlanPanelState();
}

class _AddToPlanPanelState extends ConsumerState<_AddToPlanPanel> {
  late final CivilDate _today = CivilDate.today(ref.read(clockProvider));
  late DateRange _week = weekOf(_today);
  late CivilDate _day = _today;
  MealType? _type;
  late int _servings = widget.recipe.servings.clamp(minServings, maxServings);
  late Future<Map<MealSlot, PlannedMeal>> _taken = _load(pickFree: true);

  Future<Map<MealSlot, PlannedMeal>> _load({required bool pickFree}) async {
    final taken = await ref.read(mealPlanRepositoryProvider).mealsIn(_week);
    if (pickFree && mounted) {
      setState(() => _type = firstFreeMeal(_day, taken));
    }
    return taken;
  }

  void _showWeek(int offset) {
    setState(() {
      _week = DateRange(
        _week.start.addDays(7 * offset),
        _week.end.addDays(7 * offset),
      );
      _day = _week.contains(_today) ? _today : _week.start;
      _type = null;
      _taken = _load(pickFree: true);
    });
  }

  void _selectDay(CivilDate day, Map<MealSlot, PlannedMeal> taken) =>
      setState(() {
        _day = day;
        _type = firstFreeMeal(day, taken);
      });

  Future<void> _submit(Map<MealSlot, PlannedMeal> taken) async {
    final type = _type;
    if (type == null) return;
    final slot = MealSlot(_day, type);
    var replace = false;
    final current = taken[slot];
    if (current != null) {
      replace = await _confirmReplace(
        context,
        slot,
        current.snapshot?.title,
        widget.recipe,
      );
      if (!replace) return;
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop<AddToPlanChoice>((slot: slot, servings: _servings, replace: replace));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return FutureBuilder<Map<MealSlot, PlannedMeal>>(
      future: _taken,
      builder: (context, snap) {
        final taken = snap.data ?? const <MealSlot, PlannedMeal>{};
        final loading = snap.connectionState != ConnectionState.done;
        final days = _week.days.toList();
        final side = widget.inset ? TavliSpacing.large : 0.0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                side,
                widget.inset ? TavliSpacing.medium : 0,
                widget.inset ? TavliSpacing.small : 0,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Dodaj u plan',
                            style: t.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          widget.recipe.title,
                          style: t.bodyMedium?.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TavliIconButton(
                    glyph: TavliIcons.close,
                    semanticLabel: 'Zatvori',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: side,
                  vertical: TavliSpacing.small,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: TavliSpacing.medium,
                  children: [
                    TavliPeriodSwitcher(
                      label: weekLabel(_week),
                      previousLabel: 'Prethodna nedelja',
                      nextLabel: 'Sledeća nedelja',
                      onPrevious: _week.contains(_today)
                          ? null
                          : () => _showWeek(-1),
                      onNext: () => _showWeek(1),
                    ),
                    TavliWeekStrip(
                      selectedIndex: days.indexOf(_day),
                      onSelected: (i) => _selectDay(days[i], taken),
                      days: [
                        for (final d in days)
                          TavliStripDay(
                            weekday: weekdayShort(d),
                            day: '${d.day}',
                            enabled: !d.isBefore(_today),
                            semanticLabel: d == _today
                                ? '${dayLabel(d)}, danas'
                                : dayLabel(d),
                          ),
                      ],
                    ),
                    Text(
                      dayLabel(_day),
                      style: t.titleSmall?.copyWith(
                        color: c.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (loading)
                      const TavliLoading()
                    else if (snap.hasError)
                      const TavliEmptyState(
                        icon: Icons.error_outline,
                        title: 'Plan nije učitan.',
                      )
                    else
                      _MealChoices(
                        day: _day,
                        taken: taken,
                        selected: _type,
                        onSelect: (type) => setState(() => _type = type),
                      ),
                    TavliListGroup(
                      children: [
                        TavliListRow(
                          title: 'Porcije',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TavliIconButton(
                                icon: Icons.remove,
                                semanticLabel: 'Manje porcija',
                                onPressed: _servings <= minServings
                                    ? null
                                    : () => setState(() => _servings--),
                              ),
                              Text('$_servings', style: t.titleMedium),
                              TavliIconButton(
                                glyph: TavliIcons.add,
                                semanticLabel: 'Više porcija',
                                onPressed: _servings >= maxServings
                                    ? null
                                    : () => setState(() => _servings++),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                side,
                TavliSpacing.small,
                side,
                widget.inset ? TavliSpacing.large : 0,
              ),
              child: _Actions(
                onCancel: () => Navigator.of(context).pop(),
                onAdd: loading || snap.hasError || _type == null
                    ? null
                    : () => _submit(taken),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// „Odustani“ i „Dodaj u plan“, iste visine: u jednom redu, a sa velikim
/// tekstom jedno ispod drugog, da tekst ne prelazi u drugi red.
class _Actions extends StatelessWidget {
  const _Actions({required this.onCancel, required this.onAdd});

  final VoidCallback onCancel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final cancel = TavliButton.secondary(
      label: 'Odustani',
      onPressed: onCancel,
    );
    final add = TavliButton.primary(label: 'Dodaj u plan', onPressed: onAdd);
    if (!isLargeText(context)) {
      return TavliButtonRow(expand: true, children: [cancel, add]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TavliSpacing.small,
      children: [
        TavliButtonRow(expand: true, children: [add]),
        TavliButtonRow(expand: true, children: [cancel]),
      ],
    );
  }
}

/// Pet obroka izabranog dana, kao izbor jednog: šta je već upisano, a
/// skuvan ili zaključan obrok se ne bira.
class _MealChoices extends StatelessWidget {
  const _MealChoices({
    required this.day,
    required this.taken,
    required this.selected,
    required this.onSelect,
  });

  final CivilDate day;
  final Map<MealSlot, PlannedMeal> taken;
  final MealType? selected;
  final ValueChanged<MealType> onSelect;

  @override
  Widget build(BuildContext context) {
    return TavliListGroup(
      children: [
        for (final type in MealType.values)
          Builder(
            builder: (context) {
              final meal = taken[MealSlot(day, type)];
              final protected =
                  meal != null && (meal.isCooked || meal.isLocked);
              final isSelected = selected == type;
              final title = meal?.snapshot?.title ?? 'Jelo bez naziva';
              final subtitle = meal == null
                  ? 'Slobodno'
                  : meal.isCooked
                  ? '$title · skuvano'
                  : meal.isLocked
                  ? '$title · zaključano'
                  : isSelected
                  ? 'Zameniće: $title'
                  : title;
              return Semantics(
                inMutuallyExclusiveGroup: true,
                checked: isSelected,
                child: TavliListRow(
                  title: type.label,
                  subtitle: subtitle,
                  leading: _RadioMark(
                    selected: isSelected,
                    enabled: !protected,
                  ),
                  trailing: meal != null && meal.isCooked
                      ? const TavliTag.cooked()
                      : null,
                  onTap: protected ? null : () => onSelect(type),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Kružić izbora (samo crtež; dodir i opis daje red).
class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final x = TavliColors.of(context);
    final color = !enabled
        ? c.onSurface.withValues(alpha: 0.38)
        : selected
        ? c.primary
        : x.boxLine;
    // Veličina prati tekst, kao polje za štikliranje u redovima biblioteke.
    final size = MediaQuery.textScalerOf(context).scale(22);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: selected
            ? Container(
                width: size / 2,
                height: size / 2,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              )
            : null,
      ),
    );
  }
}
