import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_errors.dart';
import '../../ai/ai_models.dart';
import '../../ai/key_store.dart';
import '../../ai/model_check.dart';
import '../../domain/recipe_format.dart';
import '../../providers.dart';
import 'ai_error_text.dart';
import 'chain_test_card.dart';

enum _KeyStatus {
  works('Radi'),
  rejected('Odbijen'),
  unchecked('Nije provereno');

  const _KeyStatus(this.label);

  final String label;
}

/// Jedno polje za dodavanje bilo kog ključa i lista ključeva koje je
/// korisnik dodao. Ugrađeni ključevi aplikacije se ovde nikad ne pominju.
class AiKeysScreen extends ConsumerStatefulWidget {
  const AiKeysScreen({super.key});

  @override
  ConsumerState<AiKeysScreen> createState() => _AiKeysScreenState();
}

class _AiKeysScreenState extends ConsumerState<AiKeysScreen> {
  final _input = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  AIProvider? _chosen;
  String? _message;
  bool _messageIsError = false;
  List<StoredKey>? _keys;
  String? _loadError;
  final _status = <String, _KeyStatus>{};
  final _models = <String, List<ModelAvailability>>{};
  final _checking = <String>{};

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    unawaited(_load());
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final List<StoredKey> keys;
    try {
      keys = await ref.read(keyStoreProvider).list();
    } on Exception catch (e) {
      if (!mounted) return;
      // Tip greške, nikad sadržaj (može da sadrži ključ).
      setState(() => _loadError = e.runtimeType.toString());
      return;
    }
    if (!mounted) return;
    final rejected = ref.read(aiRouterProvider).invalidKeyIds;
    setState(() {
      _keys = keys;
      for (final id in rejected) {
        _status[id] = _KeyStatus.rejected;
      }
    });
  }

  void _show(String message, {bool error = false}) => setState(() {
    _message = message;
    _messageIsError = error;
  });

  AIProvider? get _provider => detectProvider(_input.text) ?? _chosen;

  Future<void> _add() async {
    final value = _input.text.trim();
    final provider = _provider;
    if (value.isEmpty || provider == null) return;
    final store = ref.read(keyStoreProvider);
    if ((await store.list()).any((k) => k.value == value)) {
      return _show('Ovaj ključ je već dodat.', error: true);
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // Provera preko liste modela ne troši limit za generisanje.
      _KeyStatus status;
      List<ModelAvailability> models = const [];
      String? checkError;
      try {
        final ids = await ref
            .read(chatClientProvider)
            .listModels(provider, value);
        models = checkChainModels(ref.read(chainConfigProvider), provider, ids);
        status = _KeyStatus.works;
      } on AuthError catch (e) {
        return _show(aiErrorText(e), error: true);
      } on AIError catch (e) {
        status = _KeyStatus.unchecked;
        checkError = aiErrorText(e);
      }
      final StoredKey key;
      try {
        key = await store.add(provider, value);
      } on DuplicateKeyException {
        return _show('Ovaj ključ je već dodat.', error: true);
      }
      _input.clear();
      _status[key.id] = status;
      _models[key.id] = models;
      _chosen = null;
      _show(
        checkError == null
            ? 'Ključ je dodat (${provider.label}).'
            : 'Ključ je dodat (${provider.label}), ali nije proveren: '
                  '$checkError',
        error: checkError != null,
      );
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check(StoredKey key) async {
    setState(() => _checking.add(key.id));
    try {
      final ids = await ref
          .read(chatClientProvider)
          .listModels(key.provider, key.value);
      ref.read(aiRouterProvider).resetKey(key.id);
      if (!mounted) return;
      setState(() {
        _status[key.id] = _KeyStatus.works;
        _models[key.id] = checkChainModels(
          ref.read(chainConfigProvider),
          key.provider,
          ids,
        );
      });
    } on AuthError {
      if (mounted) setState(() => _status[key.id] = _KeyStatus.rejected);
    } on AIError catch (e) {
      if (!mounted) return;
      setState(() => _status[key.id] = _KeyStatus.unchecked);
      _show(aiErrorText(e), error: true);
    } finally {
      if (mounted) setState(() => _checking.remove(key.id));
    }
  }

  Future<void> _remove(StoredKey key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Obrisati ključ ${key.masked}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Otkaži'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(keyStoreProvider).remove(key.id);
    _status.remove(key.id);
    _models.remove(key.id);
    _show('Ključ je obrisan.');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keys = _keys;
    final detected = detectProvider(_input.text);
    final hasText = _input.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('AI ključevi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ključevi se čuvaju samo na ovom uređaju, u sistemskom '
                    'sigurnom skladištu. Možeš dodati više ključeva: kad se '
                    'jednom potroši besplatni limit, Tavli koristi sledeći.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    'Ključ praviš na aistudio.google.com/apikey, '
                    'console.groq.com/keys ili openrouter.ai/keys.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _input,
                            obscureText: _obscure,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'API ključ',
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'Prikaži' : 'Sakrij',
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            onSubmitted: (_) => _add(),
                          ),
                          if (hasText && detected != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Prepoznat servis: ${detected.label}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                          if (hasText && detected == null) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<AIProvider>(
                              initialValue: _chosen,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Izaberi servis',
                              ),
                              items: [
                                for (final p in AIProvider.values)
                                  DropdownMenuItem(
                                    value: p,
                                    child: Text(p.label),
                                  ),
                              ],
                              onChanged: (p) => setState(() => _chosen = p),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.icon(
                              onPressed: _busy || !hasText || _provider == null
                                  ? null
                                  : _add,
                              icon: const Icon(Icons.add),
                              label: const Text('Dodaj ključ'),
                            ),
                          ),
                          if (_busy) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(),
                          ],
                          if (_message case final message?) ...[
                            const SizedBox(height: 12),
                            Text(
                              message,
                              style: TextStyle(
                                color: _messageIsError
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Dodati ključevi', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_loadError case final error?) ...[
                    Text(
                      'Ključevi nisu učitani iz sigurnog skladišta ($error).',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          setState(() => _loadError = null);
                          unawaited(_load());
                        },
                        child: const Text('Pokušaj ponovo'),
                      ),
                    ),
                  ] else if (keys == null)
                    const Column(
                      children: [
                        Center(child: CircularProgressIndicator()),
                        SizedBox(height: 8),
                        Text(
                          'Ako macOS traži lozinku za Keychain, izaberi '
                          '„Always Allow“.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  else if (keys.isEmpty)
                    const Text('Još nema dodatih ključeva.')
                  else
                    for (final p in AIProvider.values)
                      if (keys.any((k) => k.provider == p)) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            p.label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        for (final k in keys.where((k) => k.provider == p))
                          _SavedKeyTile(
                            storedKey: k,
                            status: _status[k.id],
                            models: _models[k.id] ?? const [],
                            checking: _checking.contains(k.id),
                            onCheck: () => _check(k),
                            onRemove: () => _remove(k),
                          ),
                      ],
                  const SizedBox(height: 24),
                  const ChainTestCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedKeyTile extends StatelessWidget {
  const _SavedKeyTile({
    required this.storedKey,
    required this.status,
    required this.models,
    required this.checking,
    required this.onCheck,
    required this.onRemove,
  });

  final StoredKey storedKey;
  final _KeyStatus? status;
  final List<ModelAvailability> models;
  final bool checking;
  final VoidCallback onCheck;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final added = formatDateTime(storedKey.addedAt.toLocal()).split(' ').first;
    final s = status;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  s == _KeyStatus.rejected
                      ? Icons.error_outline
                      : s == _KeyStatus.works
                      ? Icons.check_circle
                      : Icons.key,
                  color: s == _KeyStatus.rejected
                      ? colors.error
                      : colors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(storedKey.masked, style: theme.textTheme.bodyLarge),
                      Text(
                        ['Dodat $added', if (s != null) s.label].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: s == _KeyStatus.rejected ? colors.error : null,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: checking ? null : onCheck,
                  child: const Text('Proveri'),
                ),
                IconButton(
                  tooltip: 'Obriši ključ',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (checking) const LinearProgressIndicator(),
            for (final m in models)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 36),
                child: Text(
                  m.listed
                      ? '✓ ${m.spec.label}'
                      : '? ${m.spec.label}: nije na listi (alias ili ukinut model)',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
