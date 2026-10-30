import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/recipe.dart';
import '../domain/recipe_version.dart';
import 'database.dart';
import 'recipe_photo_store.dart';

/// Recepti i njihove prethodne verzije u lokalnoj bazi.
class RecipeRepository {
  RecipeRepository(this._db, this._photos, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final RecipePhotoStore _photos;
  final DateTime Function() _clock;

  /// Najviše toliko prethodnih verzija po receptu.
  static const maxVersions = 30;

  Stream<List<Recipe>> watchAll() {
    final q = _db.select(_db.recipes)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return q.watch().map((rows) => rows.map(_fromRow).toList());
  }

  Stream<Recipe?> watch(String id) => (_db.select(
    _db.recipes,
  )..where((t) => t.id.equals(id))).watchSingleOrNull().map(_fromRowOrNull);

  Future<Recipe?> get(String id) => (_db.select(
    _db.recipes,
  )..where((t) => t.id.equals(id))).getSingleOrNull().then(_fromRowOrNull);

  Future<void> create(Recipe recipe) =>
      _db.into(_db.recipes).insert(_toCompanion(recipe));

  /// Menja recept i čuva prethodno stanje kao verziju.
  Future<void> update(
    Recipe next, {
    required ChangeKind kind,
    String? instruction,
    String? changedBy,
  }) => _db.transaction(() async {
    final current = await get(next.id);
    if (current == null) throw StateError('Recept ${next.id} ne postoji');
    await _addVersion(current, kind, instruction, changedBy);
    await _replace(next);
  });

  /// Od najnovije ka najstarijoj. Pokvareni zapisi se preskaču.
  Stream<List<RecipeVersion>> watchVersions(String recipeId) =>
      _versionsQuery(recipeId).watch().map(_versionsFromRows);

  Future<List<RecipeVersion>> _versions(String recipeId) =>
      _versionsQuery(recipeId).get().then(_versionsFromRows);

  SimpleSelectStatement<$RecipeVersionsTable, RecipeVersionRow> _versionsQuery(
    String recipeId,
  ) => _db.select(_db.recipeVersions)
    ..where((t) => t.recipeId.equals(recipeId))
    ..orderBy([
      (t) => OrderingTerm.desc(t.createdAt),
      (t) => OrderingTerm.desc(t.id),
    ]);

  static List<RecipeVersion> _versionsFromRows(List<RecipeVersionRow> rows) => [
    for (final r in rows) ?_versionFromRow(r),
  ];

  /// Vraća stanje pre poslednje izmene i briše tu verziju.
  /// Vraća false kad nema šta da se poništi.
  Future<bool> undoLast(String recipeId) => _db.transaction(() async {
    final versions = await _versions(recipeId);
    if (versions.isEmpty) return false;
    final last = versions.first;
    await _replace(last.recipe);
    await (_db.delete(
      _db.recipeVersions,
    )..where((t) => t.id.equals(last.id))).go();
    return true;
  });

  /// Vraća izabranu verziju; trenutno stanje se čuva kao nova verzija.
  Future<void> restore(int versionId) => _db.transaction(() async {
    final row = await (_db.select(
      _db.recipeVersions,
    )..where((t) => t.id.equals(versionId))).getSingle();
    final version = _versionFromRow(row);
    if (version == null) throw StateError('Verzija $versionId je pokvarena');
    await update(version.recipe, kind: ChangeKind.restore);
  });

  /// Briše recept, njegove verzije, ocene i slike.
  Future<void> delete(String id) async {
    final photoPaths = <String>{};
    await _db.transaction(() async {
      final current = await get(id);
      if (current?.imagePath case final p?) photoPaths.add(p);
      for (final v in await _versions(id)) {
        if (v.recipe.imagePath case final p?) photoPaths.add(p);
      }
      await (_db.delete(
        _db.recipeVersions,
      )..where((t) => t.recipeId.equals(id))).go();
      await (_db.delete(_db.ratings)..where((t) => t.recipeId.equals(id))).go();
      await (_db.update(_db.mealPlanEntries)
            ..where((t) => t.recipeId.equals(id)))
          .write(const MealPlanEntriesCompanion(recipeId: Value(null)));
      await (_db.delete(_db.recipes)..where((t) => t.id.equals(id))).go();
    });
    for (final p in photoPaths) {
      await _photos.delete(p);
    }
  }

  Future<void> _addVersion(
    Recipe previous,
    ChangeKind kind,
    String? instruction,
    String? changedBy,
  ) async {
    await _db
        .into(_db.recipeVersions)
        .insert(
          RecipeVersionsCompanion.insert(
            recipeId: previous.id,
            recipeJson: jsonEncode(previous.toJson()),
            instruction: Value(instruction),
            changeKind: Value(kind.name),
            changedBy: Value(changedBy),
            createdAt: _clock(),
          ),
        );
    final keep = _db.selectOnly(_db.recipeVersions)
      ..addColumns([_db.recipeVersions.id])
      ..where(_db.recipeVersions.recipeId.equals(previous.id))
      ..orderBy([
        OrderingTerm.desc(_db.recipeVersions.createdAt),
        OrderingTerm.desc(_db.recipeVersions.id),
      ])
      ..limit(maxVersions);
    await (_db.delete(_db.recipeVersions)..where(
          (t) => t.recipeId.equals(previous.id) & t.id.isNotInQuery(keep),
        ))
        .go();
  }

  Future<void> _replace(Recipe recipe) => (_db.update(
    _db.recipes,
  )..where((t) => t.id.equals(recipe.id))).write(_toCompanion(recipe));

  RecipesCompanion _toCompanion(Recipe r) => RecipesCompanion.insert(
    id: r.id,
    title: r.title,
    servings: r.servings,
    prepMinutes: Value(r.prepMinutes),
    source: r.source.name,
    ingredientsJson: jsonEncode([for (final i in r.ingredients) i.toJson()]),
    stepsJson: jsonEncode(r.steps),
    imagePath: Value(r.imagePath),
    answeredBy: Value(r.answeredBy),
    createdAt: r.createdAt,
    updatedAt: _clock(),
  );

  static Recipe? _fromRowOrNull(RecipeRow? row) =>
      row == null ? null : _fromRow(row);

  static Recipe _fromRow(RecipeRow row) => Recipe(
    id: row.id,
    title: row.title,
    servings: row.servings,
    prepMinutes: row.prepMinutes,
    ingredients: [
      for (final i in jsonDecode(row.ingredientsJson) as List<dynamic>)
        Ingredient.fromJson(i as Map<String, dynamic>),
    ],
    steps: [
      for (final s in jsonDecode(row.stepsJson) as List<dynamic>) s as String,
    ],
    source: RecipeSource.values.asNameMap()[row.source] ?? RecipeSource.manual,
    imagePath: row.imagePath,
    answeredBy: row.answeredBy,
    createdAt: row.createdAt,
  );

  static RecipeVersion? _versionFromRow(RecipeVersionRow row) {
    try {
      return RecipeVersion(
        id: row.id,
        recipeId: row.recipeId,
        recipe: Recipe.fromJson(
          jsonDecode(row.recipeJson) as Map<String, dynamic>,
        ),
        kind: ChangeKind.values.asNameMap()[row.changeKind] ?? ChangeKind.ai,
        instruction: row.instruction,
        changedBy: row.changedBy,
        createdAt: row.createdAt,
      );
    } on FormatException {
      return null;
    }
  }
}
