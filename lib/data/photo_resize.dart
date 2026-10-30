import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Najduža stranica sačuvane slike: tekst recepta ostaje čitljiv,
/// a fajl je obično ispod 1 MB.
const maxPhotoSide = 1600;

/// Smanjuje sliku i pretvara je u JPEG. Teško je za glavni thread,
/// pa se zove preko `compute`. Baca [FormatException] ako bajtovi
/// nisu slika.
Uint8List downscaleToJpeg(Uint8List bytes, {int quality = 85}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Nije slika');
  final image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  final resized = longest <= maxPhotoSide
      ? image
      : image.width >= image.height
      ? img.copyResize(image, width: maxPhotoSide)
      : img.copyResize(image, height: maxPhotoSide);
  return img.encodeJpg(resized, quality: quality);
}
