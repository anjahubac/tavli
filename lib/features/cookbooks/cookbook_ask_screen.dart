import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/cookbook.dart';
import '../recipes/ai_preview.dart';
import '../recipes/recipe_form_screen.dart' show RecipeDraft;
import '../recipes/recipe_view.dart';
import 'cookbook_errors.dart';
import 'cookbook_providers.dart';

/// Pitanje nad knjigama domaćinstva: odgovor uvek nosi knjigu i stranicu, a
/// kad odgovora u knjigama nema, kaže to (bez izmišljenog izvora).
class CookbookAskScreen extends ConsumerStatefulWidget {
  const CookbookAskScreen({super.key});

  @override
  ConsumerState<CookbookAskScreen> createState() => _CookbookAskScreenState();
}

class _CookbookAskScreenState extends ConsumerState<CookbookAskScreen> {
  final _question = TextEditingController();
  String? _bookId;
  bool _busy = false;
  String? _error;
  CookbookAnswer? _answer;

  @override
  void initState() {
    super.initState();
    _question.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final repo = ref.read(cookbookRepositoryProvider);
    final question = _question.text.trim();
    if (repo == null || question.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _answer = null;
    });
    try {
      final answer = await repo.ask(question, bookId: _bookId);
      if (mounted) setState(() => _answer = answer);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = cookbookFailureText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _saveAsRecipe(CookbookAnswer answer) {
    context.go(
      '/recipes/new/manual',
      extra: RecipeDraft(
        steps: [answer.content, 'Izvor: ${sourceSummary(answer.sources)}'],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final books = [
      for (final b in ref.watch(cookbooksProvider).value ?? const <Cookbook>[])
        if (b.status == CookbookStatus.ready) b,
    ];
    final answer = _answer;
    return Scaffold(
      appBar: AppBar(title: const Text('Pitanje o knjigama')),
      body: ReadableScroll(
        children: [
          TavliTextField(
            label: 'Pitanje',
            hint: 'npr. Koliko dugo se kuva pasulj?',
            controller: _question,
            autofocus: true,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Knjiga'),
              const SizedBox(width: 12),
              Flexible(
                child: DropdownButton<String?>(
                  value: books.any((b) => b.id == _bookId) ? _bookId : null,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(child: Text('Sve knjige')),
                    for (final b in books)
                      DropdownMenuItem<String?>(
                        value: b.id,
                        child: Text(b.title, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) => setState(() => _bookId = id),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy || _question.text.trim().isEmpty ? null : _ask,
            icon: const Icon(Icons.search),
            label: const Text('Pitaj'),
          ),
          const SizedBox(height: 16),
          if (_busy) const AiBusy('Tražim u knjigama…'),
          if (_error case final error?)
            AiErrorBox(
              error,
              actions: [
                TextButton(
                  onPressed: _ask,
                  child: const Text('Pokušaj ponovo'),
                ),
              ],
            ),
          if (answer != null)
            _AnswerCard(answer: answer, onSave: _saveAsRecipe),
        ],
      ),
    );
  }
}

/// „Velika kuvarica, str. 10, str. 31": stranice iste knjige idu zajedno.
String sourceSummary(List<CookbookSource> sources) {
  final byBook = <String, List<CookbookSource>>{};
  for (final s in sources) {
    byBook.putIfAbsent(s.bookId, () => []).add(s);
  }
  return byBook.values
      .map(
        (list) =>
            '${list.first.title}, ${list.map((s) => 'str. ${s.page}').join(', ')}',
      )
      .join('; ');
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer, required this.onSave});

  final CookbookAnswer answer;
  final void Function(CookbookAnswer) onSave;

  @override
  Widget build(BuildContext context) {
    if (!answer.known) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nema odgovora u tvojim knjigama.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(answer.content),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in answer.sources)
                  Chip(label: Text('${s.title}, str. ${s.page}')),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => onSave(answer),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Sačuvaj kao recept'),
            ),
          ],
        ),
      ),
    );
  }
}
