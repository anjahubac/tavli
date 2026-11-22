/// Stable codes shared with the reviewed ingredient catalog.
enum AllergenGroup {
  gluten,
  crustaceans,
  eggs,
  fish,
  peanuts,
  soy,
  milk,
  nuts,
  celery,
  mustard,
  sesame,
  sulphites,
  lupin,
  molluscs;

  String get code => name;

  static Set<AllergenGroup> parseSelection(Object? raw) {
    if (raw is! List<Object?>) {
      throw const FormatException('Izbor alergena mora biti lista.');
    }
    final groups = {for (final group in values) group.code: group};
    final selection = <AllergenGroup>{};
    for (final code in raw) {
      final group = groups[code];
      if (group == null || !selection.add(group)) {
        throw const FormatException('Izbor alergena nije ispravan.');
      }
    }
    return Set.unmodifiable(selection);
  }
}
