import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import 'empty_art_slot.dart';
import 'tavli_states.dart';

/// Visina prostora za sadržaj tabova (bez bočne ili donje navigacije).
/// Ljuska aplikacije je postavlja jednom za sve tabove, pa [TavliEmptyArea]
/// zna gde je vrh taba i crtež praznog stanja stavlja na istu visinu na
/// svakom tabu, bez obzira na zaglavlje iznad.
class TavliEmptyAreaScope extends InheritedWidget {
  const TavliEmptyAreaScope({
    super.key,
    required this.height,
    this.anchor = TavliEmptyArea.anchor,
    this.inset = 0,
    required super.child,
  });

  final double height;

  /// Udeo visine (ispod [inset]) na kom počinje sadržaj. Na telefonu je
  /// niže nego na računaru, da stane i ispod zaglavlja Početne.
  final double anchor;

  /// Deo visine na vrhu koji zauzima sistem (npr. statusna traka).
  final double inset;

  static TavliEmptyAreaScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TavliEmptyAreaScope>();

  @override
  bool updateShouldNotify(TavliEmptyAreaScope old) =>
      old.height != height || old.anchor != anchor || old.inset != inset;
}

/// Prostor praznog stanja (npr. [TavliEmptyState]) do dna taba: vrh
/// sadržaja je uvek na istom delu visine taba ([anchor]), pa crtež ne
/// „šeta“ od taba do taba zbog zaglavlja ili dužine teksta i dugmadi.
///
/// Kada sadržaj ne staje ispod te visine (nizak prozor, krupan tekst),
/// crtež se smanji, pa se sadržaj podigne, ali nikad preko [header]-a; kada
/// ne staje ni tako, sve se pomera (skroluje).
class TavliEmptyArea extends StatelessWidget {
  const TavliEmptyArea({
    super.key,
    required this.child,
    this.header,
    this.padding = EdgeInsets.zero,
  });

  /// Udeo visine taba (od vrha taba) na kom počinje sadržaj.
  static const double anchor = 0.27;

  /// Niže na telefonu: ispod zaglavlja Početne, pa je isto na svim tabovima.
  static const double phoneAnchor = 1 / 3;

  /// Najmanja visina taba za [phoneAnchor]; na nižem ekranu dugmad ne bi
  /// stala, pa važi [anchor], a Početna počinje odmah ispod zaglavlja.
  static const double phoneMinHeight = 640;

  final Widget child;

  /// Zaglavlje koje se pomera zajedno sa sadržajem (npr. „Danas“).
  final Widget? header;

  /// Razmak oko zaglavlja i sadržaja; dno prostora ostaje dno taba.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tab = TavliEmptyAreaScope.maybeOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final height = box.maxHeight;
        // Prostor ide do dna taba, pa mu je vrh (tab - height) ispod vrha
        // taba. Bez ljuske (npr. testovi) računa se od vrha ovog prostora.
        final tabHeight = math.max(tab?.height ?? 0, height);
        final inset = tab?.inset ?? 0;
        final anchored = inset + (tabHeight - inset) * (tab?.anchor ?? anchor);
        final top = anchored - (tabHeight - height) - padding.top;
        return SingleChildScrollView(
          padding: padding,
          child: _EmptyAreaLayout(
            minHeight: math.max(0, height - padding.vertical),
            top: top,
            children: [?header, child],
          ),
        );
      },
    );
  }
}

class _EmptyAreaLayout extends MultiChildRenderObjectWidget {
  const _EmptyAreaLayout({
    required this.minHeight,
    required this.top,
    required super.children,
  });

  final double minHeight;
  final double top;

  @override
  _RenderEmptyArea createRenderObject(BuildContext context) =>
      _RenderEmptyArea(minHeight: minHeight, top: top);

  @override
  void updateRenderObject(BuildContext context, _RenderEmptyArea render) {
    render
      ..minHeight = minHeight
      ..top = top;
  }
}

class _EmptyAreaParentData extends ContainerBoxParentData<RenderBox> {}

/// Poslednje dete je sadržaj, a prethodno (ako postoji) zaglavlje na vrhu.
class _RenderEmptyArea extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EmptyAreaParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EmptyAreaParentData> {
  _RenderEmptyArea({required this._minHeight, required this._top});

  double _minHeight;
  set minHeight(double value) {
    if (value == _minHeight) return;
    _minHeight = value;
    markNeedsLayout();
  }

  double _top;
  set top(double value) {
    if (value == _top) return;
    _top = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EmptyAreaParentData) {
      child.parentData = _EmptyAreaParentData();
    }
  }

  /// Koliko se crtež u sadržaju može smanjiti.
  static double _shrinkable(RenderObject node) {
    if (node is RenderEmptyArtSlot) return node.shrinkable;
    var total = 0.0;
    node.visitChildren((child) => total += _shrinkable(child));
    return total;
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final inner = BoxConstraints.tightFor(width: width);
    final body = lastChild!;
    final header = childBefore(body);
    var minTop = 0.0;
    if (header != null) {
      header.layout(inner, parentUsesSize: true);
      (header.parentData! as _EmptyAreaParentData).offset = Offset.zero;
      minTop = header.size.height;
    }
    body.layout(inner, parentUsesSize: true);
    // Na zadatoj visini, ali ispod zaglavlja.
    final anchored = math.max(minTop, _top);
    if (anchored + body.size.height > _minHeight) {
      // Ne staje: prvo se smanji crtež (do najmanje visine), pa vrh ostaje
      // isti.
      final smallest = body.size.height - _shrinkable(body);
      body.layout(
        inner.copyWith(
          minHeight: 0,
          maxHeight: math.max(_minHeight - anchored, smallest),
        ),
        parentUsesSize: true,
      );
    }
    // Ako ni tako ne staje, podiže se, ali ne preko zaglavlja.
    final y = math.max(
      minTop,
      math.min(anchored, _minHeight - body.size.height),
    );
    (body.parentData! as _EmptyAreaParentData).offset = Offset(0, y);
    size = constraints.constrain(
      Size(width, math.max(_minHeight, y + body.size.height)),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
