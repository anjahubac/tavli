import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/meal_plan.dart';
import '../../domain/recipe_format.dart';
import 'meal_actions.dart';
import 'plan_format.dart';
import 'plan_generation.dart';
import 'plan_step_page.dart';
import 'planning_providers.dart';

/// Drugi i treći korak: napredak, predlog po danima i odobrenje. Ništa se
/// ne čuva dok osoba ne izabere "Sačuvaj plan" (ili izričito nepotpun plan).
class PlanPreviewScreen extends ConsumerWidget {
  const PlanPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(planGenerationProvider);
    final controller = ref.read(planGenerationProvider.notifier);
    final draft = state.draft;
    // Ponovni predlog postojećeg plana: nema podešavanja, prikazuju se
    // samo mesta koja se menjaju, uz jelo koje zamenjuju.
    final isChange = draft?.base != null;
    final current = isChange
        ? {
            for (final m
                in ref.watch(plannedMealsProvider(draft!.base!.planId)).value ??
                    const <PlannedMeal>[])
              m.slot: m,
          }
        : const <MealSlot, PlannedMeal>{};

    Future<void> discard() async {
      final router = GoRouter.of(context);
      if (await confirmDiscardPlan(context)) {
        controller.discard();
        router.go('/plan');
      }
    }

    void backToSetup() =>
        isChange ? unawaited(discard()) : context.go('/plan/new');

    if (draft == null) {
      return PlanStepPage(
        title: 'Predlog plana',
        onBack: backToSetup,
        children: [
          const Text('Nema otvorenog predloga.'),
          TavliButton.primary(
            label: 'Nazad na podešavanje',
            onPressed: backToSetup,
          ),
        ],
      );
    }

    Future<void> save({bool partial = false}) async {
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      final id = await controller.save(partial: partial);
      if (id == null) return;
      router.go('/plan');
      showTavliMessageOn(
        messenger,
        isChange
            ? 'Izmene su sačuvane.'
            : partial
            ? 'Nepotpun plan je sačuvan.'
            : 'Plan je sačuvan.',
      );
    }

    /// Zamena jednog jela pre čuvanja: AI predlog ili recept iz biblioteke.
    Future<void> replace(MealSlot slot) async {
      final choice = await pickReplacementSource(context);
      if (choice == null || !context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final replaced = switch (choice) {
        ReplacementSource.ai => await controller.replaceSlot(slot),
        ReplacementSource.library => await () async {
          final recipe = await pickLibraryRecipe(context, ref);
          if (recipe == null) return false;
          controller.useRecipe(slot, recipe);
          return true;
        }(),
      };
      if (!replaced) return;
      showTavliMessageOn(messenger, 'Jelo je zamenjeno.');
    }

    final request = draft.request;
    final total = request.slots.length;
    final ready = draft.readySlots.length;
    final empty = total - ready;
    final theme = Theme.of(context);
    final phase = state.phase;

    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final days = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TavliSpacing.medium,
      children: [
        for (final day in request.range.days)
          if (request.slots.any((s) => s.date == day))
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TavliSectionHeader(
                  dayLabel(day),
                  style: TavliSectionHeaderStyle.bold,
                ),
                TavliListGroup(
                  children: [
                    for (final slot in request.slots.where(
                      (s) => s.date == day,
                    ))
                      _SlotTile(
                        draft: draft,
                        slot: slot,
                        previous: current[slot]?.snapshot?.title,
                        replacing: state.replacing == slot,
                        onReplace: state.busy
                            ? null
                            : () => unawaited(replace(slot)),
                        onCancelReplace: controller.cancel,
                      ),
                  ],
                ),
              ],
            ),
      ],
    );
    Widget actions({required bool showSave}) => _Actions(
      phase: phase,
      complete: draft.isComplete,
      ready: ready,
      empty: empty,
      showSave: showSave,
      onSave: () => unawaited(save()),
      onSavePartial: () => unawaited(save(partial: true)),
      onContinue: () => unawaited(controller.generate()),
      onDiscard: () => unawaited(discard()),
      onBack: isChange ? null : backToSetup,
      saveLabel: isChange ? 'Prihvati' : 'Sačuvaj plan',
      replacing: state.replacing != null,
    );

    final summary = <Widget>[
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TavliSectionHeader(
            rangeLabel(request.range),
            style: TavliSectionHeaderStyle.title,
          ),
          Text(
            '${mealsCount(total)} · ${servingsLabel(request.servings)} '
            'po obroku · predlog još nije sačuvan',
            style: muted,
          ),
        ],
      ),
      if (phase == GenerationPhase.generating)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: TavliSpacing.small,
          children: [
            TavliProgressBar(
              value: total == 0 ? null : ready / total,
              message:
                  'Pripremam plan… Pripremljeno $ready od $total '
                  'obroka.',
              semanticLabel: 'Napredak predloga',
            ),
            TavliButton.text(label: 'Prekini', onPressed: controller.cancel),
          ],
        ),
      if (phase == GenerationPhase.failed)
        TavliNotice(
          tone: TavliNoticeTone.error,
          message:
              '${state.error ?? 'Predlog nije završen.'} '
              'Gotovo je $ready od $total; nastavak pravi samo ono što '
              'nedostaje.',
          linkLabel: 'Nastavi',
          onLink: () => unawaited(controller.generate()),
        ),
      if (draft.withoutTastes && phase != GenerationPhase.generating)
        const TavliNotice(
          message:
              'Ukusi članova trenutno nisu dostupni, pa ovaj predlog ne '
              'uzima u obzir šta ko voli.',
        ),
      if (phase == GenerationPhase.cancelled)
        TavliNotice(
          message:
              'Prekinuto. Gotovo je $ready od $total; '
              'možeš da nastaviš kad želiš.',
        ),
      if (state.error != null &&
          phase != GenerationPhase.failed &&
          phase != GenerationPhase.generating)
        Text(
          state.error!,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) backToSetup();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Širina prostora koji je ostao posle bočne navigacije.
          final wide = constraints.maxWidth >= TavliWidth.listDetail;
          final barSave =
              !wide && draft.isComplete && phase != GenerationPhase.generating;
          return PlanStepPage(
            title: isChange ? 'Pregled izmena' : 'Predlog plana',
            backLabel: isChange ? 'Plan' : 'Novi plan',
            onBack: backToSetup,
            maxWidth: TavliWidth.page,
            bottom: barSave
                ? TavliActionBar(
                    actions: [
                      TavliButton.primary(
                        label: isChange ? 'Prihvati' : 'Sačuvaj plan',
                        glyph: TavliIcons.check,
                        onPressed: state.busy || phase == GenerationPhase.saving
                            ? null
                            : () => unawaited(save()),
                      ),
                    ],
                  )
                : null,
            children: [
              ...summary,
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: TavliSpacing.large,
                  children: [
                    Expanded(child: days),
                    SizedBox(
                      width: TavliWidth.detail,
                      child: TavliCard(
                        padding: const EdgeInsets.all(TavliSpacing.large),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: TavliSpacing.medium,
                          children: [actions(showSave: true)],
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                days,
                actions(showSave: !barSave),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Dugmad ispod predloga: čuvanje (ili nastavak), pa izmena izbora i
/// odbacivanje.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.phase,
    required this.complete,
    required this.ready,
    required this.empty,
    required this.showSave,
    required this.onSave,
    required this.onSavePartial,
    required this.onContinue,
    required this.onDiscard,
    required this.onBack,
    required this.saveLabel,
    required this.replacing,
  });

  final GenerationPhase phase;
  final bool complete;
  final int ready;
  final int empty;

  /// Glavno dugme „Sačuvaj plan“ u ovom redu; na telefonu je zakucano dole.
  final bool showSave;
  final VoidCallback onSave;
  final VoidCallback onSavePartial;
  final VoidCallback onContinue;
  final VoidCallback onDiscard;
  final VoidCallback? onBack;
  final String saveLabel;
  final bool replacing;

  @override
  Widget build(BuildContext context) {
    if (phase == GenerationPhase.generating) return const SizedBox.shrink();
    final saving = phase == GenerationPhase.saving || replacing;
    final onBack = this.onBack;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TavliSpacing.small,
      children: [
        if (complete) ...[
          if (showSave)
            TavliButton.primary(
              label: saveLabel,
              glyph: TavliIcons.check,
              onPressed: saving ? null : onSave,
            ),
        ] else ...[
          TavliButton.primary(
            label: 'Nastavi generisanje',
            glyph: TavliIcons.sparkle,
            onPressed: saving ? null : onContinue,
          ),
          if (ready > 0) ...[
            TavliButton.secondary(
              label: 'Sačuvaj nepotpun plan',
              onPressed: saving ? null : onSavePartial,
            ),
            Text(
              '${mealsCount(empty)} ostaje prazno.',
              textAlign: TextAlign.center,
            ),
          ],
        ],
        Wrap(
          alignment: WrapAlignment.center,
          spacing: TavliSpacing.small,
          children: [
            if (onBack != null)
              TavliButton.text(
                label: 'Promeni izbore',
                onPressed: saving ? null : onBack,
              ),
            TavliButton.text(
              label: 'Odbaci',
              onPressed: saving ? null : onDiscard,
            ),
          ],
        ),
      ],
    );
  }
}

/// Pita pre odbacivanja nesačuvanog predloga.
Future<bool> confirmDiscardPlan(BuildContext context) => showTavliConfirm(
  context,
  title: 'Odbaciti predlog?',
  message:
      'Predlog nije sačuvan. Sačuvani planovi, recepti i nabavka '
      'ostaju kakvi su bili.',
  cancelLabel: 'Nazad',
  confirmLabel: 'Odbaci',
);

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.draft,
    required this.slot,
    this.previous,
    this.replacing = false,
    this.onReplace,
    this.onCancelReplace,
  });

  final PlanDraft draft;
  final MealSlot slot;

  /// AI upravo traži drugo jelo za ovo mesto.
  final bool replacing;

  /// "Zameni jelo"; null dok traje generisanje, čuvanje ili druga zamena.
  final VoidCallback? onReplace;
  final VoidCallback? onCancelReplace;

  /// Jelo koje predlog zamenjuje (pregled izmena).
  final String? previous;

  @override
  Widget build(BuildContext context) {
    final proposal = draft.proposals[slot];
    final snapshot = draft.snapshotFor(slot);
    final label = slot.type.label;
    if (proposal == null) {
      return TavliListRow(title: label, subtitle: 'Nije planirano');
    }
    if (replacing) {
      return TavliListRow(
        title: label,
        subtitle: '${proposal.title}\nTražim drugo jelo…',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: TavliSpacing.small,
          children: [
            const TavliLoading(),
            TavliButton.text(label: 'Prekini', onPressed: onCancelReplace),
          ],
        ),
      );
    }
    final replace = TavliIconButton(
      glyph: TavliIcons.swap,
      semanticLabel: 'Zameni jelo',
      onPressed: onReplace,
    );
    final origin = [
      proposal.isNew ? 'Nov recept' : 'Iz mojih recepata',
      if (previous case final p?) 'umesto: $p',
    ].join(' · ');
    if (snapshot == null) {
      return TavliListRow(
        title: label,
        subtitle: '${proposal.title}\n$origin · sastojci još nisu spremni',
        trailing: replace,
      );
    }
    final t = Theme.of(context).textTheme;
    return TavliExpandable(
      title: label,
      subtitle: '${proposal.title}\n$origin',
      trailing: replace,
      children: [
        Text(
          'Sastojci za ${servingsLabel(snapshot.baseServings)}'
          '${snapshot.prepMinutes == null ? '' : ' · ${snapshot.prepMinutes} min'}',
          style: t.labelLarge,
        ),
        for (final i in snapshot.ingredients) Text('• ${ingredientLine(i)}'),
      ],
    );
  }
}
