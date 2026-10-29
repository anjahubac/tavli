import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_errors.dart';
import '../../ai/ai_models.dart';
import '../../ai/model_check.dart';
import '../../providers.dart';
import 'ai_error_text.dart';
import 'chain_test_card.dart';

const _keyPages = {
  AIProvider.gemini: 'aistudio.google.com/apikey',
  AIProvider.groq: 'console.groq.com/keys',
  AIProvider.openRouter: 'openrouter.ai/keys',
};

class AiKeysScreen extends StatelessWidget {
  const AiKeysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI ključevi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Ključevi se čuvaju samo na ovom uređaju, u sistemskom '
            'sigurnom skladištu. Dovoljan je jedan, a sa više ključeva '
            'Tavli ima rezervu kad se potroši besplatni limit.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (final p in AIProvider.values) ...[
            _ProviderKeyCard(provider: p),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          const ChainTestCard(),
        ],
      ),
    );
  }
}

class _ProviderKeyCard extends ConsumerStatefulWidget {
  const _ProviderKeyCard({required this.provider});

  final AIProvider provider;

  @override
  ConsumerState<_ProviderKeyCard> createState() => _ProviderKeyCardState();
}

class _ProviderKeyCardState extends ConsumerState<_ProviderKeyCard> {
  final _controller = TextEditingController();
  bool _hasSavedKey = false;
  bool _obscure = true;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;
  List<ModelAvailability> _models = const [];

  AIProvider get _p => widget.provider;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSaved());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final key = await ref.read(keyStoreProvider).read(_p);
    if (mounted) setState(() => _hasSavedKey = key != null && key.isNotEmpty);
  }

  void _show(String message, {bool error = false}) => setState(() {
    _message = message;
    _messageIsError = error;
  });

  Future<void> _save() async {
    final key = _controller.text.trim();
    if (key.isEmpty) return _show('Prvo nalepi ključ.', error: true);
    await ref.read(keyStoreProvider).write(_p, key);
    ref.read(aiRouterProvider).resetProvider(_p);
    _controller.clear();
    setState(() => _hasSavedKey = true);
    await _check();
  }

  Future<void> _delete() async {
    await ref.read(keyStoreProvider).delete(_p);
    _controller.clear();
    setState(() {
      _hasSavedKey = false;
      _models = const [];
    });
    _show('Ključ je obrisan.');
  }

  /// Proverava ključ preko liste modela (ne troši limit za generisanje).
  Future<void> _check() async {
    final typed = _controller.text.trim();
    final key = typed.isNotEmpty
        ? typed
        : await ref.read(keyStoreProvider).read(_p);
    if (key == null || key.isEmpty) {
      return _show('Nema ključa za proveru.', error: true);
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final ids = await ref.read(chatClientProvider).listModels(_p, key);
      final models = checkChainModels(ref.read(chainConfigProvider), _p, ids);
      setState(() => _models = models);
      _show('Ključ radi. Dostupno modela: ${ids.length}.');
    } on AIError catch (e) {
      setState(() => _models = const []);
      _show(aiErrorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final usesBuiltIn = !_hasSavedKey && ref.watch(builtInKeysProvider).has(_p);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_p.label, style: theme.textTheme.titleMedium),
                ),
                Chip(
                  avatar: Icon(
                    _hasSavedKey
                        ? Icons.check_circle
                        : usesBuiltIn
                        ? Icons.auto_awesome
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: _hasSavedKey || usesBuiltIn
                        ? colors.primary
                        : colors.outline,
                  ),
                  label: Text(
                    _hasSavedKey
                        ? 'Sačuvan'
                        : usesBuiltIn
                        ? 'Tavli AI'
                        : 'Nema ključa',
                  ),
                ),
              ],
            ),
            if (usesBuiltIn) ...[
              Text(
                'Koristi se ugrađeni Tavli AI',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.primary,
                ),
              ),
              Text(
                'Sopstveni ključ ima prednost kad ga sačuvaš.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
            ],
            SelectableText(
              'Ključ praviš na ${_keyPages[_p]}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: _hasSavedKey
                    ? 'Novi ključ (zamenjuje sačuvani)'
                    : 'API ključ',
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Prikaži' : 'Sakrij',
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Sačuvaj'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _check,
                  child: const Text('Proveri'),
                ),
                if (_hasSavedKey)
                  TextButton(
                    onPressed: _busy ? null : _delete,
                    child: const Text('Obriši'),
                  ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(
                  color: _messageIsError ? colors.error : colors.primary,
                ),
              ),
            ],
            for (final m in _models)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(
                      m.listed ? Icons.check : Icons.help_outline,
                      size: 18,
                      color: m.listed ? colors.primary : colors.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m.listed
                            ? m.spec.label
                            : '${m.spec.label}: nije na listi (alias ili ukinut model)',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
