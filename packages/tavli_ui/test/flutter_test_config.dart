import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Testovi paketa crtaju pravi font (Plus Jakarta Sans iz paketa) i
/// Material ikone, da slike izgleda pokažu tekst kakav korisnik vidi.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final jakarta = FontLoader('packages/tavli_ui/PlusJakartaSans');
  for (final weight in const [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
  ]) {
    jakarta.addFont(_file('assets/fonts/PlusJakartaSans-$weight.ttf'));
  }
  await jakarta.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final icons = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(_file(icons.path))).load();
    }
  }
  await testMain();
}

Future<ByteData> _file(String path) async =>
    ByteData.sublistView(await File(path).readAsBytes());
