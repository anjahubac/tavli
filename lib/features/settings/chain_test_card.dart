import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_errors.dart';
import '../../ai/key_store.dart';
import '../../domain/recipe.dart';
import '../../providers.dart';
import 'ai_error_text.dart';

/// Pravi jedan probni recept i pokazuje kojim redom je lanac probao modele.
/// Ništa se ne čuva.
class ChainTestCard extends ConsumerStatefulWidget {
  const ChainTestCard({super.key});

  @override
  ConsumerState<ChainTestCard> createState() => _ChainTestCardState();
}

class _ChainTestCardState extends ConsumerState<ChainTestCard> {
  final _dish = TextEditingController(text: 'palačinke');
  bool _busy = false;
  Recipe? _recipe;
  KeyOrigin? _origin;
  String? _error;
  List<AttemptLog> _attempts = const [];

  @override
  void dispose() {
    _dish.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final name = _dish.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _busy = true;
      _recipe = null;
      _origin = null;
      _error = null;
      _attempts = const [];
    });
    try {
      final r = await ref.read(recipeAIProvider).fromDishName(name);
      setState(() {
        _recipe = r.value;
        _origin = r.origin;
        _attempts = r.attempts;
      });
    } on AllModelsExhausted catch (e) {
      setState(() {
        _error = aiErrorText(e);
        _attempts = e.attempts;
      });
    } on Exception catch (e) {
      setState(() => _error = aiErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipe = _recipe;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Probaj AI', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Napravi probni recept i vidi koji model je odgovorio.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dish,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Naziv jela',
              ),
              onSubmitted: (_) => _run(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _run,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Napravi probni recept'),
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (recipe != null) ...[
              const SizedBox(height: 16),
              Text(recipe.title, style: theme.textTheme.titleLarge),
              Text(
                'Odgovorio: ${recipe.answeredBy}'
                '${_origin == KeyOrigin.builtIn ? ' · $_tavliAi' : ''}'
                ' · ${recipe.servings} porcije'
                '${recipe.prepMinutes == null ? '' : ' · ${recipe.prepMinutes} min'}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final i in recipe.ingredients)
                Text('• ${_quantity(i)}${i.name}'),
              const SizedBox(height: 8),
              for (final (n, s) in recipe.steps.indexed) Text('${n + 1}. $s'),
            ],
            if (_attempts.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Kako je lanac radio'),
                children: [
                  for (final a in _attempts)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        a.origin == KeyOrigin.builtIn
                            ? '${a.model.label} · $_tavliAi'
                            : a.model.label,
                      ),
                      subtitle: Text(a.outcome),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static const _tavliAi = 'Tavli AI';

  static String _quantity(Ingredient i) {
    final q = i.quantity;
    if (q == null) return '';
    final n = q == q.roundToDouble() ? q.toInt().toString() : q.toString();
    return '$n ${i.unit ?? ''} '.replaceAll('  ', ' ');
  }
}
