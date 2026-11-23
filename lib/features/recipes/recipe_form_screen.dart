import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/ids.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_format.dart';
import '../../domain/recipe_labels.dart';
import '../../domain/recipe_version.dart';
import '../../domain/voice_draft.dart';
import 'recipe_labels_sheet.dart';
import 'recipe_providers.dart';

/// Ručni unos novog recepta ([id] == null) ili izmena postojećeg.
class RecipeFormScreen extends ConsumerStatefulWidget {
  const RecipeFormScreen({super.key, this.id, this.draft});

  final String? id;

  /// Nacrt iz „Recept glasom“: popunjava nov recept, a osoba ga pregleda i
  /// čuva (spec 027, pravilo 3).
  final VoiceDraft? draft;

  @override
  ConsumerState<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends ConsumerState<RecipeFormScreen> {
  final _title = TextEditingController();
  final _servings = TextEditingController(text: '2');
  final _prep = TextEditingController();
  final _steps = TextEditingController();
  List<Ingredient> _ingredients = [];
  LabelChoice _labels = labelChoiceOf(RecipeLabels.none);
  Recipe? _original;
  bool _loading = false;
  bool _dirty = false;
  bool _saving = false;
  String? _titleError;
  String? _ingredientsError;

  @override
  void initState() {
    super.initState();
    final id = widget.id;
    if (id != null) {
      _loading = true;
      unawaited(_load(id));
    } else if (widget.draft case final draft?) {
      _title.text = draft.title ?? '';
      if (draft.servings case final n?) _servings.text = '$n';
      _steps.text = draft.steps.join('\n');
      _ingredients = [...draft.ingredients];
      // Nesačuvan nacrt: izlazak traži potvrdu.
      _dirty = !draft.isEmpty;
    }
  }

  Future<void> _load(String id) async {
    final recipe = await ref.read(recipeRepositoryProvider).get(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _original = recipe;
      if (recipe != null) {
        _title.text = recipe.title;
        _servings.text = '${recipe.servings}';
        _prep.text = recipe.prepMinutes?.toString() ?? '';
        _steps.text = recipe.steps.join('\n');
        _ingredients = [...recipe.ingredients];
        _labels = labelChoiceOf(recipe.labels);
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _servings.dispose();
    _prep.dispose();
    _steps.dispose();
    super.dispose();
  }

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _editIngredient([int? index]) async {
    final result = await showDialog<Ingredient>(
      context: context,
      builder: (context) => _IngredientDialog(
        initial: index == null ? null : _ingredients[index],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _ingredients = [..._ingredients, result];
      } else {
        _ingredients = [..._ingredients]..[index] = result;
      }
      _dirty = true;
      _ingredientsError = null;
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    setState(() {
      _titleError = title.isEmpty ? 'Unesi naziv recepta.' : null;
      _ingredientsError = _ingredients.isEmpty
          ? 'Dodaj bar jedan sastojak.'
          : null;
    });
    if (_titleError != null || _ingredientsError != null) return;

    final servings = (int.tryParse(_servings.text.trim()) ?? 2).clamp(1, 99);
    final prep = int.tryParse(_prep.text.trim());
    final steps = [
      for (final line in _steps.text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    final repo = ref.read(recipeRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final original = _original;
    final Recipe recipe;
    setState(() => _saving = true);
    if (original == null) {
      final now = ref.read(clockProvider)();
      recipe = Recipe(
        id: newId(),
        title: title,
        servings: servings,
        prepMinutes: prep,
        ingredients: _ingredients,
        steps: steps,
        source: RecipeSource.manual,
        createdAt: now,
        labels: isEmptyChoice(_labels)
            ? RecipeLabels.none
            : labelsByUser(_labels),
      );
      await repo.create(recipe);
    } else {
      recipe = original.copyWith(
        title: title,
        servings: servings,
        prepMinutes: prep,
        clearPrepMinutes: prep == null,
        ingredients: _ingredients,
        steps: steps,
      );
      // Nova verzija samo kad se sadržaj promenio; izmena samo oznaka ne
      // pravi praznu verziju koju bi „Poništi“ prvo potrošio.
      if (jsonEncode(recipe.toAiJson()) != jsonEncode(original.toAiJson())) {
        await repo.update(recipe, kind: ChangeKind.manual);
      }
      // Oznake nisu deo verzije recepta; menjaju se samo ako ih je korisnik
      // promenio, da AI oznake koje nije dirao ostanu AI.
      if (!sameChoice(_labels, labelChoiceOf(original.labels))) {
        await repo.setLabels(recipe.id, labelsByUser(_labels));
      }
    }
    if (!mounted) return;
    setState(() => _dirty = false);
    context.go('/recipes/${recipe.id}');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Recept je sačuvan.')));
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odbaciti izmene?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Nastavi uređivanje'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Odbaci'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    setState(() => _dirty = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.id != null;
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(editing ? 'Izmeni recept' : 'Novi recept'),
          actions: [
            TextButton(
              onPressed: _loading || _saving ? null : _save,
              child: const Text('Sačuvaj'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : editing && _original == null
            ? const Center(child: Text('Recept više ne postoji.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TavliTextField(
                            label: 'Naziv',
                            hint: 'npr. Sarma',
                            controller: _title,
                            onChanged: (_) => _changed(),
                            errorText: _titleError,
                          ),
                          const SizedBox(height: TavliSpacing.medium),
                          _NumberFields(
                            servings: TavliTextField(
                              label: 'Broj porcija',
                              controller: _servings,
                              onChanged: (_) => _changed(),
                              keyboardType: TextInputType.number,
                            ),
                            prep: TavliTextField(
                              label: 'Vreme pripreme (min)',
                              controller: _prep,
                              onChanged: (_) => _changed(),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(height: TavliSpacing.medium),
                          Text('Oznake', style: theme.textTheme.titleMedium),
                          RecipeLabelsPicker(
                            value: _labels,
                            onChanged: (update) => setState(() {
                              _labels = update(_labels);
                              _dirty = true;
                            }),
                          ),
                          const SizedBox(height: 20),
                          Text('Sastojci', style: theme.textTheme.titleMedium),
                          for (final (n, i) in _ingredients.indexed)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(ingredientLine(i)),
                              subtitle: Text(i.category),
                              onTap: () => _editIngredient(n),
                              trailing: IconButton(
                                tooltip: 'Ukloni sastojak',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => setState(() {
                                  _ingredients = [..._ingredients]..removeAt(n);
                                  _dirty = true;
                                }),
                              ),
                            ),
                          if (_ingredientsError case final error?)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                error,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _editIngredient,
                              icon: const Icon(Icons.add),
                              label: const Text('Dodaj sastojak'),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TavliTextField(
                            label: 'Koraci pripreme (jedan po redu)',
                            controller: _steps,
                            onChanged: (_) => _changed(),
                            keyboardType: TextInputType.multiline,
                            minLines: 4,
                            maxLines: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Porcije i minuti jedno pored drugog; uz krupan tekst ili na uskom ekranu
/// jedno ispod drugog, da se nazivi ne seku.
class _NumberFields extends StatelessWidget {
  const _NumberFields({required this.servings, required this.prep});

  final Widget servings;
  final Widget prep;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 20;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (largeText || constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              servings,
              const SizedBox(height: TavliSpacing.medium),
              prep,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: servings),
            const SizedBox(width: TavliSpacing.medium),
            Expanded(child: prep),
          ],
        );
      },
    );
  }
}

class _IngredientDialog extends StatefulWidget {
  const _IngredientDialog({this.initial});

  final Ingredient? initial;

  @override
  State<_IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<_IngredientDialog> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _quantity = TextEditingController(
    text: widget.initial?.quantity == null
        ? ''
        : formatQuantity(widget.initial!.quantity!),
  );
  late final _unit = TextEditingController(text: widget.initial?.unit);
  late final _note = TextEditingController(text: widget.initial?.note);
  late String _category = widget.initial?.category ?? 'ostalo';

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    // Isto čitanje kao za AI odgovor: "0,5", "1/2", prazno → bez količine.
    Navigator.of(context).pop(
      Ingredient.fromJson({
        'name': _name.text,
        'quantity': _quantity.text,
        'unit': _unit.text,
        'category': _category,
        'note': _note.text,
        // Veza sa katalogom ostaje; ako se naziv promeni, prestaje da važi
        // sama (matchedKey se više ne poklapa, ugovor #30).
        ...?widget.initial?.link?.toJson(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sastojak'),
      content: SingleChildScrollView(
        // Razmak mora biti eksplicitan: polja ga nemaju sama od sebe, pa bi se
        // uokvirena polja i plutajuće oznake dodirivali i preklapali.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: TavliSpacing.medium,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Naziv'),
            ),
            Row(
              spacing: TavliSpacing.medium,
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Količina'),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: 'Jedinica'),
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kategorija'),
              items: [
                for (final c in ingredientCategories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (c) => setState(() => _category = c ?? 'ostalo'),
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Napomena'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Otkaži'),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          child: const Text('Sačuvaj'),
        ),
      ],
    );
  }
}
