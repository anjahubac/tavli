import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/ai_models.dart';
import '../../ai/recipe_ai.dart';
import '../../app/animations/photo_scan.dart';
import '../../domain/recipe.dart';
import '../../providers.dart';
import '../settings/ai_error_text.dart';
import 'ai_preview.dart';
import 'photo_picker.dart';
import 'recipe_providers.dart';
import 'recipe_view.dart';

/// Telefon (Android/iOS) nudi kameru i galeriju; računar samo izbor slike.
bool isPhonePlatform(BuildContext context) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };

/// Poruka kad izbor slike ne uspe; null znači da poruke nema.
String photoPickErrorText(Exception error, {required bool camera}) =>
    switch (error) {
      PhotoAccessDeniedException() when camera =>
        'Tavli nema dozvolu za kameru. Dozvoli pristup u podešavanjima '
            'telefona.',
      PhotoAccessDeniedException() =>
        'Tavli nema dozvolu za galeriju. Dozvoli pristup u podešavanjima '
            'telefona.',
      _ => 'Slika nije učitana.',
    };

/// Novi recept sa slike: izbor slike → smanjivanje → AI → pregled → čuvanje.
/// Slika se čuva na disku tek kad korisnik sačuva recept.
/// Na računaru meni već bira sliku i prosleđuje je kao [initialPhoto].
class FromPhotoScreen extends ConsumerStatefulWidget {
  const FromPhotoScreen({super.key, this.initialPhoto});

  /// Već izabrana (nesmanjena) slika; ekran odmah počinje čitanje.
  final Uint8List? initialPhoto;

  @override
  ConsumerState<FromPhotoScreen> createState() => _FromPhotoScreenState();
}

class _FromPhotoScreenState extends ConsumerState<FromPhotoScreen> {
  Uint8List? _photo;
  bool _busy = false;
  bool _saving = false;
  String? _error;
  bool _notARecipe = false;
  Recipe? _result;

  /// Raste sa svakim zahtevom; odgovor prekinutog zahteva se odbacuje.
  int _request = 0;

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
      _notARecipe = false;
      _result = null;
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
    setState(() {
      _busy = true;
      _error = null;
      _notARecipe = false;
      _result = null;
    });
    try {
      final r = await ref.read(recipeAIProvider).fromImage(AIImage(photo));
      if (!mounted || request != _request) return;
      setState(() => _result = r.value);
    } on Exception catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = aiErrorText(e);
        _notARecipe = e is NotARecipeException;
      });
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  /// Prekida čekanje; slika ostaje pa može "Pokušaj ponovo".
  void _cancel() => setState(() {
    _request++;
    _busy = false;
    _error = 'Čitanje je prekinuto.';
  });

  void _reset() => setState(() {
    _request++;
    _photo = null;
    _result = null;
    _error = null;
    _notARecipe = false;
  });

  Future<void> _save(Recipe recipe, Uint8List photo) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final path = await ref.read(recipePhotoStoreProvider).save(photo);
    final saved = recipe.copyWith(imagePath: path);
    await ref.read(recipeRepositoryProvider).create(saved);
    if (!mounted) return;
    context.go('/recipes/${saved.id}');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Recept je sačuvan.')));
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final photo = _photo;
    final showCamera =
        isPhonePlatform(context) && ref.watch(photoPickerProvider).canUseCamera;
    return Scaffold(
      appBar: AppBar(title: const Text('Recept sa slike')),
      body: result != null && photo != null
          ? AiRecipePreview(
              recipe: result,
              photoBytes: photo,
              saving: _saving,
              onSave: () => _save(result, photo),
              onRetry: _read,
              onDiscard: _reset,
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
                      semanticLabel: 'Izabrana slika recepta',
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  const Text(
                    'Slika recepta iz kuvara, rukom pisan recept ili snimak '
                    'ekrana.',
                  ),
                  const SizedBox(height: 16),
                  if (showCamera) ...[
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _pick(camera: true),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Slikaj'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(camera: false),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Izaberi iz galerije'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_busy)
                  AiBusy(
                    'Čitam recept sa slike…',
                    onCancel: _photo == null ? null : _cancel,
                    pot: _photo == null,
                  ),
                if (_error case final error?)
                  AiErrorBox(
                    error,
                    actions: [
                      if (photo != null && !_notARecipe)
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
