import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../ai/ai_models.dart';
import '../../ai/pantry_ai.dart';
import '../../app/animations/photo_scan.dart';
import '../../providers.dart';
import '../recipes/ai_preview.dart';
import '../recipes/from_photo_screen.dart'
    show isPhonePlatform, photoPickErrorText;
import '../recipes/recipe_providers.dart';
import '../recipes/recipe_view.dart';
import '../settings/ai_error_text.dart';
import '../shopping/shopping_list_view.dart' show amountLabel;
import '../shopping/shopping_providers.dart' show pantryRepositoryProvider;
import 'pantry_amount_form.dart';

/// Namirnice u ostavu sa slike (jedna namirnica, polica ili frižider):
/// izbor slike → smanjivanje → AI → pregled (štikliranje i izmena količine)
/// → „Dodaj u ostavu“. Slika se ne čuva. Na računaru meni već bira sliku i
/// prosleđuje je kao [initialPhoto].
class PantryPhotoScreen extends ConsumerStatefulWidget {
  const PantryPhotoScreen({super.key, this.initialPhoto});

  /// Već izabrana (nesmanjena) slika; ekran odmah počinje čitanje.
  final Uint8List? initialPhoto;

  @override
  ConsumerState<PantryPhotoScreen> createState() => _PantryPhotoScreenState();
}

class _PantryPhotoScreenState extends ConsumerState<PantryPhotoScreen> {
  Uint8List? _photo;
  bool _busy = false;
  bool _saving = false;
  String? _error;
  bool _noFood = false;
  List<PhotoFoodItem>? _items;
  final _skipped = <int>{};

  /// Raste sa svakim zahtevom; odgovor prekinutog zahteva se odbacuje.
  int _request = 0;
  AICancellation? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoto case final picked?) {
      _busy = true;
      unawaited(Future.microtask(() => _process(picked)));
    }
  }

  Future<void> _pick({required bool camera}) async {
    final Uint8List? picked;
    try {
      picked = await ref.read(photoPickerProvider).pick(camera: camera);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _error = photoPickErrorText(e, camera: camera));
      return;
    }
    if (picked == null || !mounted) return;
    await _process(picked);
  }

  Future<void> _process(Uint8List picked) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _noFood = false;
      _items = null;
      _photo = null;
    });
    try {
      final jpeg = await ref.read(photoResizerProvider)(picked);
      if (!mounted) return;
      setState(() => _photo = jpeg);
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Ova slika ne može da se otvori.';
      });
      return;
    }
    await _read();
  }

  Future<void> _read() async {
    final photo = _photo;
    if (photo == null) return;
    final request = ++_request;
    _cancelToken?.cancel();
    final cancel = _cancelToken = AICancellation();
    setState(() {
      _busy = true;
      _error = null;
      _noFood = false;
      _items = null;
      _skipped.clear();
    });
    try {
      final r = await ref
          .read(pantryAIProvider)
          .fromPhoto(AIImage(photo), cancel: cancel);
      if (!mounted || request != _request) return;
      setState(() => _items = r.value);
    } on Exception catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = aiErrorText(e);
        _noFood = e is NoFoodOnPhotoException;
      });
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  void _cancel() => setState(() {
    _cancelToken?.cancel();
    _request++;
    _busy = false;
    _error = 'Prepoznavanje je prekinuto.';
  });

  void _reset() => setState(() {
    _cancelToken?.cancel();
    _request++;
    _photo = null;
    _items = null;
    _error = null;
    _noFood = false;
    _skipped.clear();
  });

  Future<void> _edit(int index) async {
    final item = _items![index];
    await showTavliSheet<void>(
      context,
      title: item.name,
      builder: (sheetContext) => PantryAmountForm(
        initialQuantity: item.quantity,
        initialUnit: item.unit ?? 'kom',
        saveLabel: 'Sačuvaj',
        onSave: (q, u) {
          setState(
            () => _items = [
              for (final (i, it) in _items!.indexed)
                if (i == index)
                  PhotoFoodItem(
                    name: it.name,
                    quantity: q,
                    unit: u,
                    category: it.category,
                  )
                else
                  it,
            ],
          );
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  Future<void> _save() async {
    final items = _items;
    if (items == null) return;
    setState(() => _saving = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final chosen = [
      for (final (i, it) in items.indexed)
        if (!_skipped.contains(i))
          (
            name: it.name,
            quantity: it.quantity,
            unit: it.unit,
            category: it.category,
          ),
    ];
    final n = await ref.read(pantryRepositoryProvider).addAll(chosen);
    if (!mounted) return;
    router.go('/pantry');
    showTavliMessageOn(messenger, 'Dodato u ostavu: $n');
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final photo = _photo;
    final showCamera =
        isPhonePlatform(context) && ref.watch(photoPickerProvider).canUseCamera;
    final chosenCount = items == null ? 0 : items.length - _skipped.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Namirnice sa slike')),
      body: items != null
          ? Column(
              children: [
                Expanded(
                  child: ReadableScroll(
                    children: [
                      Text(
                        'Ovo je prepoznato na slici. Proveri nazive, štikliraj ono '
                        'što želiš u ostavi i, ako hoćeš, upiši količinu.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: TavliSpacing.medium),
                      TavliListGroup(
                        children: [
                          for (final (i, it) in items.indexed)
                            TavliCheckRow(
                              key: ValueKey('$i-${it.name}'),
                              title: it.name,
                              detail: amountLabel(it.quantity, it.unit),
                              checked: !_skipped.contains(i),
                              onChanged: (on) => setState(
                                () => on ? _skipped.remove(i) : _skipped.add(i),
                              ),
                              trailing: TavliIconButton(
                                glyph: TavliIcons.edit,
                                semanticLabel: 'Izmeni ${it.name}',
                                onPressed: () => unawaited(_edit(i)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(TavliSpacing.medium),
                    child: Row(
                      spacing: TavliSpacing.small,
                      children: [
                        Expanded(
                          child: TavliButton.secondary(
                            label: 'Odbaci',
                            onPressed: _saving ? null : _reset,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TavliButton.primary(
                            label: 'Dodaj u ostavu ($chosenCount)',
                            onPressed: _saving || chosenCount == 0
                                ? null
                                : () => unawaited(_save()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ReadableScroll(
              children: [
                if (photo != null) ...[
                  PhotoScan(
                    scanning: _busy,
                    height: 280,
                    photo: Image.memory(
                      photo,
                      fit: BoxFit.contain,
                      semanticLabel: 'Izabrana slika namirnica',
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  const Text(
                    'Slikaj jednu namirnicu, policu ili otvoren frižider. Slika se '
                    'ne čuva, samo se prepoznaju namirnice.',
                  ),
                  const SizedBox(height: 16),
                  if (showCamera) ...[
                    TavliButton.primary(
                      label: 'Slikaj',
                      icon: Icons.photo_camera_outlined,
                      onPressed: _busy ? null : () => _pick(camera: true),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TavliButton.secondary(
                    label: 'Izaberi iz galerije',
                    icon: Icons.photo_library_outlined,
                    onPressed: _busy ? null : () => _pick(camera: false),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_busy)
                  AiBusy(
                    'Prepoznajem namirnice…',
                    onCancel: _photo == null ? null : _cancel,
                    pot: _photo == null,
                  ),
                if (_error case final error?)
                  AiErrorBox(
                    error,
                    actions: [
                      if (photo != null && !_noFood)
                        TextButton(
                          onPressed: _read,
                          child: const Text('Pokušaj ponovo'),
                        ),
                      if (photo != null)
                        TextButton(
                          onPressed: _reset,
                          child: const Text('Izaberi drugu sliku'),
                        ),
                    ],
                  ),
              ],
            ),
    );
  }
}
