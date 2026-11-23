import 'package:material_ui/material_ui.dart';

/// Jedna Tavli ikonica: linijski crtež na mreži 24×24, kao na platnu
/// „Tavli: ekrani po uređajima“.
///
/// [shapes] su SVG oblici sa platna, prepisani doslovno: putanja (`d`
/// atribut), `rect x y w h rx` ili `circle cx cy r`. Crta se linijom
/// [strokeWidth] (u jedinicama mreže 24), zaobljenih krajeva i spojeva, u
/// boji okolnog teksta.
@immutable
class TavliIconData {
  const TavliIconData(this.name, this.shapes, {this.strokeWidth = 2});

  /// Ime za testove i galeriju.
  final String name;
  final List<String> shapes;
  final double strokeWidth;

  /// Ista ikonica sa debljom linijom (kvačica u statusu 2,4, u polju 3).
  TavliIconData withStroke(double width) =>
      TavliIconData(name, shapes, strokeWidth: width);

  @override
  bool operator ==(Object other) =>
      other is TavliIconData &&
      other.name == name &&
      other.strokeWidth == strokeWidth;

  @override
  int get hashCode => Object.hash(name, strokeWidth);

  @override
  String toString() => 'TavliIconData($name)';
}

/// Set ikonica sa platna. Nova ikonica se crta u istom stilu (linija 2,
/// zaobljeno, mreža 24) i dodaje ovde, sa ulazom u galeriji.
abstract final class TavliIcons {
  // Navigacija.
  static const plan = TavliIconData('plan', [
    'rect 4 5 16 15 3',
    'M4 10h16M9 3v4M15 3v4',
  ]);
  static const shopping = TavliIconData('shopping', [
    'M4 5h2l2 10h9l2-7H7',
    'circle 9.5 19 1.3',
    'circle 16.5 19 1.3',
  ]);
  static const home = TavliIconData('home', [
    'M4 11l8-7 8 7v8a1 1 0 0 1-1 1h-4v-6h-6v6H5a1 1 0 0 1-1-1z',
  ]);
  static const recipes = TavliIconData('recipes', [
    'M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3z',
    'M5 17a3 3 0 0 1 3-3h11',
  ]);
  static const pantry = TavliIconData('pantry', [
    'M4 8l8-4 8 4v8l-8 4-8-4z',
    'M4 8l8 4 8-4M12 12v8',
  ]);

  // Akcije.
  static const cook = TavliIconData('cook', [
    'M5 10h14v6a4 4 0 0 1-4 4H9a4 4 0 0 1-4-4z',
    'M3 10h18M9 6c0-1 1-1 1-2M14 6c0-1 1-1 1-2',
  ]);
  static const check = TavliIconData('check', ['M5 12l5 5 9-10']);
  static const add = TavliIconData('add', ['M12 5v14M5 12h14']);
  static const search = TavliIconData('search', [
    'circle 11 11 6',
    'M20 20l-4.5-4.5',
  ]);
  static const delete = TavliIconData('delete', [
    'M5 7h14M10 7V5h4v2M7 7l1 13h8l1-13',
  ]);
  static const edit = TavliIconData('edit', [
    'M4 20h4L19 9l-4-4L4 16z',
    'M13 7l4 4',
  ]);
  static const close = TavliIconData('close', ['M6 6l12 12M18 6L6 18']);
  static const remove = TavliIconData('remove', ['M5 12h14']);
  static const filter = TavliIconData('filter', [
    'M4 7h9M17 7h3M4 17h3M11 17h9',
    'circle 15 7 2',
    'circle 9 17 2',
  ]);
  static const checklist = TavliIconData('checklist', [
    'M4 6l1.5 1.5L8 5M4 12l1.5 1.5L8 11M4 18l1.5 1.5L8 17',
    'M11 6h9M11 12h9M11 18h9',
  ]);
  static const timer = TavliIconData('timer', [
    'circle 12 13 7',
    'M12 9v4l2.5 2.5M10 3h4',
  ]);
  static const servings = TavliIconData('servings', [
    'circle 9 9 3',
    'M3.5 19a5.5 5.5 0 0 1 11 0',
    'circle 17 10 2.5',
    'M15.5 15.2a4.5 4.5 0 0 1 5.5 3.8',
  ]);
  static const joinHousehold = TavliIconData('joinHousehold', [
    'circle 9 8 3.5',
    'M3 19a6 6 0 0 1 12 0',
    'M18 8v6M15 11h6',
  ]);
  static const more = TavliIconData('more', [
    'circle 12 5.5 1',
    'circle 12 12 1',
    'circle 12 18.5 1',
  ]);
  static const swap = TavliIconData('swap', [
    'M5 8h14M15 4l4 4-4 4',
    'M19 16H5M9 12l-4 4 4 4',
  ]);
  static const sparkle = TavliIconData('sparkle', [
    'M11 4l1.8 5.2L18 11l-5.2 1.8L11 18l-1.8-5.2L4 11l5.2-1.8z',
    'M18 3v4M16 5h4',
  ]);
  static const replay = TavliIconData('replay', [
    'M5 12a7 7 0 1 0 2-4.9',
    'M5 4v4h4',
  ]);
  static const today = TavliIconData('today', [
    'rect 4 5 16 15 3',
    'M4 10h16',
    'circle 12 15 1.5',
  ]);

  // Strelice.
  static const back = TavliIconData('back', ['M15 5l-7 7 7 7']);
  static const chevronRight = TavliIconData('chevronRight', ['M9 5l7 7-7 7']);
  static const chevronDown = TavliIconData('chevronDown', ['M5 9l7 7 7-7']);
  static const chevronUp = TavliIconData('chevronUp', ['M5 15l7-7 7 7']);
  static const arrowForward = TavliIconData('arrowForward', [
    'M5 12h14M13 6l6 6-6 6',
  ]);
  static const arrowBack = TavliIconData('arrowBack', [
    'M19 12H5M11 6l-6 6 6 6',
  ]);

  // Nalog i podešavanja.
  static const key = TavliIconData('key', [
    'circle 8 15 4',
    'M11 12l8-8M16 7l2 2M14 9l2 2',
  ]);
  static const signOut = TavliIconData('signOut', [
    'M14 4h4a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-4',
    'M10 16l-4-4 4-4M6 12h10',
  ]);
  static const palette = TavliIconData('palette', [
    'M12 4a8 8 0 1 0 0 16c1.1 0 1.6-.8 1.6-1.6 0-1.2-1-1.5-1-2.6 '
        '0-.9.7-1.6 1.6-1.6H16a4 4 0 0 0 4-4c0-3.5-3.6-6.2-8-6.2z',
    'circle 8 11 1',
    'circle 11 7.5 1',
    'circle 15.5 8.5 1',
  ]);
  static const synced = TavliIconData('synced', [
    'M7 18a4 4 0 0 1-.6-8A5.5 5.5 0 0 1 17 9a4 4 0 0 1 0 9z',
    'M9.5 13.5l2 2 3.5-4',
  ]);
  static const info = TavliIconData('info', [
    'circle 12 12 8.5',
    'M12 11v5M12 8h.01',
  ]);
  static const show = TavliIconData('show', [
    'M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z',
    'circle 12 12 3',
  ]);
  static const lightMode = TavliIconData('lightMode', [
    'circle 12 12 4',
    'M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4'
        'M5.6 18.4L7 17M17 7l1.4-1.4',
  ]);
  static const darkMode = TavliIconData('darkMode', [
    'M19 14.5A7.5 7.5 0 0 1 9.5 5 7.5 7.5 0 1 0 19 14.5z',
  ]);
  static const systemMode = TavliIconData('systemMode', [
    'circle 12 12 8',
    'M12 4v16',
  ]);
  static const question = TavliIconData('question', [
    'M5 5h14a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-8l-4 3v-3H5a2 2 0 0 1-2-2V7'
        'a2 2 0 0 1 2-2z',
    'M10 9.5a2 2 0 1 1 2.8 1.8c-.5.3-.8.7-.8 1.2M12 14.5v.01',
  ]);

  // Ukusi i alergeni.
  static const like = TavliIconData('like', [
    'M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z',
  ]);
  static const dislike = TavliIconData('dislike', [
    'circle 12 12 8',
    'M6.5 6.5l11 11',
  ]);
  static const lock = TavliIconData('lock', [
    'rect 5 11 14 10 2',
    'M8 11V8a4 4 0 0 1 8 0v3',
  ]);
  static const star = TavliIconData('star', [
    'M12 3.5l2.6 5.5 6 .8-4.4 4.2 1.1 6-5.3-2.9-5.3 2.9 1.1-6L3.4 9.8l6-.8z',
  ]);
  static const dish = TavliIconData('dish', [
    'M5 10h14v6a4 4 0 0 1-4 4H9a4 4 0 0 1-4-4z',
    'M3 10h18M9 6c0-1 1-1 1-2M14 6c0-1 1-1 1-2',
  ]);
  static const allergenGluten = TavliIconData('allergenGluten', [
    'M12 21V9M12 9c-2.2-.8-3.2-2.8-3-5 2.2.4 3.2 2.4 3 5zM12 9c2.2-.8 3.2-2.8'
        ' 3-5-2.2.4-3.2 2.4-3 5zM12 14c-2.2-.8-3.4-2.6-3.4-4.6 2.2.3 3.4 2.3'
        ' 3.4 4.6zM12 14c2.2-.8 3.4-2.6 3.4-4.6-2.2.3-3.4 2.3-3.4 4.6zM12 19'
        'c-2.2-.8-3.4-2.6-3.4-4.6 2.2.3 3.4 2.3 3.4 4.6zM12 19c2.2-.8 3.4-2.6'
        ' 3.4-4.6-2.2.3-3.4 2.3-3.4 4.6z',
  ]);
  static const allergenMilk = TavliIconData('allergenMilk', [
    'M8 3h8v3l2 3v11a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V9l2-3zM6 10h12',
  ]);
  static const allergenEggs = TavliIconData('allergenEggs', [
    'M12 3c3.6 0 6.5 5.6 6.5 10a6.5 6.5 0 0 1-13 0C5.5 8.6 8.4 3 12 3z',
  ]);
  static const allergenNuts = TavliIconData('allergenNuts', [
    'M4.5 10a7.5 3.5 0 0 1 15 0zM6 10c0 5.5 2.8 9.5 6 10.5 3.2-1 6-5 6-10.5'
        'M12 6.5V3.5',
  ]);
  static const allergenPeanuts = TavliIconData('allergenPeanuts', [
    'M9.5 3.5a4 4 0 0 1 4 4c0 1.1.5 1.7 1.6 2.2a4.6 4.6 0 1 1-6.3 5.8'
        'c-.3-1-.8-1.5-1.9-1.8A4 4 0 0 1 9.5 3.5z',
  ]);
  static const allergenFish = TavliIconData('allergenFish', [
    'M3 12c3-5 9-6.5 13-3l5-3v12l-5-3c-4 3.5-10 2-13-3zM8.5 11v.5',
  ]);
  static const allergenCrustaceans = TavliIconData('allergenCrustaceans', [
    'M5 7c4.5-3 13-2 14 5 .5 4-2.5 7-6.5 7H9.5M9.5 19l-2.5 2M9.5 19L7 17.5'
        'M9 11.5c2 0 4 1 5 3M5 7L2.5 4.5M5 7L3 9.5',
  ]);
  static const allergenMolluscs = TavliIconData('allergenMolluscs', [
    'M3 19h15a3 3 0 0 0 3-3V9M3 19a7.5 7.5 0 1 1 12-6 3.5 3.5 0 1 1-7 1.5',
  ]);
  static const allergenSoy = TavliIconData('allergenSoy', [
    'M5 19C4 12 9 5 19 5c0 9-6.5 15-14 14zM8 16l8-8',
  ]);
  static const allergenSesame = TavliIconData('allergenSesame', [
    'M8 4.5c1.6 1 1.6 4 0 5.2-1.6-1.2-1.6-4.2 0-5.2zM16 6.5c1.6 1 1.6 4 0'
        ' 5.2-1.6-1.2-1.6-4.2 0-5.2zM11 13.5c1.6 1 1.6 4 0 5.2-1.6-1.2-1.6-4.2'
        ' 0-5.2z',
  ]);
  static const allergenCelery = TavliIconData('allergenCelery', [
    'M9 21V11M12 21V10M15 21V11M9 11c-2-2-2-5 0-6.5 1.2 2 1.2 4.5 0 6.5z'
        'M15 11c2-2 2-5 0-6.5-1.2 2-1.2 4.5 0 6.5zM12 10c-1.6-2.2-1.6-5 0-7'
        ' 1.6 2 1.6 4.8 0 7z',
  ]);
  static const allergenMustard = TavliIconData('allergenMustard', [
    'M8.5 3h7v3h-7zM7 6h10l1 3v10a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V9zM6 12.5h12',
  ]);
  static const allergenSulphites = TavliIconData('allergenSulphites', [
    'M7.5 3h9l-.6 6.5a3.9 3.9 0 0 1-7.8 0zM12 13.5V20M8.5 20.5h7M8 7.5h8',
  ]);
  static const allergenLupin = TavliIconData('allergenLupin', [
    'M12 21V8.5M12 3.5a1.8 1.8 0 1 1 0 3.6 1.8 1.8 0 1 1 0-3.6z'
        'M8.5 9.5c.5 1.5 2 2 3.5 1.5M15.5 9.5c-.5 1.5-2 2-3.5 1.5'
        'M8.5 13.5c.5 1.5 2 2 3.5 1.5M15.5 13.5c-.5 1.5-2 2-3.5 1.5'
        'M8.5 17.5c.5 1.5 2 2 3.5 1.5M15.5 17.5c-.5 1.5-2 2-3.5 1.5',
  ]);

  /// Svi, za galeriju i testove.
  static const all = [
    plan,
    shopping,
    home,
    recipes,
    pantry,
    cook,
    check,
    add,
    search,
    delete,
    edit,
    close,
    remove,
    filter,
    checklist,
    timer,
    servings,
    joinHousehold,
    more,
    swap,
    sparkle,
    replay,
    today,
    back,
    chevronRight,
    chevronDown,
    chevronUp,
    arrowForward,
    arrowBack,
    key,
    signOut,
    palette,
    synced,
    info,
    show,
    lightMode,
    darkMode,
    systemMode,
    question,
    like,
    dislike,
    lock,
    star,
    dish,
    allergenGluten,
    allergenMilk,
    allergenEggs,
    allergenNuts,
    allergenPeanuts,
    allergenFish,
    allergenCrustaceans,
    allergenMolluscs,
    allergenSoy,
    allergenSesame,
    allergenCelery,
    allergenMustard,
    allergenSulphites,
    allergenLupin,
  ];
}

/// Crta [TavliIconData] u veličini [size] (podrazumevano iz `IconTheme`),
/// bojom [color] ili bojom iz `IconTheme`. Bez [semanticLabel] je
/// ukras i čitač ekrana ga preskače.
class TavliIcon extends StatelessWidget {
  const TavliIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.filled = false,
  });

  final TavliIconData icon;

  /// Popunjen oblik (zvezdica ocene, srce omiljenog), uz liniju.
  final bool filled;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final side = size ?? theme.size ?? 24;
    final paint =
        color ?? theme.color ?? DefaultTextStyle.of(context).style.color!;
    // Center: kad roditelj nametne veću minimalnu veličinu (npr. lupa u polju
    // od 48), crtež ostaje kvadrat u sredini umesto u gornjem levom uglu.
    final drawing = Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox.square(
        dimension: side,
        child: CustomPaint(painter: _IconPainter(icon, paint, filled)),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: drawing);
    return Semantics(label: semanticLabel, image: true, child: drawing);
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color, this.filled);

  final TavliIconData icon;
  final Color color;
  final bool filled;

  static final _cache = <String, Path>{};

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = icon.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final shape in icon.shapes) {
      final path = _cache.putIfAbsent(shape, () => parseIconShape(shape));
      if (filled) canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color || old.filled != filled;
}

/// Pretvara jedan oblik iz [TavliIconData.shapes] u [Path]: `rect x y w h
/// rx`, `circle cx cy r` ili SVG putanju (M L H V C S Q A Z, velika i mala
/// slova).
@visibleForTesting
Path parseIconShape(String shape) {
  final parts = shape.trim().split(RegExp(r'\s+'));
  if (parts.first == 'rect') {
    final v = parts.skip(1).map(double.parse).toList();
    return Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(v[0], v[1], v[2], v[3]),
        Radius.circular(v.length > 4 ? v[4] : 0),
      ),
    );
  }
  if (parts.first == 'circle') {
    final v = parts.skip(1).map(double.parse).toList();
    return Path()
      ..addOval(Rect.fromCircle(center: Offset(v[0], v[1]), radius: v[2]));
  }
  return _SvgPath(shape).parse();
}

class _SvgPath {
  _SvgPath(this.source);

  final String source;
  final _tokens = <String>[];
  var _i = 0;

  static final _token = RegExp(
    r'[MmLlHhVvCcSsQqAaZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?',
  );

  Path parse() {
    _tokens.addAll(_token.allMatches(source).map((m) => m.group(0)!));
    final path = Path();
    var cur = Offset.zero;
    var start = Offset.zero;
    Offset? lastControl;
    String? cmd;
    while (_i < _tokens.length) {
      if (_isCommand(_tokens[_i])) cmd = _tokens[_i++];
      final c = cmd!;
      final rel = c == c.toLowerCase();
      final base = rel ? cur : Offset.zero;
      switch (c.toUpperCase()) {
        case 'M':
          cur = base + _point();
          start = cur;
          path.moveTo(cur.dx, cur.dy);
          // Posle M brojevi se nastavljaju kao L.
          cmd = rel ? 'l' : 'L';
          lastControl = null;
        case 'L':
          cur = base + _point();
          path.lineTo(cur.dx, cur.dy);
          lastControl = null;
        case 'H':
          cur = Offset((rel ? cur.dx : 0) + _number(), cur.dy);
          path.lineTo(cur.dx, cur.dy);
          lastControl = null;
        case 'V':
          cur = Offset(cur.dx, (rel ? cur.dy : 0) + _number());
          path.lineTo(cur.dx, cur.dy);
          lastControl = null;
        case 'C':
          final c1 = base + _point();
          final c2 = base + _point();
          final end = base + _point();
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          lastControl = c2;
          cur = end;
        case 'S':
          final c1 = lastControl == null ? cur : cur * 2 - lastControl;
          final c2 = base + _point();
          final end = base + _point();
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          lastControl = c2;
          cur = end;
        case 'Q':
          final c1 = base + _point();
          final end = base + _point();
          path.quadraticBezierTo(c1.dx, c1.dy, end.dx, end.dy);
          lastControl = null;
          cur = end;
        case 'A':
          final rx = _number();
          final ry = _number();
          final rotation = _number();
          final large = _flag();
          final sweep = _flag();
          final end = base + _point();
          path.arcToPoint(
            end,
            radius: Radius.elliptical(rx, ry),
            rotation: rotation,
            largeArc: large,
            clockwise: sweep,
          );
          cur = end;
          lastControl = null;
        case 'Z':
          path.close();
          cur = start;
          lastControl = null;
          cmd = null;
      }
      if (cmd == null && _i < _tokens.length && !_isCommand(_tokens[_i])) {
        throw FormatException('Neispravna putanja ikonice', source);
      }
    }
    return path;
  }

  bool _isCommand(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);

  double _number() {
    if (_i >= _tokens.length || _isCommand(_tokens[_i])) {
      throw FormatException('Neispravna putanja ikonice', source);
    }
    return double.parse(_tokens[_i++]);
  }

  // Zastavice luka mogu biti spojene sa brojem posle njih („0 1 1“ ili
  // „011“); na platnu su uvek odvojene razmakom.
  bool _flag() => _number() != 0;

  Offset _point() => Offset(_number(), _number());
}
