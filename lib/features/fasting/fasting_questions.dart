import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/home_shell.dart' show wideLayoutWidth;
import '../../domain/church_calendar.dart';
import '../../domain/cookbook.dart';
import '../cookbooks/cookbook_errors.dart';
import '../cookbooks/cookbook_providers.dart';
import '../planning/plan_generation.dart';
import '../recipes/recipe_providers.dart';

class FastingStatusCard extends StatelessWidget {
  const FastingStatusCard({required this.calendar, super.key});

  final ChurchCalendar calendar;

  @override
  Widget build(BuildContext context) => TavliListGroup(
    children: [
      TavliListRow(
        title: 'Post i praznici',
        subtitle: calendar.status,
        leading: const Icon(Icons.calendar_month_outlined),
        showChevron: true,
        onTap: () {
          if (MediaQuery.sizeOf(context).width < wideLayoutWidth) {
            unawaited(context.push('/home/fasting'));
            return;
          }
          unawaited(
            showGeneralDialog<void>(
              context: context,
              barrierDismissible: true,
              barrierColor: Colors.transparent,
              barrierLabel: 'Zatvori',
              pageBuilder: (context, _, _) => Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: TavliWidth.sidePanel,
                  ),
                  child: const _PanelEdge(child: FastingQuestions(panel: true)),
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}

/// Leva ivica i senka bočnog panela, kao na dizajnu (MacPostPanel):
/// `border-left: 1px line`, `box-shadow: -8px 0 24px text/10 %`.
class _PanelEdge extends StatelessWidget {
  const _PanelEdge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = TavliColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.line)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.10),
            offset: const Offset(-8, 0),
            blurRadius: 24,
          ),
        ],
      ),
      child: child,
    );
  }
}

class FastingQuestions extends ConsumerStatefulWidget {
  const FastingQuestions({this.panel = false, super.key});

  final bool panel;

  @override
  ConsumerState<FastingQuestions> createState() => _FastingQuestionsState();
}

class _FastingQuestionsState extends ConsumerState<FastingQuestions> {
  final _question = TextEditingController();
  String? _answer;
  String? _calendarSource;
  String? _error;
  List<CookbookSource> _sources = const [];
  bool _busy = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask([String? suggestion]) async {
    if (_busy) return;
    if (suggestion != null) _question.text = suggestion;
    final question = _question.text.trim();
    if (question.isEmpty) return;
    final calendar = ChurchCalendar(ref.read(clockProvider)());
    final fact = calendar.answer(question);
    FocusScope.of(context).unfocus();
    setState(() {
      _answer = fact?.text;
      _calendarSource = fact?.source;
      _error = null;
      _sources = const [];
    });
    if (fact != null) return;

    if (ChurchCalendar.isCalendarQuestion(question)) {
      setState(
        () => _answer =
            'Ne znam. U crkvenom kalendaru nemam odgovor na to pitanje.',
      );
      return;
    }

    final repo = ref.read(cookbookRepositoryProvider);
    if (repo == null) {
      setState(
        () => _error =
            'Za pretragu recepata i kuvara potrebna je veza sa internetom.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final answer = await repo.ask(question, includeRecipes: true);
      if (!mounted || ref.read(cookbookRepositoryProvider) != repo) return;
      setState(() {
        _answer = answer.known
            ? answer.content
            : 'Ne znam. U sačuvanim receptima i kuvarima nema odgovora.';
        _sources = answer.sources;
      });
    } on Exception catch (error) {
      if (mounted && ref.read(cookbookRepositoryProvider) == repo) {
        setState(() => _error = cookbookFailureText(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(String location) {
    final router = GoRouter.of(context);
    if (widget.panel) Navigator.of(context).pop();
    router.go(location);
  }

  void _openPlan() {
    final state = ref.read(planGenerationProvider);
    if (state.busy || state.draft != null) {
      showTavliMessageOn(
        ScaffoldMessenger.of(context),
        'Završi postojeći nacrt plana pa napravi posni plan.',
      );
      return;
    }
    _open('/plan/new?posni=1');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final panel = widget.panel;
    final content = <Widget>[
      if (panel)
        Row(
          spacing: TavliSpacing.small,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Post i praznici',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
            TavliIconButton(
              glyph: TavliIcons.close,
              semanticLabel: 'Zatvori panel',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      Row(
        spacing: TavliSpacing.small,
        children: [
          Expanded(
            child: TavliTextField(
              controller: _question,
              hint: 'Pitanje o postu i praznicima',
              leading: const TavliIcon(TavliIcons.question),
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => unawaited(_ask()),
            ),
          ),
          IconButton.filled(
            tooltip: 'Pošalji pitanje',
            onPressed: _busy ? null : () => unawaited(_ask()),
            icon: const TavliIcon(TavliIcons.arrowForward, size: 20),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TavliRadius.button),
              ),
            ),
          ),
        ],
      ),
      if (_busy) const TavliLoading(),
      if (_error case final error?)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error),
            TextButton(onPressed: _ask, child: const Text('Pokušaj ponovo')),
          ],
        ),
      if (_answer case final answer?)
        TavliCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              _overline(theme, 'Odgovor'),
              Text(
                answer,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              if (_calendarSource case final source?)
                _source(theme, 'Izvor: $source'),
              for (final source in _sources)
                if (source.recipeId case final id?)
                  TextButton(
                    onPressed: () =>
                        _open('/recipes/${Uri.encodeComponent(id)}'),
                    child: Text(source.label),
                  )
                else
                  _source(theme, 'Izvor: ${source.label}'),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TavliButton.primary(
                      onPressed: _openPlan,
                      label: 'Napravi posni plan',
                      glyph: TavliIcons.plan,
                    ),
                    TavliButton.secondary(
                      onPressed: () => _open('/recipes?posni=1'),
                      label: 'Posni recepti',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TavliSpacing.small,
        children: [
          _overline(theme, 'Pitaj još'),
          // Vidljivi razmak 8; polje za dodir je 6 više gore i dole.
          Wrap(
            spacing: TavliSpacing.small,
            runSpacing: TavliSpacing.small - 2 * _QuestionChip.touchInset,
            children: [
              if (_answer == null) _chip('Kada počinje Božićni post?'),
              _chip('Da li je sutra posno?'),
              _chip('Šta se jede na ulju?'),
              _chip('Kada je Vaskrs ${ref.watch(clockProvider)().year + 1}?'),
            ],
          ),
        ],
      ),
      Text(
        'Opšta pravila posta po crkvenom kalendaru. Bolesni, trudnice i deca su obično izuzeti.',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          height: 1.4,
          color: muted,
        ),
      ),
    ];
    // Kanvas: panel 20/24 i razmak 16, telefon 8/20 i razmak 14.
    final body = SafeArea(
      child: SingleChildScrollView(
        padding: panel
            ? const EdgeInsets.symmetric(horizontal: 24, vertical: 20)
            : const EdgeInsets.fromLTRB(
                TavliSpacing.large,
                TavliSpacing.small,
                TavliSpacing.large,
                TavliSpacing.large,
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: panel ? 16 : TavliSpacing.medium,
          children: content,
        ),
      ),
    );
    return Scaffold(
      appBar: panel
          ? null
          : AppBar(
              title: const Text('Post i praznici'),
              leading: const BackButton(),
            ),
      body: body,
    );
  }

  Widget _overline(ThemeData theme, String text) => Text(
    text.toUpperCase(),
    semanticsLabel: text,
    style: theme.textTheme.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.72,
      height: 1.3,
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );

  Widget _source(ThemeData theme, String text) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      spacing: 6,
      children: [
        TavliIcon(TavliIcons.recipes, size: 16, color: muted),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              height: 1.4,
              color: muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String question) => _QuestionChip(
    label: question,
    onPressed: _busy ? null : () => unawaited(_ask(question)),
  );
}

/// Predloženo pitanje (kanvas „Pitaj još“): bela pločica, ivica 1, radijus 10,
/// vidljiva visina 36, a polje za dodir 48.
class _QuestionChip extends StatelessWidget {
  const _QuestionChip({required this.label, required this.onPressed});

  static const double touchInset = 6;

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TavliRadius.chip),
      side: BorderSide(color: TavliColors.of(context).line),
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        excludeFromSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: touchInset),
          child: Material(
            color: c.surface,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Center(
                  widthFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: onPressed == null
                            ? c.onSurfaceVariant
                            : c.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
