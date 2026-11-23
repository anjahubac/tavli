import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import 'controls_test.dart' show pump;

void main() {
  test('dodir menja ništa → Volim → Ne volim → ništa', () {
    expect(TavliLiking.none.next, TavliLiking.like);
    expect(TavliLiking.like.next, TavliLiking.dislike);
    expect(TavliLiking.dislike.next, TavliLiking.none);
  });

  testWidgets('alergen: polje za dodir 48, vidljivo 44, stanje za čitač', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    bool? changed;
    await pump(
      tester,
      TavliToggleChip(
        label: 'Mleko',
        icon: TavliIcons.allergenMilk,
        selected: false,
        onChanged: (v) => changed = v,
      ),
    );
    final chip = find.byType(TavliToggleChip);
    expect(tester.getSize(chip).height, 48);
    expect(tester.getSize(chip).width, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(chip),
      matchesSemantics(
        label: 'Mleko',
        isButton: true,
        hasToggledState: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    // Dodir u prozirnom dodatku iznad pilule takođe menja izbor.
    await tester.tapAt(tester.getTopLeft(chip) + const Offset(24, 1));
    expect(changed, isTrue);
    semantics.dispose();
  });

  testWidgets('izabran alergen ima kvačicu, isključen ne reaguje', (
    tester,
  ) async {
    await pump(
      tester,
      const Column(
        children: [
          TavliToggleChip(label: 'Jaja', selected: true, onChanged: null),
        ],
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is TavliIcon && w.icon == TavliIcons.check,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Jaja'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('čip sa tri stanja čita stanje i daje sledeće', (tester) async {
    final semantics = tester.ensureSemantics();
    TavliLiking? next;
    await pump(
      tester,
      TavliLikingChip(
        label: 'Testenina',
        liking: TavliLiking.like,
        onChanged: (v) => next = v,
      ),
    );
    expect(find.bySemanticsLabel('Testenina: Volim'), findsOneWidget);
    await tester.tap(find.byType(TavliLikingChip));
    expect(next, TavliLiking.dislike);
    semantics.dispose();
  });

  testWidgets('izabrana namirnica: dugme „Ukloni“ 44 × 48', (tester) async {
    final semantics = tester.ensureSemantics();
    var removed = false;
    await pump(
      tester,
      TavliRemovableChip(
        label: 'Paradajz',
        liking: TavliLiking.like,
        onRemove: () => removed = true,
      ),
    );
    final remove = find.bySemanticsLabel('Ukloni Paradajz');
    expect(remove, findsOneWidget);
    expect(tester.getSize(find.byType(TavliRemovableChip)).height, 48);
    await tester.tap(remove);
    expect(removed, isTrue);
    semantics.dispose();
  });

  testWidgets('tekst 2× u uskom prostoru: čipovi prelaze u novi red', (
    tester,
  ) async {
    await pump(
      tester,
      TavliChipWrap(
        children: [
          for (final label in ['Pita, pica ili sendvič', 'Pečeno ili prženo'])
            TavliLikingChip(
              label: label,
              liking: TavliLiking.none,
              onChanged: (_) {},
            ),
          TavliAddChip(label: 'Dodaj', onTap: () {}),
        ],
      ),
      size: const Size(320, 600),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pločice omiljenih: traka i „Dodaj“', (tester) async {
    var opened = false;
    await pump(
      tester,
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TavliAddTile(label: 'Dodaj', onTap: () {}),
              TavliRecipeTile(
                title: 'Musaka od krompira',
                onTap: () => opened = true,
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(TavliRecipeTile)).width,
      TavliRecipeTile.stripWidth,
    );
    expect(tester.getSize(find.byType(TavliAddTile)).width, TavliAddTile.width);
    await tester.tap(find.text('Musaka od krompira'));
    expect(opened, isTrue);
  });
}
