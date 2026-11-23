import 'dart:async';

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
                    maxWidth: TavliWidth.dialog,
                  ),
                  child: const FastingQuestions(panel: true),
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post i praznici'),
        leading: widget.panel
            ? CloseButton(onPressed: () => Navigator.of(context).pop())
            : const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(TavliSpacing.large),
          children: [
            TextField(
              controller: _question,
              maxLength: 500,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => unawaited(_ask()),
              decoration: InputDecoration(
                labelText: 'Pitanje o postu i praznicima',
                hintText: 'Kada počinje Božićni post?',
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: 'Pošalji pitanje',
                  onPressed: _busy ? null : () => unawaited(_ask()),
                  icon: const Icon(Icons.send_outlined),
                ),
              ),
            ),
            const SizedBox(height: TavliSpacing.medium),
            if (_busy) const TavliLoading(),
            if (_error case final error?) ...[
              Text(error),
              TextButton(onPressed: _ask, child: const Text('Pokušaj ponovo')),
            ],
            if (_answer case final answer?)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(TavliSpacing.large),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: TavliSpacing.small,
                    children: [
                      Text('Odgovor', style: theme.textTheme.labelLarge),
                      Text(answer),
                      if (_calendarSource case final source?)
                        Text(
                          'Izvor: $source',
                          style: theme.textTheme.bodyMedium,
                        ),
                      for (final source in _sources)
                        if (source.recipeId case final id?)
                          TextButton(
                            onPressed: () =>
                                _open('/recipes/${Uri.encodeComponent(id)}'),
                            child: Text(source.label),
                          )
                        else
                          Text(
                            'Izvor: ${source.label}',
                            style: theme.textTheme.bodyMedium,
                          ),
                      Wrap(
                        spacing: TavliSpacing.small,
                        runSpacing: TavliSpacing.small,
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
                    ],
                  ),
                ),
              ),
            const SizedBox(height: TavliSpacing.medium),
            Text('Pitaj još', style: theme.textTheme.labelLarge),
            Wrap(
              spacing: TavliSpacing.small,
              runSpacing: TavliSpacing.small,
              children: [
                if (_answer == null) _chip('Kada počinje Božićni post?'),
                _chip('Da li je sutra posno?'),
                _chip('Šta se jede na ulju?'),
                _chip('Kada je Vaskrs ${ref.watch(clockProvider)().year + 1}?'),
              ],
            ),
            const SizedBox(height: TavliSpacing.medium),
            Text(
              'Opšta pravila posta po crkvenom kalendaru. Bolesni, trudnice i deca su obično izuzeti.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String question) => ActionChip(
    label: Text(question),
    onPressed: _busy ? null : () => unawaited(_ask(question)),
  );
}
