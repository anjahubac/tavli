import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Bira sliku recepta sa kamere ili iz galerije.
abstract class PhotoPicker {
  /// Mac nema kameru preko image_picker-a, pa se tada nudi samo galerija.
  bool get canUseCamera;

  /// Bajtovi slike ili null ako je korisnik odustao.
  Future<Uint8List?> pick({required bool camera});
}

class ImagePhotoPicker implements PhotoPicker {
  final _picker = ImagePicker();

  @override
  bool get canUseCamera => _picker.supportsImageSource(ImageSource.camera);

  @override
  Future<Uint8List?> pick({required bool camera}) async {
    // Na telefonu se slika smanjuje već pri izboru; na macOS-u ove opcije
    // ne rade, pa se uvek smanjuje i posle (downscaleToJpeg).
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  }
}
