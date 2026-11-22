import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/voice_draft.dart';

const meso = Ingredient(name: 'mleveno meso', quantity: 1, unit: 'kg');
const so = Ingredient(name: 'so', quantity: 1, unit: 'kašičica');
const pirinac = Ingredient(name: 'pirinač', quantity: 0.5, unit: 'kg');

const draft = VoiceDraft(
  title: 'Sarma',
  servings: 6,
  ingredients: [meso, so, pirinac],
  steps: ['Iseckaj luk.', 'Umotaj sarmu.'],
  revision: 3,
);

List<String> names(VoiceDraft d) => [for (final i in d.ingredients) i.name];

void main() {
  group('applyVoiceActions', () {
    test('ne menja ulaz i podiže verziju', () {
      final next = applyVoiceActions(draft, const [SetServings(4)]);
      expect(next.servings, 4);
      expect(next.revision, 4);
      expect(draft.servings, 6);
      expect(names(draft), ['mleveno meso', 'so', 'pirinač']);
    });

    test('indeksi se odnose na stari nacrt, bez obzira na redosled', () {
      final next = applyVoiceActions(draft, const [
        RemoveIngredient(0),
        UpdateIngredient(2, quantity: 0.25),
        AddIngredient(Ingredient(name: 'jaje', quantity: 2, unit: 'kom')),
      ]);
      expect(names(next), ['so', 'pirinač', 'jaje']);
      expect(next.ingredients[1].quantity, 0.25);
    });

    test('izmena čuva neizmenjena polja; brisanje količine', () {
      final next = applyVoiceActions(draft, const [
        UpdateIngredient(0, quantity: 700, unit: 'g'),
        UpdateIngredient(1, clearQuantity: true),
      ]);
      expect(next.ingredients[0].name, 'mleveno meso');
      expect(next.ingredients[0].quantity, 700);
      expect(next.ingredients[0].unit, 'g');
      expect(next.ingredients[1].quantity, isNull);
      expect(next.ingredients[1].unit, 'kašičica');
    });

    test('koraci, naziv i porcije', () {
      final next = applyVoiceActions(draft, const [
        UpdateStep(0, 'Iseckaj crni luk.'),
        RemoveStep(1),
        AddStep('Kuvaj dva sata.'),
        SetTitle('Posna sarma'),
      ]);
      expect(next.steps, ['Iseckaj crni luk.', 'Kuvaj dva sata.']);
      expect(next.title, 'Posna sarma');
    });

    test('bez radnji nacrt ostaje isti objekat', () {
      expect(identical(applyVoiceActions(draft, const []), draft), isTrue);
    });
  });

  group('VoiceSession', () {
    test('primenjuje odgovor za trenutnu verziju', () {
      final s = VoiceSession(draft);
      expect(
        s.apply(const VoiceTurn(actions: [SetServings(2)]), baseRevision: 3),
        isTrue,
      );
      expect(s.draft.servings, 2);
      expect(s.canUndo, isTrue);
    });

    test('zakasneli odgovor za stariju verziju se odbacuje', () {
      final s = VoiceSession(draft)
        ..apply(const VoiceTurn(actions: [SetServings(2)]), baseRevision: 3);
      final applied = s.apply(
        const VoiceTurn(actions: [RemoveIngredient(0)]),
        baseRevision: 3,
      );
      expect(applied, isFalse);
      expect(names(s.draft), ['mleveno meso', 'so', 'pirinač']);
    });

    test('posle otkazivanja ništa se ne primenjuje', () {
      final s = VoiceSession(draft)..cancel();
      expect(
        s.apply(const VoiceTurn(actions: [SetServings(2)]), baseRevision: 3),
        isFalse,
      );
      expect(s.draft.servings, 6);
    });

    test(
      'Poništi vraća prethodni izgovor; stari odgovor posle toga ne važi',
      () {
        final s = VoiceSession(draft)
          ..apply(
            const VoiceTurn(actions: [RemoveIngredient(1), SetServings(2)]),
            baseRevision: 3,
          );
        final beforeUndo = s.draft.revision;
        s.undo();
        expect(names(s.draft), ['mleveno meso', 'so', 'pirinač']);
        expect(s.draft.servings, 6);
        expect(s.canUndo, isFalse);
        expect(
          s.apply(
            const VoiceTurn(actions: [SetServings(1)]),
            baseRevision: beforeUndo,
          ),
          isFalse,
        );
      },
    );

    test('pitanje bez radnji ne pravi korak u istoriji', () {
      final s = VoiceSession(draft);
      expect(
        s.apply(const VoiceTurn(reply: 'Koliko pirinča?'), baseRevision: 3),
        isTrue,
      );
      expect(s.canUndo, isFalse);
      expect(s.draft.revision, 3);
    });
  });
}
