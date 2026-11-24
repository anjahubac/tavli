import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

/// Vrh praznog stanja je na istoj visini bez obzira na dužinu sadržaja,
/// nikad preko zaglavlja, a sve se pomera kada ne staje.
const _scope = 600.0;

const _body = ValueKey('sadržaj');
const _header = ValueKey('zaglavlje');
const _art = ValueKey('crtež');
const _last = ValueKey('poslednje dugme');

enum _Content { noAction, oneButton, twoButtons }

Widget _state(_Content content) => TavliEmptyState(
  key: _body,
  icon: Icons.event,
  title: 'Još nemaš plan',
  message: 'Napravi plan i ovde ćeš videti šta se kuva.',
  action: switch (content) {
    _Content.noAction => null,
    _Content.oneButton => TavliButton.primary(
      key: _last,
      label: 'Napravi plan',
      onPressed: () {},
    ),
    _Content.twoButtons => Column(
      mainAxisSize: MainAxisSize.min,
      spacing: TavliSpacing.small,
      children: [
        TavliButton.primary(label: 'Napravi plan', onPressed: () {}),
        TavliButton.primary(
          key: _last,
          label: 'Dodaj recept',
          onPressed: () {},
        ),
      ],
    ),
  },
);

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required double scale,
  required Widget child,
  double header = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Nov prostor svaki put, da skrol iz prethodnog merenja ne ostane.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTavliTheme(TavliMotif.bosiljak, Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: TavliEmptyAreaScope(
            height: _scope,
            child: TavliEmptyArea(
              header: header == 0
                  ? null
                  : SizedBox(key: _header, height: header),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

/// Visina na kojoj sadržaj treba da počne kada staje.
double _anchored(Size size) {
  final tab = math.max(_scope, size.height);
  return tab * TavliEmptyArea.anchor - (tab - size.height);
}

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

void main() {
  const sizes = [Size(320, 500), Size(390, 844), Size(1200, 760)];
  const headers = [0.0, 96.0, 320.0];

  for (final size in sizes) {
    for (final scale in [1.0, 2.0]) {
      final at = '${size.width.toInt()}x${size.height.toInt()}, tekst $scale';

      for (final header in headers) {
        testWidgets('$at, zaglavlje $header: vrh i skrol', (tester) async {
          // Sadržaj bez zaglavlja ne sme ispod najniže dozvoljene visine.
          final minTop = header;
          final fittingTops = <_Content, double>{};
          for (final content in _Content.values) {
            await _pump(
              tester,
              size: size,
              scale: scale,
              header: header,
              child: _state(content),
            );
            final top = tester.getTopLeft(find.byKey(_body)).dy;
            final height = tester.getSize(find.byKey(_body)).height;
            final anchor = math.max(minTop, _anchored(size));

            expect(top, greaterThanOrEqualTo(minTop), reason: '$content');
            if (header > 0) {
              final bottom = tester.getBottomLeft(find.byKey(_header)).dy;
              expect(top, greaterThanOrEqualTo(bottom), reason: '$content');
            }

            final max = _position(tester).maxScrollExtent;
            if (anchor + height <= size.height) {
              fittingTops[content] = top;
              expect(top, moreOrLessEquals(anchor), reason: '$content');
              expect(max, 0, reason: '$content staje, pa nema skrola');
            } else if (minTop + height <= size.height) {
              // Podiže se taman da stane.
              expect(top + height, moreOrLessEquals(size.height));
              expect(max, 0, reason: '$content');
            } else {
              expect(top, moreOrLessEquals(minTop), reason: '$content');
              expect(max, moreOrLessEquals(minTop + height - size.height));
              if (content != _Content.noAction) {
                await tester.ensureVisible(find.byKey(_last));
                await tester.pumpAndSettle();
                expect(
                  tester.getRect(find.byKey(_last)).bottom,
                  lessThanOrEqualTo(size.height),
                );
                expect(find.byKey(_last).hitTestable(), findsOneWidget);
              }
            }
            expect(tester.takeException(), isNull);
          }
          // Svi sadržaji koji staju počinju na istoj visini.
          expect(fittingTops.values.toSet().length, lessThanOrEqualTo(1));
        });
      }
    }
  }

  testWidgets('kratak i dugačak sadržaj počinju na istoj visini', (
    tester,
  ) async {
    for (final size in const [Size(390, 844), Size(1200, 760)]) {
      final tops = <double>{};
      for (final content in _Content.values) {
        await _pump(tester, size: size, scale: 1, child: _state(content));
        tops.add(tester.getTopLeft(find.byKey(_body)).dy);
      }
      expect(tops, hasLength(1), reason: '$size');
    }
  });

  testWidgets('zaglavlje ne pomera sadržaj dok ne dođe do njega', (
    tester,
  ) async {
    const size = Size(390, 844);
    final tops = <double>{};
    for (final header in [0.0, 60.0, 150.0]) {
      await _pump(
        tester,
        size: size,
        scale: 1,
        header: header,
        child: _state(_Content.oneButton),
      );
      tops.add(tester.getTopLeft(find.byKey(_body)).dy);
    }
    expect(tops, hasLength(1));
  });

  testWidgets('traka iznad prostora ne menja visinu u tabu', (tester) async {
    // Isti tab (600); gornja traka zauzima 0, 56 ili 100.
    tester.view.physicalSize = const Size(390, _scope);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tops = <double>{};
    for (final bar in [0.0, 56.0, 100.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTavliTheme(TavliMotif.bosiljak, Brightness.light),
          home: Scaffold(
            body: TavliEmptyAreaScope(
              height: _scope,
              child: Column(
                children: [
                  SizedBox(height: bar),
                  Expanded(
                    child: TavliEmptyArea(child: _state(_Content.noAction)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tops.add(tester.getTopLeft(find.byKey(_body)).dy);
    }
    expect(tops, {_scope * TavliEmptyArea.anchor});
  });

  // Crtež koji poštuje datu visinu, kao EmptyArt u aplikaciji.
  Widget withArt(double art) => TavliEmptyState(
    key: _body,
    art: ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: art, height: art),
      child: const SizedBox(key: _art),
    ),
    title: 'Još nema plana',
    message: 'Napravi plan i ovde ćeš videti šta se danas kuva.',
    action: TavliButton.primary(
      key: _last,
      label: 'Napravi plan',
      onPressed: () {},
    ),
  );

  testWidgets('ispod zaglavlja crtež se smanji da dugme ima razmak od dna', (
    tester,
  ) async {
    const size = Size(320, 560);
    await _pump(tester, size: size, scale: 1, header: 220, child: withArt(160));
    final art = tester.getSize(find.byKey(_art)).height;
    expect(art, lessThan(160));
    expect(art, greaterThanOrEqualTo(88));
    expect(_position(tester).maxScrollExtent, 0);
    expect(
      tester.getRect(find.byKey(_last)).bottom,
      lessThanOrEqualTo(size.height - TavliSpacing.large),
    );
  });

  testWidgets('crtež nije manji od 88; posle toga se sve pomera', (
    tester,
  ) async {
    const size = Size(320, 560);
    await _pump(tester, size: size, scale: 1, header: 400, child: withArt(160));
    expect(tester.getSize(find.byKey(_art)).height, 88);
    expect(_position(tester).maxScrollExtent, greaterThan(0));
    await tester.ensureVisible(find.byKey(_last));
    await tester.pumpAndSettle();
    expect(find.byKey(_last).hitTestable(), findsOneWidget);
  });

  testWidgets('crtež ostaje svoje veličine kada ima mesta', (tester) async {
    await _pump(
      tester,
      size: const Size(390, 844),
      scale: 1,
      header: 150,
      child: withArt(160),
    );
    expect(tester.getSize(find.byKey(_art)).height, 160);
  });

  testWidgets('crtež se smanji pre nego što se vrh pomeri', (tester) async {
    const size = Size(390, 600);
    await _pump(tester, size: size, scale: 1, child: withArt(300));
    expect(
      tester.getTopLeft(find.byKey(_body)).dy,
      moreOrLessEquals(_anchored(size)),
    );
    expect(tester.getSize(find.byKey(_art)).height, lessThan(300));
    expect(_position(tester).maxScrollExtent, 0);
  });

  testWidgets('niži vrh na telefonu i ivica sistema važe za svaki tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 764);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tops = <double>{};
    for (final bar in [0.0, 47.0, 119.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTavliTheme(TavliMotif.bosiljak, Brightness.light),
          home: Scaffold(
            body: TavliEmptyAreaScope(
              height: 764,
              anchor: TavliEmptyArea.phoneAnchor,
              inset: 47,
              child: Column(
                children: [
                  SizedBox(height: bar),
                  Expanded(
                    child: TavliEmptyArea(child: _state(_Content.oneButton)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tops.add(tester.getTopLeft(find.byKey(_body)).dy.roundToDouble());
    }
    expect(tops, {(47 + (764 - 47) / 3).roundToDouble()});
  });

  testWidgets('tekst 2×, dugme u dva reda: crtež nije manji od 88', (
    tester,
  ) async {
    const size = Size(390, 694);
    await _pump(
      tester,
      size: size,
      scale: 2,
      child: TavliEmptyState(
        key: _body,
        art: const SizedBox.square(key: _art, dimension: 160),
        title: 'Nabavka je prazna',
        message: 'Dodaj sastojke iz plana obroka ili iz pojedinačnog recepta.',
        action: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: TavliSpacing.small,
          children: [
            TavliButton.primary(
              label: 'Pogledaj recepte',
              glyph: TavliIcons.plan,
              onPressed: () {},
            ),
            TavliButton.primary(
              key: _last,
              label: 'Napravi plan',
              glyph: TavliIcons.plan,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    expect(tester.getRect(find.byKey(_art)).height, moreOrLessEquals(88));
  });
}
