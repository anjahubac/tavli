import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ai/ai_models.dart';
import '../../ai/recipe_ai.dart';
import '../../domain/recipe.dart';
import '../../providers.dart';
import '../settings/ai_error_text.dart';
import 'ai_preview.dart';
import 'recipe_providers.dart';
import 'recipe_view.dart';

/// Novi recept iz slike: izbor slike → smanjivanje → AI → pregled → čuvanje.
/// Slika se čuva na disku tek kad korisnik sačuva recept.
class FromPhotoScreen extends ConsumerStatefulWidget {
  const FromPhotoScreen({super.key});

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

  Future<void> _pick({required bool camera}) async {
    final Uint8List? picked;
    try {
      picked = await ref.read(photoPickerProvider).pick(camera: camera);
    } on Exception {
      if (!mounted) return;
      setState(() => _error = 'Slika nije učitana.');
      return;
    }
    if (picked == null || !mounted) return;
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
    setState(() {
      _busy = true;
      _error = null;
      _notARecipe = false;
      _result = null;
    });
    try {
      final r = await ref.read(recipeAIProvider).fromImage(AIImage(photo));
      if (!mounted) return;
      setState(() => _result = r.value);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = aiErrorText(e);
        _notARecipe = e is NotARecipeException;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() => setState(() {
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
    final canUseCamera = ref.watch(photoPickerProvider).canUseCamera;
    return Scaffold(
      appBar: AppBar(title: const Text('Recept iz slike')),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      photo,
                      height: 280,
                      fit: BoxFit.contain,
                      semanticLabel: 'Izabrana slika recepta',
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  const Text(
                    'Slikaj recept iz kuvara, rukom pisan recept ili snimak '
                    'ekrana.',
                  ),
                  const SizedBox(height: 16),
                  if (canUseCamera) ...[
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
                if (_busy) const AiBusy('Čitam recept sa slike…'),
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
