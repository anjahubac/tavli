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
import 'own_key_order.dart';
import 'settings_page.dart';

enum _KeyStatus {
  works('Radi'),
  rejected('Odbijen'),
  unchecked('Nije provereno');

  const _KeyStatus(this.label);

  final String label;
}

/// Jedno polje za dodavanje ključa bilo kog podržanog servisa (prepoznaje se
/// po početku ključa) i lista ključeva koje je korisnik dodao. Ključevi koji
/// dolaze uz aplikaciju se pominju samo kao kraj redosleda, bez prikaza.
class AiKeysScreen extends ConsumerStatefulWidget {
  const AiKeysScreen({super.key});

  @override
  ConsumerState<AiKeysScreen> createState() => _AiKeysScreenState();
}

class _AiKeysScreenState extends ConsumerState<AiKeysScreen> {
  final _input = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
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

  void _show(String message, {bool error = false}) => setState(() {
    _message = message;
    _messageIsError = error;
  });

  static final _supported = [
    for (final p in AIProvider.values)
      if (p.supportsPersonalKey) p.label,
  ].join(', ');

  Future<void> _add() async {
    final value = _input.text.trim();
    final provider = detectProvider(value);
    if (value.isEmpty || provider == null) return;
    final store = ref.read(keyStoreProvider);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if ((await store.list()).any((k) => k.value == value)) {
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
              'Tavli prvo koristi tvoje ključeve, redom. Kad se njihov '
              'besplatni limit potroši, prelazi na besplatne ključeve koji '
              'dolaze uz aplikaciju.',
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
              if (hasText && detected == null)
                Text(
                  'Servis nije prepoznat. Podržani su: $_supported.',
                  style: _muted(context),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TavliButton.primary(
                  label: 'Dodaj ključ',
                  icon: Icons.add_rounded,
                  onPressed: _busy || detected == null ? null : _add,
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
    final order = ref.watch(ownKeyOrderProvider).value;
    final mixed =
        keys.any((k) => k.provider.paid) && keys.any((k) => !k.provider.paid);
    return [
      if (mixed && order != null) ...[
        const TavliSectionHeader(
          'Redosled',
          style: TavliSectionHeaderStyle.bold,
        ),
        TavliChoice<OwnKeyOrder>.segmented(
          options: const [
            TavliOption(OwnKeyOrder.paidFirst, 'Prvo plaćeni'),
            TavliOption(OwnKeyOrder.freeFirst, 'Prvo besplatni'),
          ],
          selected: order,
          onChanged: (o) =>
              unawaited(ref.read(ownKeyOrderProvider.notifier).set(o)),
        ),
        Text(
          'Važi za tvoje ključeve. Ključevi koji dolaze uz aplikaciju uvek '
          'idu na kraju.',
          style: _muted(context),
        ),
      ],
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
    final stacked = isLargeText(context);
    final actions = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
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
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TavliListRow(
          title: storedKey.masked,
          subtitle: [
            'Dodat $added',
            storedKey.provider.paid ? 'plaćen' : 'besplatan',
            if (s != null) s.label,
          ].join(' · '),
          destructive: s == _KeyStatus.rejected,
          leading: Icon(
            s == _KeyStatus.rejected
                ? Icons.error_outline_rounded
                : s == _KeyStatus.works
                ? Icons.check_circle_outline_rounded
                : Icons.key_outlined,
          ),
          trailing: stacked ? null : actions,
        ),
        // Uz krupan tekst dugmad ne staju pored naziva na uskom ekranu.
        if (stacked)
          Align(alignment: AlignmentDirectional.centerEnd, child: actions),
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
