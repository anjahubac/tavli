import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Korisnik nije dozvolio pristup kameri ili galeriji.
class PhotoAccessDeniedException implements Exception {
  const PhotoAccessDeniedException();
}

/// Bira sliku recepta sa kamere ili iz galerije (na računaru izbor datoteke).
abstract class PhotoPicker {
  /// Da li adapter podržava kameru; ekran je nudi samo na telefonu.
  bool get canUseCamera;

  /// Bajtovi slike ili null ako je korisnik odustao.
  /// Baca [PhotoAccessDeniedException] kad pristup nije dozvoljen.
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
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      // image_picker: camera_access_denied / photo_access_denied.
      if (e.code.endsWith('_access_denied')) {
        throw const PhotoAccessDeniedException();
      }
      rethrow;
    }
    return file?.readAsBytes();
  }
}
