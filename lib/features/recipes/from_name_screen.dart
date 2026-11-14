import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/recipe.dart';
import '../../providers.dart';
import '../settings/ai_error_text.dart';
import 'ai_preview.dart';
import 'recipe_providers.dart';
import 'recipe_view.dart';

/// Novi recept po nazivu jela: unos → AI → pregled → čuvanje.
class FromNameScreen extends ConsumerStatefulWidget {
  const FromNameScreen({super.key});

  @override
  ConsumerState<FromNameScreen> createState() => _FromNameScreenState();
}

class _FromNameScreenState extends ConsumerState<FromNameScreen> {
  final _name = TextEditingController();
  final _wishes = TextEditingController();
  int _servings = 2;
  bool _busy = false;
  bool _saving = false;
  String? _error;
  Recipe? _result;

  /// Raste sa svakim zahtevom; odgovor prekinutog zahteva se odbacuje.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _wishes.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final r = await ref
          .read(recipeAIProvider)
          .fromDishName(name, servings: _servings, notes: _wishes.text.trim());
      if (!mounted || request != _request) return;
      setState(() => _result = r.value);
    } on Exception catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _error = aiErrorText(e));
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  void _cancel() => setState(() {
    _request++;
    _busy = false;
  });

  Future<void> _save(Recipe recipe) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(recipeRepositoryProvider).create(recipe);
    if (!mounted) return;
    context.go('/recipes/${recipe.id}');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Recept je sačuvan.')));
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Recept po nazivu jela')),
      body: result != null
          ? AiRecipePreview(
              recipe: result,
              saving: _saving,
              onSave: () => _save(result),
              onRetry: _generate,
              onDiscard: () => setState(() => _result = null),
            )
          : ReadableScroll(
              children: [
                TextField(
                  controller: _name,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Naziv jela',
                    hintText: 'npr. sarma, musaka, palačinke',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Text('Broj porcija')),
                    IconButton(
                      tooltip: 'Manje porcija',
                      onPressed: _servings > 1
                          ? () => setState(() => _servings--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text(
                      '$_servings',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      tooltip: 'Više porcija',
                      onPressed: _servings < 20
                          ? () => setState(() => _servings++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _wishes,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Želje (nije obavezno)',
                    hintText: 'npr. bez luka, posno',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy || _name.text.trim().isEmpty
                      ? null
                      : _generate,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Napravi recept'),
                ),
                const SizedBox(height: 16),
                if (_busy) AiBusy('Pravim recept…', onCancel: _cancel),
                if (_error case final error?)
                  AiErrorBox(
                    error,
                    actions: [
                      TextButton(
                        onPressed: _generate,
                        child: const Text('Pokušaj ponovo'),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
