import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../ai/ai_errors.dart';
import '../../ai/ai_models.dart';
import '../../ai/key_store.dart';
import '../../ai/model_check.dart';
import '../../domain/recipe_format.dart';
import '../../providers.dart';
import 'ai_error_text.dart';
import 'settings_page.dart';

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
      keys = await _ownKeys();
    } on SecretStorageException {
      if (!mounted) return;
      setState(
        () => _loadError = 'Bezbedno skladište nije dostupno. Proveri da li je sistemski keyring pokrenut i otključan.',
      );
      return;
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

  /// Samo ključevi koje je korisnik dodao. Ključ koji je isti kao ugrađeni
  /// (npr. sačuvan ranije ručno) briše se iz liste: on je ugrađeni i radi
  /// u pozadini.
  Future<List<StoredKey>> _ownKeys() async {
    final store = ref.read(keyStoreProvider);
    final builtIn = ref.read(builtInKeysProvider);
    final all = await store.list();
    for (final k in all.where((k) => builtIn.contains(k.value))) {
      await store.remove(k.id);
    }
    return [
      for (final k in all)
        if (!builtIn.contains(k.value)) k,
    ];
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
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (ref.read(builtInKeysProvider).contains(value) ||
          (await store.list()).any((k) => k.value == value)) {
        return _show('Ovaj ključ je već dodat.', error: true);
      }
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
    } on SecretStorageException {
      if (mounted) {
        _show(
          'Bezbedno skladište nije dostupno. Proveri da li je sistemski keyring pokrenut i otključan.',
          error: true,
        );
      }
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
    final confirmed = await showTavliConfirm(
      context,
      title: 'Obrisati ključ ${key.masked}?',
      confirmLabel: 'Obriši',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(keyStoreProvider).remove(key.id);
    } on SecretStorageException {
      if (!mounted) return;
      _show(
        'Bezbedno skladište nije dostupno. Proveri da li je sistemski keyring pokrenut i otključan.',
        error: true,
      );
      return;
    }
    _status.remove(key.id);
    _models.remove(key.id);
    _show('Ključ je obrisan.');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final detected = detectProvider(_input.text);
    final hasText = _input.text.trim().isNotEmpty;
    final message = _message;
    final newKey = SettingsSection(
      title: 'Novi ključ',
      children: [
        const TavliNotice(
          title:
              'Ključevi se čuvaju samo na ovom uređaju, u sistemskom '
              'sigurnom skladištu.',
          message:
              'Možeš dodati više ključeva: kad se jednom potroši besplatni '
              'limit, Tavli koristi sledeći. Ključ praviš na '
              'aistudio.google.com/apikey, console.groq.com/keys ili '
              'openrouter.ai/keys.',
        ),
        TavliCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TavliSpacing.medium,
            children: [
              TavliTextField(
                label: 'API ključ',
                controller: _input,
                obscureText: _obscure,
                autocorrect: false,
                onSubmitted: (_) => _add(),
                trailing: TavliIconButton(
                  icon: _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  semanticLabel: _obscure ? 'Prikaži' : 'Sakrij',
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              if (hasText && detected != null)
                Text(
                  'Prepoznat servis: ${detected.label}',
                  style: _muted(context),
                ),
              if (hasText && detected == null) ...[
                Text('Izaberi servis', style: _muted(context)),
                TavliChoice<AIProvider?>.chips(
                  options: [
                    for (final p in AIProvider.values)
                      if (p.supportsPersonalKey) TavliOption(p, p.label),
                  ],
                  selected: _chosen,
                  onChanged: (p) => setState(() => _chosen = p),
                ),
              ],
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TavliButton.primary(
                  label: 'Dodaj ključ',
                  icon: Icons.add_rounded,
                  onPressed: _busy || !hasText || _provider == null
                      ? null
                      : _add,
                ),
              ),
              if (_busy) const TavliLoading(message: 'Proveravam ključ…'),
              if (message != null)
                TavliNotice(
                  message: message,
                  tone: _messageIsError
                      ? TavliNoticeTone.error
                      : TavliNoticeTone.success,
                ),
            ],
          ),
        ),
      ],
    );
    return SettingsPage(
      title: 'AI ključevi',
      backLabel: 'Profil',
      fallbackLocation: '/profile',
      children: [
        SettingsColumns(
          start: [newKey],
          end: [
            SettingsSection(title: 'Dodati ključevi', children: _savedKeys()),
          ],
        ),
      ],
    );
  }

  List<Widget> _savedKeys() {
    final keys = _keys;
    if (_loadError case final error?) {
      return [
        TavliNotice(
          tone: TavliNoticeTone.error,
          message: 'Ključevi nisu učitani iz sigurnog skladišta ($error).',
          linkLabel: 'Pokušaj ponovo',
          onLink: () {
            setState(() => _loadError = null);
            unawaited(_load());
          },
        ),
      ];
    }
    if (keys == null) {
      return const [
        TavliLoading(
          message:
              'Ako macOS traži lozinku za Keychain, izaberi „Always Allow“.',
        ),
      ];
    }
    if (keys.isEmpty) {
      return [Text('Još nema dodatih ključeva.', style: _muted(context))];
    }
    return [
      for (final p in AIProvider.values)
        if (p.supportsPersonalKey && keys.any((k) => k.provider == p)) ...[
          TavliSectionHeader(p.label, style: TavliSectionHeaderStyle.bold),
          TavliListGroup(
            children: [
              for (final k in keys.where((k) => k.provider == p))
                _SavedKeyRow(
                  storedKey: k,
                  status: _status[k.id],
                  models: _models[k.id] ?? const [],
                  checking: _checking.contains(k.id),
                  onCheck: () => _check(k),
                  onRemove: () => _remove(k),
                ),
            ],
          ),
        ],
    ];
  }
}

TextStyle? _muted(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

class _SavedKeyRow extends StatelessWidget {
  const _SavedKeyRow({
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
    final added = formatDateTime(storedKey.addedAt.toLocal()).split(' ').first;
    final s = status;
    final modelLines = [
      for (final m in models)
        m.listed
            ? '✓ ${m.spec.label}'
            : '? ${m.spec.label}: nije na listi (alias ili ukinut model)',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TavliListRow(
          title: storedKey.masked,
          subtitle: ['Dodat $added', if (s != null) s.label].join(' · '),
          destructive: s == _KeyStatus.rejected,
          leading: Icon(
            s == _KeyStatus.rejected
                ? Icons.error_outline_rounded
                : s == _KeyStatus.works
                ? Icons.check_circle_outline_rounded
                : Icons.key_outlined,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TavliButton.text(
                label: 'Proveri',
                onPressed: checking ? null : onCheck,
              ),
              TavliIconButton(
                icon: Icons.delete_outline_rounded,
                semanticLabel: 'Obriši ključ',
                onPressed: onRemove,
              ),
            ],
          ),
        ),
        if (checking) const TavliLoading(message: 'Proveravam ključ…'),
        for (final line in modelLines)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: TavliSpacing.medium,
            ),
            child: Text(line, style: _muted(context)),
          ),
        if (modelLines.isNotEmpty) const SizedBox(height: TavliSpacing.small),
      ],
    );
  }
}
