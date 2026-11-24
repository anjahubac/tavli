import 'dart:convert';

import 'package:drift/drift.dart';

import '../account/auth_controller.dart';
import '../domain/food_matcher.dart';
import '../domain/ids.dart';
import '../domain/ingredient_links.dart';
import '../domain/recipe.dart';
import '../domain/recipe_labels.dart';
import '../domain/recipe_version.dart';
import '../domain/shopping_source.dart';
import '../domain/shopping_sync.dart';
import '../sync/entities.dart';
import '../sync/recipe_link_rollout.dart';
import '../sync/synced_writer.dart';
import 'database.dart';
import 'recipe_image_jobs.dart';
import 'recipe_photo_store.dart';
import 'shopping_repository.dart';

/// Recepti i njihove prethodne verzije u lokalnoj bazi (kešu naloga).
/// Čita samo recepte domaćinstva iz [AccountScope]; svaka izmena se u istoj
/// transakciji upisuje i u red za slanje na server ([SyncedWriter]).
class RecipeRepository {
  RecipeRepository(
    this._db,
    this._photos, {
    required this._writer,
    required this._scope,
    this._recipeLinkRollout = recipeLinkRollout,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final RecipePhotoStore _photos;
  final SyncedWriter _writer;
  final AccountScope _scope;
  final RecipeLinkRollout _recipeLinkRollout;
  final DateTime Function() _clock;

  static const _recipe = 'recipe';
  static const _version = 'recipe_version';

  /// Redosled umetanja: id-jevi verzija su slučajni, pa rowid razrešava
  /// verzije sa istim vremenom.
  static const _rowid = CustomExpression<int>('rowid');

  /// Najviše toliko prethodnih verzija po receptu.
  static const maxVersions = 30;

  SimpleSelectStatement<$RecipesTable, RecipeRow> _all() =>
      _db.select(_db.recipes)
        ..where((t) => t.householdId.equals(_scope.householdId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

  Stream<List<Recipe>> watchAll() =>
      _all().watch().map((rows) => rows.map(_fromRow).toList());

  /// Svi recepti domaćinstva, jednom (npr. za predlog plana).
  Future<List<Recipe>> getAll() async =>
      (await _all().get()).map(_fromRow).toList();

  SimpleSelectStatement<$RecipesTable, RecipeRow> _one(String id) => _db.select(
    _db.recipes,
  )..where((t) => t.id.equals(id) & t.householdId.equals(_scope.householdId));

  Stream<Recipe?> watch(String id) =>
      _one(id).watchSingleOrNull().map(_fromRowOrNull);

  Future<Recipe?> get(String id) =>
      _one(id).getSingleOrNull().then(_fromRowOrNull);

  /// Idempotently attaches unambiguous catalog matches to existing recipe
  /// ingredients. Writes stay disabled until both rollout guards are open.
  /// Original ingredient names and approved meal snapshots are untouched.
  Future<int> backfillCatalogLinks(FoodMatcher matcher) async {
    if (!_recipeLinkRollout.enabled) return 0;
    final rows = await _all().get();
    var linked = 0;
    for (final row in rows) {
      final ingredients = _ingredientsFromJson(row.ingredientsJson);
      var changed = false;
      final next = <Ingredient>[];
      for (final ingredient in ingredients) {
        final key = ingredientKey(ingredient.name);
        if (ingredient.link != null || ingredient.unlinkedKey == key) {
          next.add(ingredient);
          continue;
        }
        final result = await matcher.findByName(
          originalText: ingredient.name,
          scope: FoodLookupScope(householdId: _scope.householdId),
        );
        if (result case Matched(:final food)) {
          next.add(
            Ingredient(
              name: ingredient.name,
              quantity: ingredient.quantity,
              unit: ingredient.unit,
              category: ingredient.category,
              note: ingredient.note,
              link: IngredientLink(
                foodId: food.id,
                matchedKey: key,
                linkSource: LinkSource.matched,
              ),
              unlinkedKey: ingredient.unlinkedKey,
            ),
          );
          changed = true;
        } else {
          next.add(ingredient);
        }
      }
      if (!changed) continue;
      final encoded = jsonEncode([for (final i in next) i.toJson()]);
      final applied = await _db.transaction(() async {
        final updated =
            await (_db.update(_db.recipes)..where(
                  (t) =>
                      t.id.equals(row.id) &
                      t.householdId.equals(_scope.householdId) &
                      t.ingredientsJson.equals(row.ingredientsJson),
                ))
                .write(
                  RecipesCompanion(
                    ingredientsJson: Value(encoded),
                    updatedAt: Value(_clock()),
                  ),
                );
        if (updated == 0) return false;
        await _writer.upsert(_recipe, row.id);
        return true;
      });
      if (applied) {
        linked +=
            next.where((i) => i.link != null).length -
            ingredients.where((i) => i.link != null).length;
      }
    }
    return linked;
  }

  /// Čuva nov recept. Slika koja stiže sa receptom je slika korisnika.
  /// AI recept bez slike ulazi u lokalni red za AI sliku (TRELLO-130).
  Future<void> create(Recipe recipe) => _db.transaction(() async {
    final saved = recipe.imagePath != null && recipe.imageSource == null
        ? recipe.copyWith(imageSource: RecipeImageSource.user)
        : recipe;
    await _db.into(_db.recipes).insert(_toCompanion(saved));
    await _writer.upsert(_recipe, saved.id);
    if (saved.imagePath case final p?) await _writer.photoUpload(p);
    if (saved.wantsAiImage) await queueAiImage(_db, _scope, saved.id, _clock());
  });

  /// Upisuje AI sliku u recept, samo ako recept i dalje nema sliku i slika
  /// nije korisnikova. Nije nova verzija recepta. Vraća false kad je slika
  /// odbačena (recept obrisan, ima sliku ili ga je korisnik promenio).
  Future<bool> attachAiImage(String id, String localPath) =>
      _db.transaction(() async {
        final current = await get(id);
        if (current == null || !current.wantsAiImage) return false;
        await (_db.update(_db.recipes)..where(
              (t) => t.id.equals(id) & t.householdId.equals(_scope.householdId),
            ))
            .write(
              RecipesCompanion(
                imagePath: Value(localPath),
                imageSource: Value(RecipeImageSource.ai.name),
                updatedAt: Value(_clock()),
              ),
            );
        await _writer.upsert(_recipe, id);
        return true;
      });

  /// Čuva opis slike koji je napravio rezervni AI poziv, ako ga recept
  /// još nema. Nije nova verzija recepta.
  Future<void> setImageDescription(String id, String description) =>
      _db.transaction(() async {
        final current = await get(id);
        if (current == null || current.imageDescription != null) return;
        await (_db.update(_db.recipes)..where(
              (t) => t.id.equals(id) & t.householdId.equals(_scope.householdId),
            ))
            .write(
              RecipesCompanion(
                imageDescription: Value(description),
                updatedAt: Value(_clock()),
              ),
            );
        await _writer.upsert(_recipe, id);
      });

  /// Menja recept i čuva prethodno stanje kao verziju.
  ///
  /// Oznake se uzimaju iz baze u trenutku čuvanja, ne iz [next]: forma i
  /// AI predlog nose oznake od trenutka kad su otvoreni, a one su se možda
  /// u međuvremenu promenile. Jedino AI izmena sme da donese nove oznake,
  /// i to samo kada ih ima, a u bazi nisu oznake korisnika. Oznake inače
  /// menja samo [setLabels].
  Future<void> update(
    Recipe next, {
    required ChangeKind kind,
    String? instruction,
    String? changedBy,
  }) => _db.transaction(() async {
    final current = await get(next.id);
    if (current == null) throw StateError('Recept ${next.id} ne postoji');
    final aiMayLabel =
        kind == ChangeKind.ai &&
        !current.labels.isUserSet &&
        !next.labels.isEmpty;
    final labels = aiMayLabel ? next.labels : current.labels;
    // Nova slika iz izmene je uvek korisnikova (AI sliku upisuje samo
    // [attachAiImage]); inače izvor slike ostaje.
    final newPhoto =
        next.imagePath != null && next.imagePath != current.imagePath;
    final imageSource = newPhoto ? RecipeImageSource.user : current.imageSource;
    await _addVersion(current, kind, instruction, changedBy);
    await _replace(
      _withImageSource(
        next.copyWith(
          labels: labels,
          imageDescription: current.imageDescription,
          ingredients: carryIngredientLinks(
            from: current.ingredients,
            to: next.ingredients,
          ),
        ),
        imageSource,
      ),
    );
    if (next.imagePath case final p? when p != current.imagePath) {
      await _writer.photoUpload(p);
    }
  });

  /// Oznake koje je korisnik izabrao na receptu. Nisu nova verzija recepta.
  Future<void> setLabels(String id, RecipeLabels labels) => _db.transaction(
    () async {
      final updated =
          await (_db.update(_db.recipes)..where(
                (t) =>
                    t.id.equals(id) & t.householdId.equals(_scope.householdId),
              ))
              .write(
                RecipesCompanion(
                  mealTypesJson: Value(_mealsJson(labels)),
                  weight: Value(labels.weight),
                  dishKind: Value(labels.dishKind),
                  labelsSource: Value(labels.source),
                  updatedAt: Value(_clock()),
                ),
              );
      if (updated == 0) throw StateError('Recept $id ne postoji');
      await _writer.upsert(_recipe, id);
    },
  );

  /// Od najnovije ka najstarijoj. Pokvareni zapisi se preskaču.
  Stream<List<RecipeVersion>> watchVersions(String recipeId) =>
      _versionsQuery(recipeId).watch().map(_versionsFromRows);

  Future<List<RecipeVersion>> _versions(String recipeId) =>
      _versionsQuery(recipeId).get().then(_versionsFromRows);

  SimpleSelectStatement<$RecipeVersionsTable, RecipeVersionRow> _versionsQuery(
    String recipeId,
  ) => _db.select(_db.recipeVersions)
    ..where(
      (t) =>
          t.recipeId.equals(recipeId) &
          t.householdId.equals(_scope.householdId),
    )
    ..orderBy([
      (t) => OrderingTerm.desc(t.createdAt),
      (_) => OrderingTerm.desc(_rowid),
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
    // Oznake nisu deo istorije: vraćanje verzije čuva trenutne.
    final current = await get(recipeId);
    await _replace(
      _keepAiImage(last.recipe, current).copyWith(labels: current?.labels),
    );
    await (_db.delete(
      _db.recipeVersions,
    )..where((t) => t.id.equals(last.id))).go();
    await _writer.delete(_version, last.id);
    return true;
  });

  /// Vraća izabranu verziju; trenutno stanje se čuva kao nova verzija.
  Future<void> restore(String versionId) => _db.transaction(() async {
    final row =
        await (_db.select(_db.recipeVersions)..where(
              (t) =>
                  t.id.equals(versionId) &
                  t.householdId.equals(_scope.householdId),
            ))
            .getSingle();
    final version = _versionFromRow(row);
    if (version == null) throw StateError('Verzija $versionId je pokvarena');
    final current = await get(version.recipeId);
    await update(
      _keepAiImage(version.recipe, current).copyWith(labels: current?.labels),
      kind: ChangeKind.restore,
    );
  });

  /// Briše recept, njegove verzije, ocene i slike (i na serveru).
  Future<void> delete(String id) async {
    final photoPaths = <String>{};
    await _db.transaction(() async {
      final current = await get(id);
      if (current == null) return;
      if (current.imagePath case final p?) photoPaths.add(p);
      final versionIds = [
        for (final v in await (_db.select(
          _db.recipeVersions,
        )..where((t) => t.recipeId.equals(id))).get())
          v.id,
      ];
      for (final v in await _versions(id)) {
        if (v.recipe.imagePath case final p?) photoPaths.add(p);
      }
      await (_db.delete(
        _db.recipeVersions,
      )..where((t) => t.recipeId.equals(id))).go();
      for (final v in versionIds) {
        await _writer.delete(_version, v);
      }
      final ratings = await (_db.select(
        _db.ratings,
      )..where((t) => t.recipeId.equals(id))).get();
      await (_db.delete(_db.ratings)..where((t) => t.recipeId.equals(id))).go();
      for (final r in ratings) {
        if (r.userId == _scope.userId) await _writer.delete('rating', r.id);
      }
      await (_db.delete(_db.ratingSummaries)..where(
            (t) =>
                t.householdId.equals(_scope.householdId) &
                t.recipeId.equals(id),
          ))
          .go();
      final entries = await (_db.select(
        _db.mealPlanEntries,
      )..where((t) => t.recipeId.equals(id))).get();
      await (_db.update(_db.mealPlanEntries)
            ..where((t) => t.recipeId.equals(id)))
          .write(const MealPlanEntriesCompanion(recipeId: Value(null)));
      for (final e in entries) {
        await _writer.upsert('meal_plan_entry', e.id);
      }
      await const RecipeEntity().deleteLocal(_db, id);
      await _writer.delete(_recipe, id);
      // Slika se briše samo ako je nijedan drugi recept ni verzija ne koristi.
      for (final p in [...photoPaths]) {
        if (await _isPhotoUsed(p)) {
          photoPaths.remove(p);
        } else {
          await _writer.photoDelete(p);
        }
      }
    });
    for (final p in photoPaths) {
      await _photos.delete(p);
    }
  }

  Future<bool> _isPhotoUsed(String path) async {
    final inRecipes =
        await (_db.select(_db.recipes)
              ..where(
                (t) =>
                    t.imagePath.equals(path) &
                    t.householdId.equals(_scope.householdId),
              )
              ..limit(1))
            .get();
    if (inRecipes.isNotEmpty) return true;
    final inVersions =
        await (_db.select(_db.recipeVersions)
              ..where(
                (t) =>
                    t.recipeJson.like('%${jsonEncode(path)}%') &
                    t.householdId.equals(_scope.householdId),
              )
              ..limit(1))
            .get();
    return inVersions.isNotEmpty;
  }

  Future<void> _addVersion(
    Recipe previous,
    ChangeKind kind,
    String? instruction,
    String? changedBy,
  ) async {
    final versionId = newId();
    await _db
        .into(_db.recipeVersions)
        .insert(
          RecipeVersionsCompanion.insert(
            id: versionId,
            householdId: Value(_scope.householdId),
            recipeId: previous.id,
            recipeJson: jsonEncode(previous.toJson()),
            instruction: Value(instruction),
            changeKind: Value(kind.name),
            changedBy: Value(changedBy),
            createdAt: _clock(),
          ),
        );
    await _writer.upsert(_version, versionId);
    final keep = _db.selectOnly(_db.recipeVersions)
      ..addColumns([_db.recipeVersions.id])
      ..where(_db.recipeVersions.recipeId.equals(previous.id))
      ..orderBy([
        OrderingTerm.desc(_db.recipeVersions.createdAt),
        OrderingTerm.desc(_rowid),
      ])
      ..limit(maxVersions);
    final pruned =
        await (_db.select(_db.recipeVersions)..where(
              (t) => t.recipeId.equals(previous.id) & t.id.isNotInQuery(keep),
            ))
            .get();
    for (final v in pruned) {
      await (_db.delete(
        _db.recipeVersions,
      )..where((t) => t.id.equals(v.id))).go();
      await _writer.delete(_version, v.id);
    }
  }

  Future<void> _replace(Recipe recipe) async {
    await (_db.update(_db.recipes)..where(
          (t) =>
              t.id.equals(recipe.id) & t.householdId.equals(_scope.householdId),
        ))
        .write(_toCompanion(recipe));
    await _writer.upsert(_recipe, recipe.id);
    await _refreshPlannedMeals(recipe);
  }

  /// Izmene recepta i vezanih obroka se čuvaju u istoj transakciji.
  Future<void> _refreshPlannedMeals(Recipe recipe) async {
    final snapshot = jsonEncode(RecipeSnapshot.fromRecipe(recipe).toJson());
    final entries =
        await (_db.select(_db.mealPlanEntries)..where(
              (t) =>
                  t.householdId.equals(_scope.householdId) &
                  t.recipeId.equals(recipe.id) &
                  t.isCooked.equals(false) &
                  (t.recipeSnapshotJson.isNull() |
                      t.recipeSnapshotJson.equals(snapshot).not()),
            ))
            .get();
    if (entries.isEmpty) return;

    for (final entry in entries) {
      await (_db.update(_db.mealPlanEntries)
            ..where((t) => t.id.equals(entry.id)))
          .write(MealPlanEntriesCompanion(recipeSnapshotJson: Value(snapshot)));
      await _writer.upsert('meal_plan_entry', entry.id);
    }
    final shopping = ShoppingRepository(
      _db,
      scope: _scope,
      writer: _writer,
      clock: _clock,
    );
    for (final planId in entries.map((entry) => entry.planId).toSet()) {
      await shopping.reconcilePlan(planId);
    }
  }

  /// Verzija iz vremena pre AI slike ne briše AI sliku koja je stigla
  /// kasnije (AI slika nije nova verzija recepta).
  static Recipe _keepAiImage(Recipe version, Recipe? current) {
    final described = version.copyWith(
      imageDescription: current?.imageDescription,
    );
    if (version.imagePath != null ||
        current == null ||
        current.imageSource != RecipeImageSource.ai) {
      return described;
    }
    return described.copyWith(
      imagePath: current.imagePath,
      imageSource: RecipeImageSource.ai,
    );
  }

  /// [Recipe.copyWith] ne može da obriše izvor slike (null).
  static Recipe _withImageSource(Recipe r, RecipeImageSource? source) => Recipe(
    id: r.id,
    title: r.title,
    servings: r.servings,
    prepMinutes: r.prepMinutes,
    ingredients: r.ingredients,
    steps: r.steps,
    source: r.source,
    createdAt: r.createdAt,
    imagePath: r.imagePath,
    answeredBy: r.answeredBy,
    labels: r.labels,
    imageDescription: r.imageDescription,
    imageSource: source,
  );

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
    householdId: Value(_scope.householdId),
    mealTypesJson: Value(_mealsJson(r.labels)),
    weight: Value(r.labels.weight),
    dishKind: Value(r.labels.dishKind),
    labelsSource: Value(r.labels.source),
    imageDescription: Value(r.imageDescription),
    imageSource: Value(r.imageSource?.name),
  );

  static String? _mealsJson(RecipeLabels l) =>
      l.meals == null ? null : jsonEncode(l.meals);

  static RecipeLabels _labelsFromRow(RecipeRow row) {
    List<String>? meals;
    try {
      final decoded = row.mealTypesJson == null
          ? null
          : jsonDecode(row.mealTypesJson!);
      if (decoded is List) meals = [for (final m in decoded) '$m'];
    } on FormatException {
      meals = null;
    }
    return RecipeLabels(
      meals: meals,
      weight: row.weight,
      dishKind: row.dishKind,
      source: row.labelsSource,
    );
  }

  static Recipe? _fromRowOrNull(RecipeRow? row) =>
      row == null ? null : _fromRow(row);

  static Recipe _fromRow(RecipeRow row) => Recipe(
    id: row.id,
    title: row.title,
    servings: row.servings,
    prepMinutes: row.prepMinutes,
    ingredients: _ingredientsFromJson(row.ingredientsJson),
    steps: [
      for (final s in jsonDecode(row.stepsJson) as List<dynamic>) s as String,
    ],
    source: RecipeSource.values.asNameMap()[row.source] ?? RecipeSource.manual,
    imagePath: row.imagePath,
    answeredBy: row.answeredBy,
    createdAt: row.createdAt,
    labels: _labelsFromRow(row),
    imageDescription: row.imageDescription,
    imageSource: RecipeImageSource.tryParse(row.imageSource),
  );

  static List<Ingredient> _ingredientsFromJson(String json) => [
    for (final i in jsonDecode(json) as List<dynamic>)
      Ingredient.fromJson(i as Map<String, dynamic>),
  ];

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
