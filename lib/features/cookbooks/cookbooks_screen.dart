import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/cookbook.dart';
import '../recipes/ai_preview.dart';
import '../recipes/recipe_view.dart';
import 'cookbook_errors.dart';
import 'cookbook_providers.dart';

/// Kuvarske knjige domaćinstva: dodavanje (PDF ili EPUB sa tekstom), stanje
/// obrade, brisanje i ulaz u pitanja nad knjigama.
class CookbooksScreen extends ConsumerStatefulWidget {
  const CookbooksScreen({super.key});

  @override
  ConsumerState<CookbooksScreen> createState() => _CookbooksScreenState();
}

class _CookbooksScreenState extends ConsumerState<CookbooksScreen> {
  bool _busy = false;
  String? _progress;
  String? _error;

  Future<void> _add() async {
    final repo = ref.read(cookbookRepositoryProvider);
    if (repo == null || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ref.read(bookPickerProvider).pick();
      if (picked.isEmpty || !mounted) return;
      var ready = 0;
      final failures = <String>[];
      for (final (index, file) in picked.indexed) {
        if (!mounted || ref.read(cookbookRepositoryProvider) != repo) return;
        final position = picked.length == 1
            ? ''
            : '${index + 1}/${picked.length} · ';
        setState(() => _progress = '${position}Otpremam knjigu…');
        try {
          await repo.upload(
            filename: file.name,
            bytes: file.bytes,
            onProgress: (book) {
              if (mounted) {
                setState(
                  () => _progress = '$position${cookbookStatusText(book)}',
                );
              }
            },
          );
          ready++;
        } on Exception catch (error) {
          failures.add(
            picked.length == 1
                ? cookbookFailureText(error)
                : '${file.name}: ${cookbookFailureText(error)}',
          );
        }
      }
      if (!mounted) return;
      ref.invalidate(cookbooksProvider);
      if (failures.isNotEmpty) setState(() => _error = failures.join('\n'));
      if (ready > 0) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                picked.length == 1
                    ? 'Knjiga je spremna.'
                    : 'Spremno: $ready od ${picked.length} knjiga.',
              ),
            ),
          );
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _error = cookbookFailureText(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _resume(Cookbook book) async {
    final repo = ref.read(cookbookRepositoryProvider);
    if (repo == null || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _progress = cookbookStatusText(book);
    });
    try {
      await repo.resume(
        book,
        onProgress: (b) {
          if (mounted) setState(() => _progress = cookbookStatusText(b));
        },
      );
      ref.invalidate(cookbooksProvider);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Knjiga je spremna.')));
    } on Exception catch (e) {
      ref.invalidate(cookbooksProvider);
      if (mounted) setState(() => _error = cookbookFailureText(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _delete(Cookbook book) async {
    final repo = ref.read(cookbookRepositoryProvider);
    if (repo == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Obrisati knjigu?'),
        content: Text(
          '„${book.title}“ i njeni delovi se brišu, a odgovori je više ne koriste.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await repo.delete(book.id);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = cookbookFailureText(e));
    }
    ref.invalidate(cookbooksProvider);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(cookbookRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kuvarske knjige')),
      body: repo == null
          ? const ReadableScroll(
              children: [
                Text('Kuvarske knjige traže prijavu i vezu sa internetom.'),
              ],
            )
          : _body(),
    );
  }

  Widget _body() {
    final books = ref.watch(cookbooksProvider);
    final list = books.value ?? const <Cookbook>[];
    final hasReady = list.any((b) => b.status == CookbookStatus.ready);
    return ReadableScroll(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.upload_file),
              label: const Text('Dodaj knjigu'),
            ),
            OutlinedButton.icon(
              onPressed: hasReady && !_busy
                  ? () => context.go('/recipes/cookbooks/ask')
                  : null,
              icon: const Icon(Icons.question_answer_outlined),
              label: const Text('Postavi pitanje'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_progress case final text?) AiBusy(text, pot: false),
        if (_error case final error?)
          AiErrorBox(
            error,
            actions: [
              TextButton(
                onPressed: () => setState(() => _error = null),
                child: const Text('U redu'),
              ),
            ],
          ),
        if (books.isLoading && list.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (books.hasError && list.isEmpty)
          Text(cookbookFailureText(books.error!))
        else if (list.isEmpty && !_busy)
          const TavliEmptyState(
            icon: Icons.menu_book_outlined,
            title: 'Još nema kuvarskih knjiga',
            message:
                'Dodaj PDF ili EPUB sa tekstom pa pitaj šta piše u njemu. '
                'Knjige vidi samo tvoje domaćinstvo.',
          )
        else
          for (final book in list)
            _BookTile(
              book: book,
              busy: _busy,
              onDelete: _delete,
              onResume: _resume,
            ),
      ],
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.busy,
    required this.onDelete,
    required this.onResume,
  });

  final Cookbook book;
  final bool busy;
  final Future<void> Function(Cookbook) onDelete;
  final Future<void> Function(Cookbook) onResume;

  @override
  Widget build(BuildContext context) {
    final progress = book.status == CookbookStatus.processing
        ? book.progress
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(cookbookStatusText(book)),
                  if (progress != null) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress),
                  ],
                  if (book.status == CookbookStatus.uploaded ||
                      book.status == CookbookStatus.processing)
                    TextButton(
                      onPressed: busy ? null : () => onResume(book),
                      child: const Text('Nastavi obradu'),
                    ),
                ],
              ),
            ),
            TavliIconButton(
              icon: Icons.delete_outline,
              semanticLabel: 'Obriši knjigu ${book.title}',
              onPressed: () => onDelete(book),
            ),
          ],
        ),
      ),
    );
  }
}
