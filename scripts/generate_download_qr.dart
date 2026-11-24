// Pravi QR kodove za stranicu site/preuzmi/ kao statičke SVG fajlove
// (sajt nema build korak i CSP dozvoljava samo 'self').
// QR vodi na isti URL kao dugme pored njega; posle promene URL-a pokreni:
//
//   dart run scripts/generate_download_qr.dart
import 'dart:io';

import 'package:qr/qr.dart';

/// Stalni linkovi na poslednji GitHub Release (imena fajlova pravi
/// .github/workflows/release.yml).
const downloadQrCodes = {
  'site/preuzmi/qr-android.svg': 'https://github.com/anjahubac/tavli/releases/latest/download/tavli-android.apk',
  'site/preuzmi/qr-stranica.svg': 'https://welcome.tavli.workers.dev/preuzmi/',
};

/// SVG sa jednom putanjom po tamnom modulu i tihom zonom od 4 modula.
String qrSvg(String data, {int quietZone = 4}) {
  final image = QrImage(
    QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
  );
  final count = image.moduleCount;
  final size = count + 2 * quietZone;
  final path = StringBuffer();
  for (var row = 0; row < count; row++) {
    for (var col = 0; col < count; col++) {
      if (image.isDark(row, col)) {
        path.write('M${col + quietZone} ${row + quietZone}h1v1h-1z');
      }
    }
  }
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $size $size" '
      'shape-rendering="crispEdges">'
      '<rect width="$size" height="$size" fill="#FFFFFF"/>'
      '<path fill="#1B1F1C" d="$path"/></svg>\n';
}

void main() {
  for (final MapEntry(key: file, value: url) in downloadQrCodes.entries) {
    File(file).writeAsStringSync(qrSvg(url));
    stdout.writeln('$file → $url');
  }
}
