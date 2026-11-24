import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Mesto za crtež praznog stanja. Pamti prirodnu visinu crteža, da
/// `TavliEmptyArea` zna koliko sme da ga smanji.
class EmptyArtSlot extends SingleChildRenderObjectWidget {
  const EmptyArtSlot({super.key, required super.child});

  /// Visina crteža kada nema mesta (krupan tekst, nizak ekran).
  static const double smallHeight = 88;

  @override
  RenderEmptyArtSlot createRenderObject(BuildContext context) =>
      RenderEmptyArtSlot();
}

class RenderEmptyArtSlot extends RenderProxyBox {
  double _naturalHeight = 0;

  /// Koliko se crtež može smanjiti (0 kada je već mali).
  double get shrinkable => _naturalHeight > EmptyArtSlot.smallHeight
      ? _naturalHeight - EmptyArtSlot.smallHeight
      : 0;

  @override
  void performLayout() {
    super.performLayout();
    if (!constraints.hasBoundedHeight) _naturalHeight = size.height;
  }
}
