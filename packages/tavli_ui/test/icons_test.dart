import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/src/icons/tavli_icons.dart';

void main() {
  test('svaka ikonica se čita i ostaje u mreži 24', () {
    final names = <String>{};
    for (final icon in TavliIcons.all) {
      expect(names.add(icon.name), isTrue, reason: 'ime ${icon.name}');
      expect(icon.strokeWidth, 2);
      for (final shape in icon.shapes) {
        // Tačke na samoj liniji (ne kontrolne tačke krivih).
        for (final metric in parseIconShape(shape).computeMetrics()) {
          for (var d = 0.0; d <= metric.length; d += 0.25) {
            final p = metric.getTangentForOffset(d)!.position;
            expect(p.dx, inInclusiveRange(0, 24), reason: shape);
            expect(p.dy, inInclusiveRange(0, 24), reason: shape);
          }
        }
      }
    }
  });

  test('putanja: relativne komande, luk, H/V i zatvaranje', () {
    // Kućica sa platna: počinje u (4, 11) i ide do vrha krova (12, 4).
    final home = parseIconShape(TavliIcons.home.shapes.single).getBounds();
    expect(home.left, closeTo(4, 0.01));
    expect(home.top, closeTo(4, 0.01));
    expect(home.right, closeTo(20, 0.01));
    expect(home.bottom, closeTo(20, 0.01));

    final rect = parseIconShape('rect 4 5 16 15 3').getBounds();
    expect(rect, const Rect.fromLTWH(4, 5, 16, 15));
    final circle = parseIconShape('circle 11 11 6').getBounds();
    expect(circle, Rect.fromCircle(center: const Offset(11, 11), radius: 6));
  });

  test('neispravna putanja javlja grešku', () {
    expect(() => parseIconShape('M4'), throwsFormatException);
  });

  testWidgets('ikonica uzima veličinu i boju iz IconTheme, ukras je skriven', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: IconTheme(
          data: IconThemeData(size: 18, color: Color(0xFF3D7A57)),
          child: Center(child: TavliIcon(TavliIcons.cook)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(TavliIcon)), const Size(18, 18));
    expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: TavliIcon(
            TavliIcons.search,
            size: 22,
            color: Color(0xFF000000),
            semanticLabel: 'Pretraga',
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(TavliIcon)), const Size(22, 22));
    expect(find.bySemanticsLabel('Pretraga'), findsOneWidget);
    semantics.dispose();
  });

  test('deblja kvačica je ista ikonica sa drugom linijom', () {
    final bold = TavliIcons.check.withStroke(2.4);
    expect(bold.strokeWidth, 2.4);
    expect(bold.shapes, TavliIcons.check.shapes);
    expect(bold == TavliIcons.check, isFalse);
  });
}
