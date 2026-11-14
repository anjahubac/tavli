import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/recipe.dart';
import '../../domain/recipe_format.dart';
import '../../domain/recipe_version.dart';
import '../../providers.dart';
import '../settings/ai_error_text.dart';
import 'ai_preview.dart';
import 'recipe_providers.dart';
import 'recipe_view.dart';
import 'versions_sheet.dart';

/// Izmene recepta preko AI-ja. Predlog se čuva tek posle "Prihvati".
class RecipeChatScreen extends ConsumerStatefulWidget {
  const RecipeChatScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<RecipeChatScreen> createState() => _RecipeChatScreenState();
}

class _RecipeChatScreenState extends ConsumerState<RecipeChatScreen> {
  final _input = TextEditingController();
  bool _busy = false;
  bool _saving = false;
  String? _error;
  String? _pending;
  Recipe? _proposal;

  /// Raste sa svakim zahtevom; odgovor prekinutog zahteva se odbacuje.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(Recipe current) async {
    final instruction = _input.text.trim();
    if (instruction.isEmpty || _busy) return;
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
      _pending = instruction;
    });
    try {
      final r = await ref.read(recipeAIProvider).refine(current, instruction);
      if (!mounted || request != _request) return;
      _input.clear();
      setState(() => _proposal = r.value);
    } on Exception catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = aiErrorText(e);
        _pending = null;
      });
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  Future<void> _accept(Recipe proposal) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(recipeRepositoryProvider)
        .update(
          proposal,
          kind: ChangeKind.ai,
          instruction: _pending,
          changedBy: proposal.answeredBy,
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _proposal = null;
      _pending = null;
    });
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Izmena je sačuvana.')));
  }

  /// Tekst zahteva ostaje u polju.
  void _cancel() => setState(() {
    _request++;
    _busy = false;
    _pending = null;
  });

  void _discard() => setState(() {
    _input.text = _pending ?? '';
    _proposal = null;
    _pending = null;
  });

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(recipeProvider(widget.id))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Recept nije učitan.')),
          ),
          data: (recipe) => recipe == null
              ? Scaffold(
                  appBar: AppBar(),
                  body: const Center(child: Text('Recept više ne postoji.')),
                )
              : _buildChat(context, recipe),
        );
  }

  Widget _buildChat(BuildContext context, Recipe recipe) {
    final theme = Theme.of(context);
    final versions =
        ref.watch(recipeVersionsProvider(recipe.id)).value ?? const [];
    final history = versions.reversed
        .where((v) => v.kind == ChangeKind.ai && v.instruction != null)
        .toList();
    final proposal = _proposal;
    final pending = _pending;
    final canSend = !_busy && proposal == null && _input.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            tooltip: 'Poništi poslednju izmenu',
            icon: const Icon(Icons.undo),
            onPressed: versions.isEmpty
                ? null
                : () => undoLastChange(context, ref, recipe.id),
          ),
          IconButton(
            tooltip: 'Prethodne verzije',
            icon: const Icon(Icons.history),
            onPressed: () => showVersionsSheet(context, recipe.id),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ReadableScroll(
              children: [
                Text(
                  'Napiši šta da promenim, npr. „za 4 osobe“, „bez glutena“ '
                  'ili „dodaj pečurke“.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                for (final v in history)
                  _Bubble(
                    text: v.instruction!,
                    caption: [
                      ?v.changedBy,
                      formatDateTime(v.createdAt.toLocal()),
                    ].join(' · '),
                  ),
                if (pending != null) _Bubble(text: pending),
                if (_busy) AiBusy('AI menja recept…', onCancel: _cancel),
                if (_error case final error?)
                  AiErrorBox(error, actions: const []),
                if (proposal != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Predlog izmene',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          RecipeView(proposal, showTitle: true),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: _saving ? null : _discard,
                                child: const Text('Odbaci'),
                              ),
                              FilledButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => _accept(proposal),
                                icon: const Icon(Icons.check),
                                label: const Text('Prihvati'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!_busy && history.isEmpty && pending == null) ...[
                  Text('Trenutni recept', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  RecipeView(recipe),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: proposal == null,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(recipe),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Šta da promenim?',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Pošalji',
                    onPressed: canSend ? () => _send(recipe) : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zahtev korisnika, desno poravnat.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, this.caption});

  final String text;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  text,
                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
            ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(caption!, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
