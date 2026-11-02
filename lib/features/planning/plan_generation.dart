import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/auth_controller.dart';
import '../../ai/meal_plan_ai.dart';
import '../../data/meal_plan_repository.dart';
import '../../domain/meal_plan.dart';
import '../../domain/plan_calendar.dart';
import '../../providers.dart';
import '../recipes/recipe_providers.dart';
import '../settings/ai_error_text.dart';
import 'planning_providers.dart';

enum PlanPeriod { week, month }

/// Izbori sa ekrana podešavanja. Ostaju i kad se osoba vrati sa pregleda.
class PlanSetup {
  const PlanSetup({
    required this.period,
    required this.anchor,
    this.mealTypes = const {MealType.lunch},
    this.servings = 2,
    this.usePantry = true,
    this.wishes = '',
  });

  final PlanPeriod period;

  /// Bilo koji dan izabrane nedelje ili meseca.
  final CivilDate anchor;
  final Set<MealType> mealTypes;
  final int servings;
  final bool usePantry;
  final String wishes;

  /// Izabrani period bez dana pre [today].
  DateRange? range(CivilDate today) {
    final full = period == PlanPeriod.week ? weekOf(anchor) : monthOf(anchor);
    if (full.end.isBefore(today)) return null;
    return DateRange(full.start.isBefore(today) ? today : full.start, full.end);
  }

  /// Susedna nedelja ili mesec.
  PlanSetup shifted(int by) => copyWith(
    anchor: period == PlanPeriod.week
        ? anchor.addDays(7 * by)
        : _addMonths(anchor, by),
  );

  static CivilDate _addMonths(CivilDate d, int by) {
    final m = d.month - 1 + by;
    return CivilDate(d.year + (m / 12).floor(), m % 12 + 1, 1);
  }

  PlanSetup copyWith({
    PlanPeriod? period,
    CivilDate? anchor,
    Set<MealType>? mealTypes,
    int? servings,
    bool? usePantry,
    String? wishes,
  }) => PlanSetup(
    period: period ?? this.period,
    anchor: anchor ?? this.anchor,
    mealTypes: mealTypes ?? this.mealTypes,
    servings: servings ?? this.servings,
    usePantry: usePantry ?? this.usePantry,
    wishes: wishes ?? this.wishes,
  );
}

enum GenerationPhase { idle, generating, failed, cancelled, ready, saving }

class PlanGenerationState {
  const PlanGenerationState({
    required this.setup,
    this.phase = GenerationPhase.idle,
    this.draft,
    this.error,
  });

  final PlanSetup setup;
  final GenerationPhase phase;
  final PlanDraft? draft;

  /// Poruka za osobu (srpski), bez tehničkih detalja.
  final String? error;

  bool get busy =>
      phase == GenerationPhase.generating || phase == GenerationPhase.saving;

  PlanGenerationState copyWith({
    PlanSetup? setup,
    GenerationPhase? phase,
    PlanDraft? draft,
    bool clearDraft = false,
    String? error,
    bool clearError = false,
  }) => PlanGenerationState(
    setup: setup ?? this.setup,
    phase: phase ?? this.phase,
    draft: clearDraft ? null : (draft ?? this.draft),
    error: clearError ? null : (error ?? this.error),
  );
}

/// Tok podešavanje → predlog → odobrenje. Nacrt je samo u memoriji; ništa
/// se ne upisuje pre [save].
class PlanGenerationController extends Notifier<PlanGenerationState> {
  PlanCancellation? _cancel;

  /// Raste kad se nacrt odbaci; zakasneli rezultat starog rada se ne prikazuje.
  int _run = 0;

  @override
  PlanGenerationState build() {
    // Drugi nalog počinje od početka.
    ref.watch(accountScopeProvider);
    _cancel?.cancel();
    _run++;
    final today = CivilDate.today(ref.read(clockProvider));
    return PlanGenerationState(
      setup: PlanSetup(period: PlanPeriod.week, anchor: today),
    );
  }

  CivilDate get _today => CivilDate.today(ref.read(clockProvider));

  /// Izmena izbora; postojeći nacrt pripada starim izborima i odbacuje se.
  void updateSetup(PlanSetup setup) {
    if (state.busy) return;
    _run++;
    state = PlanGenerationState(setup: setup);
  }

  /// Nov predlog za trenutne izbore, ili nastavak otvorenog nacrta.
  Future<void> generate() async {
    if (state.busy) return;
    final range = state.setup.range(_today);
    if (range == null || state.setup.mealTypes.isEmpty) return;
    final previous = state.draft;
    final resume = previous != null && !previous.isComplete ? previous : null;
    final request =
        resume?.request ??
        PlanRequest(
          range: range,
          mealTypes: state.setup.mealTypes,
          servings: state.setup.servings,
          usePantry: state.setup.usePantry,
          wishes: state.setup.wishes.trim().isEmpty
              ? null
              : state.setup.wishes.trim(),
          pantryNames: state.setup.usePantry
              ? await ref
                    .read(mealPlanRepositoryProvider)
                    .confirmedPantryNames()
              : const [],
        );
    final run = ++_run;
    final cancel = _cancel = PlanCancellation();
    state = state.copyWith(
      phase: GenerationPhase.generating,
      draft: resume ?? PlanDraft(request: request),
      clearError: true,
    );
    try {
      final library = await ref.read(recipeRepositoryProvider).getAll();
      final draft = await ref
          .read(mealPlanAIProvider)
          .propose(
            request,
            library: library,
            resume: resume,
            cancel: cancel,
            onProgress: (d) {
              if (run == _run && !cancel.isCancelled) {
                state = state.copyWith(draft: d);
              }
            },
          );
      if (run != _run) return;
      state = state.copyWith(
        phase: cancel.isCancelled && !draft.isComplete
            ? GenerationPhase.cancelled
            : GenerationPhase.ready,
        draft: draft,
      );
    } on PlanGenerationCancelled catch (e) {
      if (run != _run) return;
      state = state.copyWith(phase: GenerationPhase.cancelled, draft: e.draft);
    } on PlanGenerationFailed catch (e) {
      if (run != _run) return;
      if (cancel.isCancelled) {
        state = state.copyWith(
          phase: GenerationPhase.cancelled,
          draft: e.draft,
        );
        return;
      }
      state = state.copyWith(
        phase: GenerationPhase.failed,
        draft: e.draft,
        error: aiErrorText(e.error),
      );
    }
  }

  /// Prekida generisanje; gotov deo ostaje u pregledu.
  void cancel() {
    if (state.phase != GenerationPhase.generating) return;
    _cancel?.cancel();
    state = state.copyWith(phase: GenerationPhase.cancelled);
  }

  /// Odbacuje nacrt; izbori ostaju.
  void discard() {
    _cancel?.cancel();
    _run++;
    state = PlanGenerationState(setup: state.setup);
  }

  /// Čuva nacrt i vraća id plana, ili null kad čuvanje nije uspelo (tada
  /// nacrt i poruka ostaju u pregledu).
  Future<String?> save({bool partial = false}) async {
    final draft = state.draft;
    if (draft == null || state.busy) return null;
    final before = state.phase;
    state = state.copyWith(phase: GenerationPhase.saving, clearError: true);
    try {
      final id = await ref
          .read(mealPlanRepositoryProvider)
          .approve(draft, allowPartial: partial);
      state = PlanGenerationState(setup: state.setup);
      return id;
    } on StaleDraftException {
      state = state.copyWith(
        phase: before,
        error: 'Plan je u međuvremenu promenjen. Napravi novi predlog.',
      );
    } on IncompleteDraftException {
      state = state.copyWith(phase: before, error: 'Predlog još nije potpun.');
    } on Exception {
      state = state.copyWith(
        phase: before,
        error: 'Plan nije sačuvan. Pokušaj ponovo.',
      );
    }
    return null;
  }
}

final planGenerationProvider =
    NotifierProvider<PlanGenerationController, PlanGenerationState>(
      PlanGenerationController.new,
    );
