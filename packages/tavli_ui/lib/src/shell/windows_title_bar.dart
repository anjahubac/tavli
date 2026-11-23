import 'package:material_ui/material_ui.dart';

import '../theme/tavli_colors.dart';
import 'shell_parts.dart';
import 'tavli_menu_bar.dart';
import 'tavli_window_frame.dart';

/// Radnje prozora na Windows-u. Aplikacija ih vezuje za pravi prozor;
/// galerija i testovi ostavljaju `null`, pa dugmad ne rade ništa.
@immutable
class TavliWindowControls {
  const TavliWindowControls({
    this.maximized = false,
    this.onMinimize,
    this.onToggleMaximize,
    this.onClose,
    this.onStartDrag,
    this.onStartResizeTop,
    this.onShowSystemMenu,
  });

  /// Prozor je uvećan preko celog ekrana: srednje dugme vraća veličinu, a
  /// gornja ivica ne menja visinu.
  final bool maximized;
  final VoidCallback? onMinimize;
  final VoidCallback? onToggleMaximize;
  final VoidCallback? onClose;

  /// Pritisak na prazan deo trake: prozor prati miš dok se ne pusti.
  final VoidCallback? onStartDrag;

  /// Pritisak na gornju ivicu: menja visinu prozora odozgo.
  final VoidCallback? onStartResizeTop;

  /// Desni klik na traku: sistemski meni prozora.
  final VoidCallback? onShowSystemMenu;
}

/// Naslovna traka prozora na Windows-u, po platnu: visina 40, naziv 13/700,
/// stavke menija 13 sa razmakom 10, dugmad 46 x 40.
class WindowsTitleBar extends StatelessWidget {
  const WindowsTitleBar({
    super.key,
    required this.title,
    required this.controls,
  });

  final String title;
  final TavliWindowControls controls;

  /// Debljina gornje ivice koja menja visinu prozora.
  static const _resizeEdge = 4.0;

  /// Širina dugmeta prozora.
  static const _captionWidth = 46.0;

  /// Najmanji prazan deo trake za pomeranje prozora.
  static const _minDrag = 46.0;

  @override
  Widget build(BuildContext context) {
    final menus = TavliMenuBar.windowsMenusOf(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final titleStyle = Theme.of(context).textTheme.labelMedium
        ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: onSurface);

    // Prazan deo trake: pomeranje, dvoklik i sistemski meni.
    Widget drag(Widget child) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: controls.onStartDrag == null
          ? null
          : (_) => controls.onStartDrag!(),
      onDoubleTap: controls.onToggleMaximize,
      onSecondaryTap: controls.onShowSystemMenu,
      child: child,
    );

    // Naziv i meni zauzimaju koliko im treba, najviše do dugmadi i
    // najmanjeg dela za pomeranje; ostatak trake je za pomeranje, pa su
    // dugmad uvek uz desnu ivicu.
    final bar = LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (constraints.maxWidth - 3 * _captionWidth - _minDrag)
                  .clamp(0.0, double.infinity),
            ),
            child: UnconstrainedBox(
              constrainedAxis: Axis.vertical,
              alignment: AlignmentDirectional.centerStart,
              clipBehavior: Clip.hardEdge,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  drag(
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Center(
                        child: Text(title, maxLines: 1, style: titleStyle),
                      ),
                    ),
                  ),
                  if (menus.isNotEmpty) _WindowsMenus(groups: menus),
                ],
              ),
            ),
          ),
          Expanded(child: drag(const SizedBox.expand())),
          _CaptionButton(
            kind: _Caption.minimize,
            label: 'Umanji',
            onPressed: controls.onMinimize,
          ),
          _CaptionButton(
            kind: controls.maximized ? _Caption.restore : _Caption.maximize,
            label: controls.maximized ? 'Vrati' : 'Uvećaj',
            onPressed: controls.onToggleMaximize,
          ),
          _CaptionButton(
            kind: _Caption.close,
            label: 'Zatvori',
            onPressed: controls.onClose,
          ),
        ],
      ),
    );

    final resize = controls.onStartResizeTop;
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        height: TavliWindowFrame.windowsTitleBarHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: shellSurface(context),
            border: Border(
              bottom: BorderSide(color: TavliColors.of(context).line),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              bar,
              if (resize != null && !controls.maximized)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _resizeEdge,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => resize(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Meni u prozoru. Pre izbora stavke vraća fokus polju u kome je korisnik
/// bio, da Uređivanje radi na tom polju.
class _WindowsMenus extends StatefulWidget {
  const _WindowsMenus({required this.groups});

  final List<TavliMenuGroup> groups;

  @override
  State<_WindowsMenus> createState() => _WindowsMenusState();
}

class _WindowsMenusState extends State<_WindowsMenus> {
  FocusNode? _before;

  void _remember() {
    final focus = FocusManager.instance.primaryFocus;
    final menuContext = focus?.context;
    // Fokus već u meniju (prelazak sa jednog menija na drugi) se ne pamti.
    if (menuContext != null &&
        menuContext.findAncestorStateOfType<_WindowsMenusState>() == this) {
      return;
    }
    _before = focus;
  }

  void _run(TavliMenuCommand command) {
    final before = _before;
    _before = null;
    if (before != null && before.context != null) before.requestFocus();
    // Posle zatvaranja menija i vraćanja fokusa.
    WidgetsBinding.instance.addPostFrameCallback((_) => command.onSelected());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final x = TavliColors.of(context);
    final textStyle = theme.textTheme.labelMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: theme.colorScheme.onSurface,
    );
    final hover = WidgetStateProperty.resolveWith<Color?>(
      (states) =>
          states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.pressed)
          ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
          : null,
    );
    final barItem = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(0, TavliWindowFrame.windowsTitleBarHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 10),
      ),
      textStyle: WidgetStatePropertyAll(textStyle),
      foregroundColor: WidgetStatePropertyAll(theme.colorScheme.onSurface),
      backgroundColor: hover,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
    );
    final item = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(220, 32)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      textStyle: WidgetStatePropertyAll(textStyle),
      foregroundColor: WidgetStatePropertyAll(theme.colorScheme.onSurface),
      backgroundColor: hover,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
    final popup = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(4),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: x.line),
        ),
      ),
    );

    List<Widget> entries(List<TavliMenuCommand?> items) => [
      for (final c in items)
        if (c == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 1, thickness: 1, color: x.line),
          )
        else
          MenuItemButton(
            style: item,
            shortcut: c.shortcut,
            onPressed: () => _run(c),
            child: Text(c.label),
          ),
    ];

    return MenuBar(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
      ),
      children: [
        for (final g in widget.groups)
          SubmenuButton(
            style: barItem,
            menuStyle: popup,
            onOpen: _remember,
            menuChildren: entries(g.items),
            child: Text(g.label),
          ),
      ],
    );
  }
}

enum _Caption { minimize, maximize, restore, close }

/// Dugme prozora 46 x 40 sa tankim znakom 10 px; zatvaranje pod mišem je
/// crveno, kao sistemsko.
class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.kind,
    required this.label,
    required this.onPressed,
  });

  final _Caption kind;
  final String label;
  final VoidCallback? onPressed;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovered = false;
  bool _pressed = false;

  /// Crvena sistemskog dugmeta za zatvaranje na Windows-u.
  static const _closeRed = Color(0xFFC42B1C);

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final close = widget.kind == _Caption.close;
    final active = _hovered || _pressed;
    final background = !active
        ? Colors.transparent
        : close
        ? _closeRed.withValues(alpha: _pressed ? 0.85 : 1)
        : onSurface.withValues(alpha: _pressed ? 0.12 : 0.08);
    final glyph = close && active ? Colors.white : onSurface;
    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 600),
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: widget.label,
        onTap: widget.onPressed,
        excludeSemantics: true,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: () {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            },
            // Dugmad ne pomeraju prozor kao ostatak trake.
            onPanStart: (_) {},
            child: ColoredBox(
              color: background,
              child: SizedBox(
                width: WindowsTitleBar._captionWidth,
                height: TavliWindowFrame.windowsTitleBarHeight,
                child: Center(
                  child: CustomPaint(
                    size: const Size.square(10),
                    painter: _CaptionGlyph(widget.kind, glyph),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptionGlyph extends CustomPainter {
  _CaptionGlyph(this.kind, this.color);

  final _Caption kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final w = size.width;
    switch (kind) {
      case _Caption.minimize:
        canvas.drawLine(Offset(0, w / 2), Offset(w, w / 2), paint);
      case _Caption.maximize:
        canvas.drawRect(Rect.fromLTWH(0.5, 0.5, w - 1, w - 1), paint);
      case _Caption.restore:
        canvas
          ..drawRect(Rect.fromLTWH(0.5, 2.5, w - 3, w - 3), paint)
          ..drawPath(
            Path()
              ..moveTo(2.5, 2.5)
              ..lineTo(2.5, 0.5)
              ..lineTo(w - 0.5, 0.5)
              ..lineTo(w - 0.5, w - 2.5)
              ..lineTo(w - 2.5, w - 2.5),
            paint,
          );
      case _Caption.close:
        canvas
          ..drawLine(Offset.zero, Offset(w, w), paint)
          ..drawLine(Offset(w, 0), Offset(0, w), paint);
    }
  }

  @override
  bool shouldRepaint(_CaptionGlyph old) =>
      old.kind != kind || old.color != color;
}
