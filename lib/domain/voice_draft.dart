/// Nacrt recepta koji se puni glasom (spec 027, TRELLO-91/92/131).
///
/// Glasovni agent ne izvršava ništa: AI vraća predlog radnji sa zatvorene
/// liste, provera ih pretvara u [VoiceAction], a [applyVoiceActions] ih
/// primenjuje na nacrt u memoriji. Nema baze, mreže, sinhronizacije ni
/// čuvanja; recept čuva osoba posle pregleda, kroz postojeću ručnu formu.
library;

import 'recipe.dart';

/// Nacrt u memoriji. [revision] raste sa svakom primenjenom izmenom, pa
/// zakasneli odgovor za stariju verziju može da se odbaci.
final class VoiceDraft {
  const VoiceDraft({
    this.title,
    this.servings,
    this.ingredients = const [],
    this.steps = const [],
    this.revision = 0,
  });

  static const empty = VoiceDraft();

  final String? title;
  final int? servings;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final int revision;

  bool get isEmpty =>
      title == null && servings == null && ingredients.isEmpty && steps.isEmpty;
}

/// Jedna dozvoljena radnja nad nacrtom. Indeksi se odnose na nacrt kakav je
/// bio kad je zahtev poslat (ugovor „Voice draft actions“).
sealed class VoiceAction {
  const VoiceAction();
}

final class AddIngredient extends VoiceAction {
  const AddIngredient(this.ingredient);
  final Ingredient ingredient;
}

/// Polja koja nisu `null` zamenjuju postojeća; [clearQuantity] briše
/// količinu („po ukusu“).
final class UpdateIngredient extends VoiceAction {
  const UpdateIngredient(
    this.index, {
    this.name,
    this.quantity,
    this.clearQuantity = false,
    this.unit,
    this.note,
  });

  final int index;
  final String? name;
  final double? quantity;
  final bool clearQuantity;
  final String? unit;
  final String? note;
}

final class RemoveIngredient extends VoiceAction {
  const RemoveIngredient(this.index);
  final int index;
}

final class AddStep extends VoiceAction {
  const AddStep(this.text);
  final String text;
}

final class UpdateStep extends VoiceAction {
  const UpdateStep(this.index, this.text);
  final int index;
  final String text;
}

final class RemoveStep extends VoiceAction {
  const RemoveStep(this.index);
  final int index;
}

final class SetServings extends VoiceAction {
  const SetServings(this.servings);
  final int servings;
}

final class SetTitle extends VoiceAction {
  const SetTitle(this.title);
  final String title;
}

/// Odgovor agenta za jedan izgovor: radnje i kratka poruka (prikazuje se i
/// čita naglas). Bez radnji i sa porukom = pitanje za pojašnjenje.
final class VoiceTurn {
  const VoiceTurn({this.actions = const [], this.reply});

  final List<VoiceAction> actions;
  final String? reply;
}

/// Primenjuje radnje na nacrt bez izmene ulaza. Redosled: izmene po
/// indeksu starog nacrta, zatim uklanjanja, pa dodavanja na kraj; tako
/// indeksi u jednom odgovoru ne zavise jedan od drugog. Provera
/// (`parseVoiceTurn`) već garantuje ispravne i nesukobljene indekse.
VoiceDraft applyVoiceActions(VoiceDraft draft, List<VoiceAction> actions) {
  if (actions.isEmpty) return draft;
  final ingredients = [...draft.ingredients];
  final steps = [...draft.steps];
  final removedIngredients = <int>{};
  final removedSteps = <int>{};
  final addedIngredients = <Ingredient>[];
  final addedSteps = <String>[];
  var title = draft.title;
  var servings = draft.servings;

  for (final a in actions) {
    switch (a) {
      case UpdateIngredient():
        final old = ingredients[a.index];
        final name = a.name ?? old.name;
        ingredients[a.index] = Ingredient(
          name: name,
          quantity: a.clearQuantity ? null : (a.quantity ?? old.quantity),
          unit: a.unit ?? old.unit,
          category: old.category,
          note: a.note ?? old.note,
          // Nov naziv znači drugu namirnicu: stara veza ne važi.
          link: name == old.name ? old.link : null,
        );
      case RemoveIngredient():
        removedIngredients.add(a.index);
      case AddIngredient():
        addedIngredients.add(a.ingredient);
      case UpdateStep():
        steps[a.index] = a.text;
      case RemoveStep():
        removedSteps.add(a.index);
      case AddStep():
        addedSteps.add(a.text);
      case SetServings():
        servings = a.servings;
      case SetTitle():
        title = a.title;
    }
  }

  return VoiceDraft(
    title: title,
    servings: servings,
    ingredients: [
      for (final (i, x) in ingredients.indexed)
        if (!removedIngredients.contains(i)) x,
      ...addedIngredients,
    ],
    steps: [
      for (final (i, x) in steps.indexed)
        if (!removedSteps.contains(i)) x,
      ...addedSteps,
    ],
    revision: draft.revision + 1,
  );
}

/// Tok jednog diktata: trenutni nacrt i istorija za „Poništi“.
/// Odgovor se primenjuje samo ako je pripremljen za trenutnu verziju
/// nacrta; zakasneli ili posle otkazivanja se odbacuje (FR-103).
final class VoiceSession {
  VoiceSession([VoiceDraft initial = VoiceDraft.empty]) : _draft = initial;

  VoiceDraft _draft;
  final _history = <VoiceDraft>[];
  var _cancelled = false;

  VoiceDraft get draft => _draft;
  bool get canUndo => _history.isNotEmpty;
  bool get isCancelled => _cancelled;

  /// Vraća false (i ne menja ništa) za odgovor na stariju verziju nacrta
  /// ili posle [cancel].
  bool apply(VoiceTurn turn, {required int baseRevision}) {
    if (_cancelled || baseRevision != _draft.revision) return false;
    if (turn.actions.isEmpty) return true;
    _history.add(_draft);
    _draft = applyVoiceActions(_draft, turn.actions);
    return true;
  }

  /// Vraća nacrt pre poslednjeg primenjenog izgovora. Verzija i dalje raste,
  /// pa odgovor pripremljen pre poništavanja ne može da se primeni.
  void undo() {
    if (_history.isEmpty) return;
    final previous = _history.removeLast();
    _draft = VoiceDraft(
      title: previous.title,
      servings: previous.servings,
      ingredients: previous.ingredients,
      steps: previous.steps,
      revision: _draft.revision + 1,
    );
  }

  /// „Otkaži“: dalji odgovori se ignorišu; sačuvani recepti se ne diraju.
  void cancel() => _cancelled = true;
}
