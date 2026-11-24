import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Platforma za koju komponenta bira izgled i ponašanje.
///
/// Čita se iz [ThemeData.platform], pa galerija i testovi mogu da je
/// zadaju bez pravog uređaja. Linux se ponaša kao Windows, Fuchsia kao
/// Android.
enum TavliPlatform {
  android,
  ios,
  macos,
  windows;

  static TavliPlatform of(BuildContext context) =>
      fromTarget(Theme.of(context).platform);

  static TavliPlatform fromTarget(TargetPlatform platform) =>
      switch (platform) {
        TargetPlatform.android || TargetPlatform.fuchsia => android,
        TargetPlatform.iOS => ios,
        TargetPlatform.macOS => macos,
        TargetPlatform.windows || TargetPlatform.linux => windows,
      };

  /// Računar: miš, tastatura i šira mreža.
  bool get isDesktop => this == macos || this == windows;

  /// Apple: iOS i macOS.
  bool get isApple => this == ios || this == macos;

  /// Lagan sistemski otkucaj pri izboru (štikliranje, segment, oznaka),
  /// samo na iOS-u; ostale platforme ga nemaju u obrascu.
  static void selectionFeedback(BuildContext context) {
    if (of(context) == ios) unawaited(HapticFeedback.selectionClick());
  }
}
