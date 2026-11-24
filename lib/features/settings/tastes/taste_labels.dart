import 'package:tavli_ui/tavli_ui.dart';

import '../../../domain/allergen_group.dart';
import '../../../domain/cuisine_preferences.dart';

/// Alergeni redom kao na platnu „Ukusi i alergeni“, sa nazivom i ikonicom.
const allergenChoices = <(AllergenGroup, String, TavliIconData)>[
  (AllergenGroup.gluten, 'Gluten', TavliIcons.allergenGluten),
  (AllergenGroup.milk, 'Mleko', TavliIcons.allergenMilk),
  (AllergenGroup.eggs, 'Jaja', TavliIcons.allergenEggs),
  (AllergenGroup.nuts, 'Orašasti plodovi', TavliIcons.allergenNuts),
  (AllergenGroup.peanuts, 'Kikiriki', TavliIcons.allergenPeanuts),
  (AllergenGroup.fish, 'Riba', TavliIcons.allergenFish),
  (AllergenGroup.crustaceans, 'Rakovi', TavliIcons.allergenCrustaceans),
  (AllergenGroup.molluscs, 'Mekušci', TavliIcons.allergenMolluscs),
  (AllergenGroup.soy, 'Soja', TavliIcons.allergenSoy),
  (AllergenGroup.sesame, 'Susam', TavliIcons.allergenSesame),
  (AllergenGroup.celery, 'Celer', TavliIcons.allergenCelery),
  (AllergenGroup.mustard, 'Slačica', TavliIcons.allergenMustard),
  (AllergenGroup.sulphites, 'Sulfiti', TavliIcons.allergenSulphites),
  (AllergenGroup.lupin, 'Lupina', TavliIcons.allergenLupin),
];

/// Naziv kuhinje kako piše na platnu.
String cuisineLabel(Cuisine cuisine) => switch (cuisine) {
  Cuisine.serbian => 'Srpska',
  Cuisine.italian => 'Italijanska',
  Cuisine.japanese => 'Japanska',
  Cuisine.french => 'Francuska',
  Cuisine.mexican => 'Meksička',
};

/// Naziv namirnice ili kategorije iz kataloga, prvim velikim slovom.
String capitalized(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Oblik reči uz broj: 1 [one], 2–4 [few], 5 i više (i 11–14) [many].
String countLabel(int n, String one, String few, String many) {
  final lastTwo = n % 100;
  final last = n % 10;
  if (last == 1 && lastTwo != 11) return '$n $one';
  if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
    return '$n $few';
  }
  return '$n $many';
}

/// Podnaslov reda „Ukusi i alergeni“ na Profilu, kao na platnu
/// („2 alergena · 6 sviđanja · 3 omiljena recepta“). Delovi sa nulom se
/// izostavljaju.
String tastesSummary({
  required int allergens,
  required int likes,
  required int favorites,
}) {
  final parts = [
    if (allergens > 0) countLabel(allergens, 'alergen', 'alergena', 'alergena'),
    if (likes > 0) countLabel(likes, 'sviđanje', 'sviđanja', 'sviđanja'),
    if (favorites > 0)
      countLabel(
        favorites,
        'omiljeni recept',
        'omiljena recepta',
        'omiljenih recepata',
      ),
  ];
  return parts.isEmpty ? 'Ništa nije izabrano' : parts.join(' · ');
}
