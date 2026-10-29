// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RecipesTable extends Recipes with TableInfo<$RecipesTable, RecipeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _servingsMeta = const VerificationMeta(
    'servings',
  );
  @override
  late final GeneratedColumn<int> servings = GeneratedColumn<int>(
    'servings',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prepMinutesMeta = const VerificationMeta(
    'prepMinutes',
  );
  @override
  late final GeneratedColumn<int> prepMinutes = GeneratedColumn<int>(
    'prep_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ingredientsJsonMeta = const VerificationMeta(
    'ingredientsJson',
  );
  @override
  late final GeneratedColumn<String> ingredientsJson = GeneratedColumn<String>(
    'ingredients_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepsJsonMeta = const VerificationMeta(
    'stepsJson',
  );
  @override
  late final GeneratedColumn<String> stepsJson = GeneratedColumn<String>(
    'steps_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _answeredByMeta = const VerificationMeta(
    'answeredBy',
  );
  @override
  late final GeneratedColumn<String> answeredBy = GeneratedColumn<String>(
    'answered_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    servings,
    prepMinutes,
    source,
    ingredientsJson,
    stepsJson,
    imagePath,
    answeredBy,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipes';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecipeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('servings')) {
      context.handle(
        _servingsMeta,
        servings.isAcceptableOrUnknown(data['servings']!, _servingsMeta),
      );
    } else if (isInserting) {
      context.missing(_servingsMeta);
    }
    if (data.containsKey('prep_minutes')) {
      context.handle(
        _prepMinutesMeta,
        prepMinutes.isAcceptableOrUnknown(
          data['prep_minutes']!,
          _prepMinutesMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('ingredients_json')) {
      context.handle(
        _ingredientsJsonMeta,
        ingredientsJson.isAcceptableOrUnknown(
          data['ingredients_json']!,
          _ingredientsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ingredientsJsonMeta);
    }
    if (data.containsKey('steps_json')) {
      context.handle(
        _stepsJsonMeta,
        stepsJson.isAcceptableOrUnknown(data['steps_json']!, _stepsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_stepsJsonMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('answered_by')) {
      context.handle(
        _answeredByMeta,
        answeredBy.isAcceptableOrUnknown(data['answered_by']!, _answeredByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecipeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      servings: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}servings'],
      )!,
      prepMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prep_minutes'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      ingredientsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ingredients_json'],
      )!,
      stepsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}steps_json'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      answeredBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answered_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RecipesTable createAlias(String alias) {
    return $RecipesTable(attachedDatabase, alias);
  }
}

class RecipeRow extends DataClass implements Insertable<RecipeRow> {
  final String id;
  final String title;
  final int servings;
  final int? prepMinutes;
  final String source;
  final String ingredientsJson;
  final String stepsJson;
  final String? imagePath;
  final String? answeredBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RecipeRow({
    required this.id,
    required this.title,
    required this.servings,
    this.prepMinutes,
    required this.source,
    required this.ingredientsJson,
    required this.stepsJson,
    this.imagePath,
    this.answeredBy,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['servings'] = Variable<int>(servings);
    if (!nullToAbsent || prepMinutes != null) {
      map['prep_minutes'] = Variable<int>(prepMinutes);
    }
    map['source'] = Variable<String>(source);
    map['ingredients_json'] = Variable<String>(ingredientsJson);
    map['steps_json'] = Variable<String>(stepsJson);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    if (!nullToAbsent || answeredBy != null) {
      map['answered_by'] = Variable<String>(answeredBy);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RecipesCompanion toCompanion(bool nullToAbsent) {
    return RecipesCompanion(
      id: Value(id),
      title: Value(title),
      servings: Value(servings),
      prepMinutes: prepMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(prepMinutes),
      source: Value(source),
      ingredientsJson: Value(ingredientsJson),
      stepsJson: Value(stepsJson),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      answeredBy: answeredBy == null && nullToAbsent
          ? const Value.absent()
          : Value(answeredBy),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RecipeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      servings: serializer.fromJson<int>(json['servings']),
      prepMinutes: serializer.fromJson<int?>(json['prepMinutes']),
      source: serializer.fromJson<String>(json['source']),
      ingredientsJson: serializer.fromJson<String>(json['ingredientsJson']),
      stepsJson: serializer.fromJson<String>(json['stepsJson']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      answeredBy: serializer.fromJson<String?>(json['answeredBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'servings': serializer.toJson<int>(servings),
      'prepMinutes': serializer.toJson<int?>(prepMinutes),
      'source': serializer.toJson<String>(source),
      'ingredientsJson': serializer.toJson<String>(ingredientsJson),
      'stepsJson': serializer.toJson<String>(stepsJson),
      'imagePath': serializer.toJson<String?>(imagePath),
      'answeredBy': serializer.toJson<String?>(answeredBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RecipeRow copyWith({
    String? id,
    String? title,
    int? servings,
    Value<int?> prepMinutes = const Value.absent(),
    String? source,
    String? ingredientsJson,
    String? stepsJson,
    Value<String?> imagePath = const Value.absent(),
    Value<String?> answeredBy = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RecipeRow(
    id: id ?? this.id,
    title: title ?? this.title,
    servings: servings ?? this.servings,
    prepMinutes: prepMinutes.present ? prepMinutes.value : this.prepMinutes,
    source: source ?? this.source,
    ingredientsJson: ingredientsJson ?? this.ingredientsJson,
    stepsJson: stepsJson ?? this.stepsJson,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    answeredBy: answeredBy.present ? answeredBy.value : this.answeredBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RecipeRow copyWithCompanion(RecipesCompanion data) {
    return RecipeRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      servings: data.servings.present ? data.servings.value : this.servings,
      prepMinutes: data.prepMinutes.present
          ? data.prepMinutes.value
          : this.prepMinutes,
      source: data.source.present ? data.source.value : this.source,
      ingredientsJson: data.ingredientsJson.present
          ? data.ingredientsJson.value
          : this.ingredientsJson,
      stepsJson: data.stepsJson.present ? data.stepsJson.value : this.stepsJson,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      answeredBy: data.answeredBy.present
          ? data.answeredBy.value
          : this.answeredBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('servings: $servings, ')
          ..write('prepMinutes: $prepMinutes, ')
          ..write('source: $source, ')
          ..write('ingredientsJson: $ingredientsJson, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('imagePath: $imagePath, ')
          ..write('answeredBy: $answeredBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    servings,
    prepMinutes,
    source,
    ingredientsJson,
    stepsJson,
    imagePath,
    answeredBy,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.servings == this.servings &&
          other.prepMinutes == this.prepMinutes &&
          other.source == this.source &&
          other.ingredientsJson == this.ingredientsJson &&
          other.stepsJson == this.stepsJson &&
          other.imagePath == this.imagePath &&
          other.answeredBy == this.answeredBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RecipesCompanion extends UpdateCompanion<RecipeRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> servings;
  final Value<int?> prepMinutes;
  final Value<String> source;
  final Value<String> ingredientsJson;
  final Value<String> stepsJson;
  final Value<String?> imagePath;
  final Value<String?> answeredBy;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RecipesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.servings = const Value.absent(),
    this.prepMinutes = const Value.absent(),
    this.source = const Value.absent(),
    this.ingredientsJson = const Value.absent(),
    this.stepsJson = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.answeredBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipesCompanion.insert({
    required String id,
    required String title,
    required int servings,
    this.prepMinutes = const Value.absent(),
    required String source,
    required String ingredientsJson,
    required String stepsJson,
    this.imagePath = const Value.absent(),
    this.answeredBy = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       servings = Value(servings),
       source = Value(source),
       ingredientsJson = Value(ingredientsJson),
       stepsJson = Value(stepsJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RecipeRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? servings,
    Expression<int>? prepMinutes,
    Expression<String>? source,
    Expression<String>? ingredientsJson,
    Expression<String>? stepsJson,
    Expression<String>? imagePath,
    Expression<String>? answeredBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (servings != null) 'servings': servings,
      if (prepMinutes != null) 'prep_minutes': prepMinutes,
      if (source != null) 'source': source,
      if (ingredientsJson != null) 'ingredients_json': ingredientsJson,
      if (stepsJson != null) 'steps_json': stepsJson,
      if (imagePath != null) 'image_path': imagePath,
      if (answeredBy != null) 'answered_by': answeredBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<int>? servings,
    Value<int?>? prepMinutes,
    Value<String>? source,
    Value<String>? ingredientsJson,
    Value<String>? stepsJson,
    Value<String?>? imagePath,
    Value<String?>? answeredBy,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RecipesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      servings: servings ?? this.servings,
      prepMinutes: prepMinutes ?? this.prepMinutes,
      source: source ?? this.source,
      ingredientsJson: ingredientsJson ?? this.ingredientsJson,
      stepsJson: stepsJson ?? this.stepsJson,
      imagePath: imagePath ?? this.imagePath,
      answeredBy: answeredBy ?? this.answeredBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (servings.present) {
      map['servings'] = Variable<int>(servings.value);
    }
    if (prepMinutes.present) {
      map['prep_minutes'] = Variable<int>(prepMinutes.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (ingredientsJson.present) {
      map['ingredients_json'] = Variable<String>(ingredientsJson.value);
    }
    if (stepsJson.present) {
      map['steps_json'] = Variable<String>(stepsJson.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (answeredBy.present) {
      map['answered_by'] = Variable<String>(answeredBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('servings: $servings, ')
          ..write('prepMinutes: $prepMinutes, ')
          ..write('source: $source, ')
          ..write('ingredientsJson: $ingredientsJson, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('imagePath: $imagePath, ')
          ..write('answeredBy: $answeredBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipeVersionsTable extends RecipeVersions
    with TableInfo<$RecipeVersionsTable, RecipeVersionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipeVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recipeIdMeta = const VerificationMeta(
    'recipeId',
  );
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
    'recipe_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recipes (id)',
    ),
  );
  static const VerificationMeta _recipeJsonMeta = const VerificationMeta(
    'recipeJson',
  );
  @override
  late final GeneratedColumn<String> recipeJson = GeneratedColumn<String>(
    'recipe_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instructionMeta = const VerificationMeta(
    'instruction',
  );
  @override
  late final GeneratedColumn<String> instruction = GeneratedColumn<String>(
    'instruction',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recipeId,
    recipeJson,
    instruction,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipe_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecipeVersionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('recipe_id')) {
      context.handle(
        _recipeIdMeta,
        recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('recipe_json')) {
      context.handle(
        _recipeJsonMeta,
        recipeJson.isAcceptableOrUnknown(data['recipe_json']!, _recipeJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeJsonMeta);
    }
    if (data.containsKey('instruction')) {
      context.handle(
        _instructionMeta,
        instruction.isAcceptableOrUnknown(
          data['instruction']!,
          _instructionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecipeVersionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeVersionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recipeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_id'],
      )!,
      recipeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_json'],
      )!,
      instruction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instruction'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RecipeVersionsTable createAlias(String alias) {
    return $RecipeVersionsTable(attachedDatabase, alias);
  }
}

class RecipeVersionRow extends DataClass
    implements Insertable<RecipeVersionRow> {
  final int id;
  final String recipeId;
  final String recipeJson;
  final String? instruction;
  final DateTime createdAt;
  const RecipeVersionRow({
    required this.id,
    required this.recipeId,
    required this.recipeJson,
    this.instruction,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['recipe_id'] = Variable<String>(recipeId);
    map['recipe_json'] = Variable<String>(recipeJson);
    if (!nullToAbsent || instruction != null) {
      map['instruction'] = Variable<String>(instruction);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RecipeVersionsCompanion toCompanion(bool nullToAbsent) {
    return RecipeVersionsCompanion(
      id: Value(id),
      recipeId: Value(recipeId),
      recipeJson: Value(recipeJson),
      instruction: instruction == null && nullToAbsent
          ? const Value.absent()
          : Value(instruction),
      createdAt: Value(createdAt),
    );
  }

  factory RecipeVersionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeVersionRow(
      id: serializer.fromJson<int>(json['id']),
      recipeId: serializer.fromJson<String>(json['recipeId']),
      recipeJson: serializer.fromJson<String>(json['recipeJson']),
      instruction: serializer.fromJson<String?>(json['instruction']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recipeId': serializer.toJson<String>(recipeId),
      'recipeJson': serializer.toJson<String>(recipeJson),
      'instruction': serializer.toJson<String?>(instruction),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RecipeVersionRow copyWith({
    int? id,
    String? recipeId,
    String? recipeJson,
    Value<String?> instruction = const Value.absent(),
    DateTime? createdAt,
  }) => RecipeVersionRow(
    id: id ?? this.id,
    recipeId: recipeId ?? this.recipeId,
    recipeJson: recipeJson ?? this.recipeJson,
    instruction: instruction.present ? instruction.value : this.instruction,
    createdAt: createdAt ?? this.createdAt,
  );
  RecipeVersionRow copyWithCompanion(RecipeVersionsCompanion data) {
    return RecipeVersionRow(
      id: data.id.present ? data.id.value : this.id,
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      recipeJson: data.recipeJson.present
          ? data.recipeJson.value
          : this.recipeJson,
      instruction: data.instruction.present
          ? data.instruction.value
          : this.instruction,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeVersionRow(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('recipeJson: $recipeJson, ')
          ..write('instruction: $instruction, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, recipeId, recipeJson, instruction, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeVersionRow &&
          other.id == this.id &&
          other.recipeId == this.recipeId &&
          other.recipeJson == this.recipeJson &&
          other.instruction == this.instruction &&
          other.createdAt == this.createdAt);
}

class RecipeVersionsCompanion extends UpdateCompanion<RecipeVersionRow> {
  final Value<int> id;
  final Value<String> recipeId;
  final Value<String> recipeJson;
  final Value<String?> instruction;
  final Value<DateTime> createdAt;
  const RecipeVersionsCompanion({
    this.id = const Value.absent(),
    this.recipeId = const Value.absent(),
    this.recipeJson = const Value.absent(),
    this.instruction = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RecipeVersionsCompanion.insert({
    this.id = const Value.absent(),
    required String recipeId,
    required String recipeJson,
    this.instruction = const Value.absent(),
    required DateTime createdAt,
  }) : recipeId = Value(recipeId),
       recipeJson = Value(recipeJson),
       createdAt = Value(createdAt);
  static Insertable<RecipeVersionRow> custom({
    Expression<int>? id,
    Expression<String>? recipeId,
    Expression<String>? recipeJson,
    Expression<String>? instruction,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recipeId != null) 'recipe_id': recipeId,
      if (recipeJson != null) 'recipe_json': recipeJson,
      if (instruction != null) 'instruction': instruction,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RecipeVersionsCompanion copyWith({
    Value<int>? id,
    Value<String>? recipeId,
    Value<String>? recipeJson,
    Value<String?>? instruction,
    Value<DateTime>? createdAt,
  }) {
    return RecipeVersionsCompanion(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      recipeJson: recipeJson ?? this.recipeJson,
      instruction: instruction ?? this.instruction,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (recipeJson.present) {
      map['recipe_json'] = Variable<String>(recipeJson.value);
    }
    if (instruction.present) {
      map['instruction'] = Variable<String>(instruction.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipeVersionsCompanion(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('recipeJson: $recipeJson, ')
          ..write('instruction: $instruction, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PantryItemsTable extends PantryItems
    with TableInfo<$PantryItemsTable, PantryItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PantryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    quantity,
    unit,
    category,
    addedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pantry_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<PantryItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PantryItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PantryItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
    );
  }

  @override
  $PantryItemsTable createAlias(String alias) {
    return $PantryItemsTable(attachedDatabase, alias);
  }
}

class PantryItemRow extends DataClass implements Insertable<PantryItemRow> {
  final int id;
  final String name;
  final double? quantity;
  final String? unit;
  final String category;
  final DateTime addedAt;
  final DateTime? expiresAt;
  const PantryItemRow({
    required this.id,
    required this.name,
    this.quantity,
    this.unit,
    required this.category,
    required this.addedAt,
    this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<double>(quantity);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    map['category'] = Variable<String>(category);
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    return map;
  }

  PantryItemsCompanion toCompanion(bool nullToAbsent) {
    return PantryItemsCompanion(
      id: Value(id),
      name: Value(name),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      category: Value(category),
      addedAt: Value(addedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
    );
  }

  factory PantryItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PantryItemRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<double?>(json['quantity']),
      unit: serializer.fromJson<String?>(json['unit']),
      category: serializer.fromJson<String>(json['category']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<double?>(quantity),
      'unit': serializer.toJson<String?>(unit),
      'category': serializer.toJson<String>(category),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
    };
  }

  PantryItemRow copyWith({
    int? id,
    String? name,
    Value<double?> quantity = const Value.absent(),
    Value<String?> unit = const Value.absent(),
    String? category,
    DateTime? addedAt,
    Value<DateTime?> expiresAt = const Value.absent(),
  }) => PantryItemRow(
    id: id ?? this.id,
    name: name ?? this.name,
    quantity: quantity.present ? quantity.value : this.quantity,
    unit: unit.present ? unit.value : this.unit,
    category: category ?? this.category,
    addedAt: addedAt ?? this.addedAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
  );
  PantryItemRow copyWithCompanion(PantryItemsCompanion data) {
    return PantryItemRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
      category: data.category.present ? data.category.value : this.category,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PantryItemRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('category: $category, ')
          ..write('addedAt: $addedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, quantity, unit, category, addedAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PantryItemRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.unit == this.unit &&
          other.category == this.category &&
          other.addedAt == this.addedAt &&
          other.expiresAt == this.expiresAt);
}

class PantryItemsCompanion extends UpdateCompanion<PantryItemRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<double?> quantity;
  final Value<String?> unit;
  final Value<String> category;
  final Value<DateTime> addedAt;
  final Value<DateTime?> expiresAt;
  const PantryItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.category = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  PantryItemsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    required String category,
    required DateTime addedAt,
    this.expiresAt = const Value.absent(),
  }) : name = Value(name),
       category = Value(category),
       addedAt = Value(addedAt);
  static Insertable<PantryItemRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? quantity,
    Expression<String>? unit,
    Expression<String>? category,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (category != null) 'category': category,
      if (addedAt != null) 'added_at': addedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  PantryItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double?>? quantity,
    Value<String?>? unit,
    Value<String>? category,
    Value<DateTime>? addedAt,
    Value<DateTime?>? expiresAt,
  }) {
    return PantryItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      addedAt: addedAt ?? this.addedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PantryItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('category: $category, ')
          ..write('addedAt: $addedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

class $ShoppingListsTable extends ShoppingLists
    with TableInfo<$ShoppingListsTable, ShoppingListRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShoppingListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealPlanIdMeta = const VerificationMeta(
    'mealPlanId',
  );
  @override
  late final GeneratedColumn<String> mealPlanId = GeneratedColumn<String>(
    'meal_plan_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weekMeta = const VerificationMeta('week');
  @override
  late final GeneratedColumn<int> week = GeneratedColumn<int>(
    'week',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, mealPlanId, week, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shopping_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShoppingListRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('meal_plan_id')) {
      context.handle(
        _mealPlanIdMeta,
        mealPlanId.isAcceptableOrUnknown(
          data['meal_plan_id']!,
          _mealPlanIdMeta,
        ),
      );
    }
    if (data.containsKey('week')) {
      context.handle(
        _weekMeta,
        week.isAcceptableOrUnknown(data['week']!, _weekMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShoppingListRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShoppingListRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      mealPlanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_plan_id'],
      ),
      week: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}week'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ShoppingListsTable createAlias(String alias) {
    return $ShoppingListsTable(attachedDatabase, alias);
  }
}

class ShoppingListRow extends DataClass implements Insertable<ShoppingListRow> {
  final String id;
  final String name;
  final String? mealPlanId;

  /// Redni broj nedelje kod mesečnog plana (1-5), null inače.
  final int? week;
  final DateTime createdAt;
  const ShoppingListRow({
    required this.id,
    required this.name,
    this.mealPlanId,
    this.week,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || mealPlanId != null) {
      map['meal_plan_id'] = Variable<String>(mealPlanId);
    }
    if (!nullToAbsent || week != null) {
      map['week'] = Variable<int>(week);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ShoppingListsCompanion toCompanion(bool nullToAbsent) {
    return ShoppingListsCompanion(
      id: Value(id),
      name: Value(name),
      mealPlanId: mealPlanId == null && nullToAbsent
          ? const Value.absent()
          : Value(mealPlanId),
      week: week == null && nullToAbsent ? const Value.absent() : Value(week),
      createdAt: Value(createdAt),
    );
  }

  factory ShoppingListRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShoppingListRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      mealPlanId: serializer.fromJson<String?>(json['mealPlanId']),
      week: serializer.fromJson<int?>(json['week']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'mealPlanId': serializer.toJson<String?>(mealPlanId),
      'week': serializer.toJson<int?>(week),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ShoppingListRow copyWith({
    String? id,
    String? name,
    Value<String?> mealPlanId = const Value.absent(),
    Value<int?> week = const Value.absent(),
    DateTime? createdAt,
  }) => ShoppingListRow(
    id: id ?? this.id,
    name: name ?? this.name,
    mealPlanId: mealPlanId.present ? mealPlanId.value : this.mealPlanId,
    week: week.present ? week.value : this.week,
    createdAt: createdAt ?? this.createdAt,
  );
  ShoppingListRow copyWithCompanion(ShoppingListsCompanion data) {
    return ShoppingListRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      mealPlanId: data.mealPlanId.present
          ? data.mealPlanId.value
          : this.mealPlanId,
      week: data.week.present ? data.week.value : this.week,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingListRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('mealPlanId: $mealPlanId, ')
          ..write('week: $week, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, mealPlanId, week, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShoppingListRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.mealPlanId == this.mealPlanId &&
          other.week == this.week &&
          other.createdAt == this.createdAt);
}

class ShoppingListsCompanion extends UpdateCompanion<ShoppingListRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> mealPlanId;
  final Value<int?> week;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ShoppingListsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.mealPlanId = const Value.absent(),
    this.week = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShoppingListsCompanion.insert({
    required String id,
    required String name,
    this.mealPlanId = const Value.absent(),
    this.week = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<ShoppingListRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? mealPlanId,
    Expression<int>? week,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (mealPlanId != null) 'meal_plan_id': mealPlanId,
      if (week != null) 'week': week,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShoppingListsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? mealPlanId,
    Value<int?>? week,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ShoppingListsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      mealPlanId: mealPlanId ?? this.mealPlanId,
      week: week ?? this.week,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mealPlanId.present) {
      map['meal_plan_id'] = Variable<String>(mealPlanId.value);
    }
    if (week.present) {
      map['week'] = Variable<int>(week.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingListsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('mealPlanId: $mealPlanId, ')
          ..write('week: $week, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShoppingItemsTable extends ShoppingItems
    with TableInfo<$ShoppingItemsTable, ShoppingItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShoppingItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shopping_lists (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isBoughtMeta = const VerificationMeta(
    'isBought',
  );
  @override
  late final GeneratedColumn<bool> isBought = GeneratedColumn<bool>(
    'is_bought',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_bought" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isManualMeta = const VerificationMeta(
    'isManual',
  );
  @override
  late final GeneratedColumn<bool> isManual = GeneratedColumn<bool>(
    'is_manual',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_manual" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _fromRecipeIdsJsonMeta = const VerificationMeta(
    'fromRecipeIdsJson',
  );
  @override
  late final GeneratedColumn<String> fromRecipeIdsJson =
      GeneratedColumn<String>(
        'from_recipe_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    listId,
    name,
    quantity,
    unit,
    category,
    isBought,
    isManual,
    fromRecipeIdsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shopping_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShoppingItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('is_bought')) {
      context.handle(
        _isBoughtMeta,
        isBought.isAcceptableOrUnknown(data['is_bought']!, _isBoughtMeta),
      );
    }
    if (data.containsKey('is_manual')) {
      context.handle(
        _isManualMeta,
        isManual.isAcceptableOrUnknown(data['is_manual']!, _isManualMeta),
      );
    }
    if (data.containsKey('from_recipe_ids_json')) {
      context.handle(
        _fromRecipeIdsJsonMeta,
        fromRecipeIdsJson.isAcceptableOrUnknown(
          data['from_recipe_ids_json']!,
          _fromRecipeIdsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShoppingItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShoppingItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      isBought: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_bought'],
      )!,
      isManual: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_manual'],
      )!,
      fromRecipeIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_recipe_ids_json'],
      )!,
    );
  }

  @override
  $ShoppingItemsTable createAlias(String alias) {
    return $ShoppingItemsTable(attachedDatabase, alias);
  }
}

class ShoppingItemRow extends DataClass implements Insertable<ShoppingItemRow> {
  final int id;
  final String listId;
  final String name;
  final double? quantity;
  final String? unit;
  final String category;
  final bool isBought;
  final bool isManual;
  final String fromRecipeIdsJson;
  const ShoppingItemRow({
    required this.id,
    required this.listId,
    required this.name,
    this.quantity,
    this.unit,
    required this.category,
    required this.isBought,
    required this.isManual,
    required this.fromRecipeIdsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['list_id'] = Variable<String>(listId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<double>(quantity);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    map['category'] = Variable<String>(category);
    map['is_bought'] = Variable<bool>(isBought);
    map['is_manual'] = Variable<bool>(isManual);
    map['from_recipe_ids_json'] = Variable<String>(fromRecipeIdsJson);
    return map;
  }

  ShoppingItemsCompanion toCompanion(bool nullToAbsent) {
    return ShoppingItemsCompanion(
      id: Value(id),
      listId: Value(listId),
      name: Value(name),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      category: Value(category),
      isBought: Value(isBought),
      isManual: Value(isManual),
      fromRecipeIdsJson: Value(fromRecipeIdsJson),
    );
  }

  factory ShoppingItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShoppingItemRow(
      id: serializer.fromJson<int>(json['id']),
      listId: serializer.fromJson<String>(json['listId']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<double?>(json['quantity']),
      unit: serializer.fromJson<String?>(json['unit']),
      category: serializer.fromJson<String>(json['category']),
      isBought: serializer.fromJson<bool>(json['isBought']),
      isManual: serializer.fromJson<bool>(json['isManual']),
      fromRecipeIdsJson: serializer.fromJson<String>(json['fromRecipeIdsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'listId': serializer.toJson<String>(listId),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<double?>(quantity),
      'unit': serializer.toJson<String?>(unit),
      'category': serializer.toJson<String>(category),
      'isBought': serializer.toJson<bool>(isBought),
      'isManual': serializer.toJson<bool>(isManual),
      'fromRecipeIdsJson': serializer.toJson<String>(fromRecipeIdsJson),
    };
  }

  ShoppingItemRow copyWith({
    int? id,
    String? listId,
    String? name,
    Value<double?> quantity = const Value.absent(),
    Value<String?> unit = const Value.absent(),
    String? category,
    bool? isBought,
    bool? isManual,
    String? fromRecipeIdsJson,
  }) => ShoppingItemRow(
    id: id ?? this.id,
    listId: listId ?? this.listId,
    name: name ?? this.name,
    quantity: quantity.present ? quantity.value : this.quantity,
    unit: unit.present ? unit.value : this.unit,
    category: category ?? this.category,
    isBought: isBought ?? this.isBought,
    isManual: isManual ?? this.isManual,
    fromRecipeIdsJson: fromRecipeIdsJson ?? this.fromRecipeIdsJson,
  );
  ShoppingItemRow copyWithCompanion(ShoppingItemsCompanion data) {
    return ShoppingItemRow(
      id: data.id.present ? data.id.value : this.id,
      listId: data.listId.present ? data.listId.value : this.listId,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
      category: data.category.present ? data.category.value : this.category,
      isBought: data.isBought.present ? data.isBought.value : this.isBought,
      isManual: data.isManual.present ? data.isManual.value : this.isManual,
      fromRecipeIdsJson: data.fromRecipeIdsJson.present
          ? data.fromRecipeIdsJson.value
          : this.fromRecipeIdsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingItemRow(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('category: $category, ')
          ..write('isBought: $isBought, ')
          ..write('isManual: $isManual, ')
          ..write('fromRecipeIdsJson: $fromRecipeIdsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    listId,
    name,
    quantity,
    unit,
    category,
    isBought,
    isManual,
    fromRecipeIdsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShoppingItemRow &&
          other.id == this.id &&
          other.listId == this.listId &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.unit == this.unit &&
          other.category == this.category &&
          other.isBought == this.isBought &&
          other.isManual == this.isManual &&
          other.fromRecipeIdsJson == this.fromRecipeIdsJson);
}

class ShoppingItemsCompanion extends UpdateCompanion<ShoppingItemRow> {
  final Value<int> id;
  final Value<String> listId;
  final Value<String> name;
  final Value<double?> quantity;
  final Value<String?> unit;
  final Value<String> category;
  final Value<bool> isBought;
  final Value<bool> isManual;
  final Value<String> fromRecipeIdsJson;
  const ShoppingItemsCompanion({
    this.id = const Value.absent(),
    this.listId = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.category = const Value.absent(),
    this.isBought = const Value.absent(),
    this.isManual = const Value.absent(),
    this.fromRecipeIdsJson = const Value.absent(),
  });
  ShoppingItemsCompanion.insert({
    this.id = const Value.absent(),
    required String listId,
    required String name,
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    required String category,
    this.isBought = const Value.absent(),
    this.isManual = const Value.absent(),
    this.fromRecipeIdsJson = const Value.absent(),
  }) : listId = Value(listId),
       name = Value(name),
       category = Value(category);
  static Insertable<ShoppingItemRow> custom({
    Expression<int>? id,
    Expression<String>? listId,
    Expression<String>? name,
    Expression<double>? quantity,
    Expression<String>? unit,
    Expression<String>? category,
    Expression<bool>? isBought,
    Expression<bool>? isManual,
    Expression<String>? fromRecipeIdsJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (listId != null) 'list_id': listId,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (category != null) 'category': category,
      if (isBought != null) 'is_bought': isBought,
      if (isManual != null) 'is_manual': isManual,
      if (fromRecipeIdsJson != null) 'from_recipe_ids_json': fromRecipeIdsJson,
    });
  }

  ShoppingItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? listId,
    Value<String>? name,
    Value<double?>? quantity,
    Value<String?>? unit,
    Value<String>? category,
    Value<bool>? isBought,
    Value<bool>? isManual,
    Value<String>? fromRecipeIdsJson,
  }) {
    return ShoppingItemsCompanion(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      isBought: isBought ?? this.isBought,
      isManual: isManual ?? this.isManual,
      fromRecipeIdsJson: fromRecipeIdsJson ?? this.fromRecipeIdsJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (isBought.present) {
      map['is_bought'] = Variable<bool>(isBought.value);
    }
    if (isManual.present) {
      map['is_manual'] = Variable<bool>(isManual.value);
    }
    if (fromRecipeIdsJson.present) {
      map['from_recipe_ids_json'] = Variable<String>(fromRecipeIdsJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingItemsCompanion(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('category: $category, ')
          ..write('isBought: $isBought, ')
          ..write('isManual: $isManual, ')
          ..write('fromRecipeIdsJson: $fromRecipeIdsJson')
          ..write(')'))
        .toString();
  }
}

class $MealPlansTable extends MealPlans
    with TableInfo<$MealPlansTable, MealPlanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealTypesJsonMeta = const VerificationMeta(
    'mealTypesJson',
  );
  @override
  late final GeneratedColumn<String> mealTypesJson = GeneratedColumn<String>(
    'meal_types_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usePantryMeta = const VerificationMeta(
    'usePantry',
  );
  @override
  late final GeneratedColumn<bool> usePantry = GeneratedColumn<bool>(
    'use_pantry',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_pantry" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startDate,
    endDate,
    mealTypesJson,
    usePantry,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealPlanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('meal_types_json')) {
      context.handle(
        _mealTypesJsonMeta,
        mealTypesJson.isAcceptableOrUnknown(
          data['meal_types_json']!,
          _mealTypesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mealTypesJsonMeta);
    }
    if (data.containsKey('use_pantry')) {
      context.handle(
        _usePantryMeta,
        usePantry.isAcceptableOrUnknown(data['use_pantry']!, _usePantryMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealPlanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealPlanRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      )!,
      mealTypesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_types_json'],
      )!,
      usePantry: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_pantry'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MealPlansTable createAlias(String alias) {
    return $MealPlansTable(attachedDatabase, alias);
  }
}

class MealPlanRow extends DataClass implements Insertable<MealPlanRow> {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final String mealTypesJson;
  final bool usePantry;
  final DateTime createdAt;
  const MealPlanRow({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.mealTypesJson,
    required this.usePantry,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    map['meal_types_json'] = Variable<String>(mealTypesJson);
    map['use_pantry'] = Variable<bool>(usePantry);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MealPlansCompanion toCompanion(bool nullToAbsent) {
    return MealPlansCompanion(
      id: Value(id),
      startDate: Value(startDate),
      endDate: Value(endDate),
      mealTypesJson: Value(mealTypesJson),
      usePantry: Value(usePantry),
      createdAt: Value(createdAt),
    );
  }

  factory MealPlanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealPlanRow(
      id: serializer.fromJson<String>(json['id']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      mealTypesJson: serializer.fromJson<String>(json['mealTypesJson']),
      usePantry: serializer.fromJson<bool>(json['usePantry']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'mealTypesJson': serializer.toJson<String>(mealTypesJson),
      'usePantry': serializer.toJson<bool>(usePantry),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MealPlanRow copyWith({
    String? id,
    DateTime? startDate,
    DateTime? endDate,
    String? mealTypesJson,
    bool? usePantry,
    DateTime? createdAt,
  }) => MealPlanRow(
    id: id ?? this.id,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    mealTypesJson: mealTypesJson ?? this.mealTypesJson,
    usePantry: usePantry ?? this.usePantry,
    createdAt: createdAt ?? this.createdAt,
  );
  MealPlanRow copyWithCompanion(MealPlansCompanion data) {
    return MealPlanRow(
      id: data.id.present ? data.id.value : this.id,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      mealTypesJson: data.mealTypesJson.present
          ? data.mealTypesJson.value
          : this.mealTypesJson,
      usePantry: data.usePantry.present ? data.usePantry.value : this.usePantry,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealPlanRow(')
          ..write('id: $id, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('mealTypesJson: $mealTypesJson, ')
          ..write('usePantry: $usePantry, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, startDate, endDate, mealTypesJson, usePantry, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealPlanRow &&
          other.id == this.id &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.mealTypesJson == this.mealTypesJson &&
          other.usePantry == this.usePantry &&
          other.createdAt == this.createdAt);
}

class MealPlansCompanion extends UpdateCompanion<MealPlanRow> {
  final Value<String> id;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<String> mealTypesJson;
  final Value<bool> usePantry;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MealPlansCompanion({
    this.id = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.mealTypesJson = const Value.absent(),
    this.usePantry = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MealPlansCompanion.insert({
    required String id,
    required DateTime startDate,
    required DateTime endDate,
    required String mealTypesJson,
    this.usePantry = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startDate = Value(startDate),
       endDate = Value(endDate),
       mealTypesJson = Value(mealTypesJson),
       createdAt = Value(createdAt);
  static Insertable<MealPlanRow> custom({
    Expression<String>? id,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<String>? mealTypesJson,
    Expression<bool>? usePantry,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (mealTypesJson != null) 'meal_types_json': mealTypesJson,
      if (usePantry != null) 'use_pantry': usePantry,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MealPlansCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? startDate,
    Value<DateTime>? endDate,
    Value<String>? mealTypesJson,
    Value<bool>? usePantry,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MealPlansCompanion(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      mealTypesJson: mealTypesJson ?? this.mealTypesJson,
      usePantry: usePantry ?? this.usePantry,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (mealTypesJson.present) {
      map['meal_types_json'] = Variable<String>(mealTypesJson.value);
    }
    if (usePantry.present) {
      map['use_pantry'] = Variable<bool>(usePantry.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealPlansCompanion(')
          ..write('id: $id, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('mealTypesJson: $mealTypesJson, ')
          ..write('usePantry: $usePantry, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MealPlanEntriesTable extends MealPlanEntries
    with TableInfo<$MealPlanEntriesTable, MealPlanEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealPlanEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meal_plans (id)',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealTypeMeta = const VerificationMeta(
    'mealType',
  );
  @override
  late final GeneratedColumn<String> mealType = GeneratedColumn<String>(
    'meal_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipeIdMeta = const VerificationMeta(
    'recipeId',
  );
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
    'recipe_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recipes (id)',
    ),
  );
  static const VerificationMeta _isLockedMeta = const VerificationMeta(
    'isLocked',
  );
  @override
  late final GeneratedColumn<bool> isLocked = GeneratedColumn<bool>(
    'is_locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isCookedMeta = const VerificationMeta(
    'isCooked',
  );
  @override
  late final GeneratedColumn<bool> isCooked = GeneratedColumn<bool>(
    'is_cooked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_cooked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    planId,
    date,
    mealType,
    recipeId,
    isLocked,
    isCooked,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_plan_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealPlanEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('meal_type')) {
      context.handle(
        _mealTypeMeta,
        mealType.isAcceptableOrUnknown(data['meal_type']!, _mealTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mealTypeMeta);
    }
    if (data.containsKey('recipe_id')) {
      context.handle(
        _recipeIdMeta,
        recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta),
      );
    }
    if (data.containsKey('is_locked')) {
      context.handle(
        _isLockedMeta,
        isLocked.isAcceptableOrUnknown(data['is_locked']!, _isLockedMeta),
      );
    }
    if (data.containsKey('is_cooked')) {
      context.handle(
        _isCookedMeta,
        isCooked.isAcceptableOrUnknown(data['is_cooked']!, _isCookedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealPlanEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealPlanEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      mealType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_type'],
      )!,
      recipeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_id'],
      ),
      isLocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_locked'],
      )!,
      isCooked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_cooked'],
      )!,
    );
  }

  @override
  $MealPlanEntriesTable createAlias(String alias) {
    return $MealPlanEntriesTable(attachedDatabase, alias);
  }
}

class MealPlanEntryRow extends DataClass
    implements Insertable<MealPlanEntryRow> {
  final int id;
  final String planId;
  final DateTime date;
  final String mealType;
  final String? recipeId;
  final bool isLocked;
  final bool isCooked;
  const MealPlanEntryRow({
    required this.id,
    required this.planId,
    required this.date,
    required this.mealType,
    this.recipeId,
    required this.isLocked,
    required this.isCooked,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['plan_id'] = Variable<String>(planId);
    map['date'] = Variable<DateTime>(date);
    map['meal_type'] = Variable<String>(mealType);
    if (!nullToAbsent || recipeId != null) {
      map['recipe_id'] = Variable<String>(recipeId);
    }
    map['is_locked'] = Variable<bool>(isLocked);
    map['is_cooked'] = Variable<bool>(isCooked);
    return map;
  }

  MealPlanEntriesCompanion toCompanion(bool nullToAbsent) {
    return MealPlanEntriesCompanion(
      id: Value(id),
      planId: Value(planId),
      date: Value(date),
      mealType: Value(mealType),
      recipeId: recipeId == null && nullToAbsent
          ? const Value.absent()
          : Value(recipeId),
      isLocked: Value(isLocked),
      isCooked: Value(isCooked),
    );
  }

  factory MealPlanEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealPlanEntryRow(
      id: serializer.fromJson<int>(json['id']),
      planId: serializer.fromJson<String>(json['planId']),
      date: serializer.fromJson<DateTime>(json['date']),
      mealType: serializer.fromJson<String>(json['mealType']),
      recipeId: serializer.fromJson<String?>(json['recipeId']),
      isLocked: serializer.fromJson<bool>(json['isLocked']),
      isCooked: serializer.fromJson<bool>(json['isCooked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'planId': serializer.toJson<String>(planId),
      'date': serializer.toJson<DateTime>(date),
      'mealType': serializer.toJson<String>(mealType),
      'recipeId': serializer.toJson<String?>(recipeId),
      'isLocked': serializer.toJson<bool>(isLocked),
      'isCooked': serializer.toJson<bool>(isCooked),
    };
  }

  MealPlanEntryRow copyWith({
    int? id,
    String? planId,
    DateTime? date,
    String? mealType,
    Value<String?> recipeId = const Value.absent(),
    bool? isLocked,
    bool? isCooked,
  }) => MealPlanEntryRow(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    date: date ?? this.date,
    mealType: mealType ?? this.mealType,
    recipeId: recipeId.present ? recipeId.value : this.recipeId,
    isLocked: isLocked ?? this.isLocked,
    isCooked: isCooked ?? this.isCooked,
  );
  MealPlanEntryRow copyWithCompanion(MealPlanEntriesCompanion data) {
    return MealPlanEntryRow(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      date: data.date.present ? data.date.value : this.date,
      mealType: data.mealType.present ? data.mealType.value : this.mealType,
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      isLocked: data.isLocked.present ? data.isLocked.value : this.isLocked,
      isCooked: data.isCooked.present ? data.isCooked.value : this.isCooked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealPlanEntryRow(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('date: $date, ')
          ..write('mealType: $mealType, ')
          ..write('recipeId: $recipeId, ')
          ..write('isLocked: $isLocked, ')
          ..write('isCooked: $isCooked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, planId, date, mealType, recipeId, isLocked, isCooked);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealPlanEntryRow &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.date == this.date &&
          other.mealType == this.mealType &&
          other.recipeId == this.recipeId &&
          other.isLocked == this.isLocked &&
          other.isCooked == this.isCooked);
}

class MealPlanEntriesCompanion extends UpdateCompanion<MealPlanEntryRow> {
  final Value<int> id;
  final Value<String> planId;
  final Value<DateTime> date;
  final Value<String> mealType;
  final Value<String?> recipeId;
  final Value<bool> isLocked;
  final Value<bool> isCooked;
  const MealPlanEntriesCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.date = const Value.absent(),
    this.mealType = const Value.absent(),
    this.recipeId = const Value.absent(),
    this.isLocked = const Value.absent(),
    this.isCooked = const Value.absent(),
  });
  MealPlanEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String planId,
    required DateTime date,
    required String mealType,
    this.recipeId = const Value.absent(),
    this.isLocked = const Value.absent(),
    this.isCooked = const Value.absent(),
  }) : planId = Value(planId),
       date = Value(date),
       mealType = Value(mealType);
  static Insertable<MealPlanEntryRow> custom({
    Expression<int>? id,
    Expression<String>? planId,
    Expression<DateTime>? date,
    Expression<String>? mealType,
    Expression<String>? recipeId,
    Expression<bool>? isLocked,
    Expression<bool>? isCooked,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (date != null) 'date': date,
      if (mealType != null) 'meal_type': mealType,
      if (recipeId != null) 'recipe_id': recipeId,
      if (isLocked != null) 'is_locked': isLocked,
      if (isCooked != null) 'is_cooked': isCooked,
    });
  }

  MealPlanEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? planId,
    Value<DateTime>? date,
    Value<String>? mealType,
    Value<String?>? recipeId,
    Value<bool>? isLocked,
    Value<bool>? isCooked,
  }) {
    return MealPlanEntriesCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      recipeId: recipeId ?? this.recipeId,
      isLocked: isLocked ?? this.isLocked,
      isCooked: isCooked ?? this.isCooked,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (mealType.present) {
      map['meal_type'] = Variable<String>(mealType.value);
    }
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (isLocked.present) {
      map['is_locked'] = Variable<bool>(isLocked.value);
    }
    if (isCooked.present) {
      map['is_cooked'] = Variable<bool>(isCooked.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealPlanEntriesCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('date: $date, ')
          ..write('mealType: $mealType, ')
          ..write('recipeId: $recipeId, ')
          ..write('isLocked: $isLocked, ')
          ..write('isCooked: $isCooked')
          ..write(')'))
        .toString();
  }
}

class $RatingsTable extends Ratings with TableInfo<$RatingsTable, RatingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RatingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recipeIdMeta = const VerificationMeta(
    'recipeId',
  );
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
    'recipe_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recipes (id)',
    ),
  );
  static const VerificationMeta _starsMeta = const VerificationMeta('stars');
  @override
  late final GeneratedColumn<int> stars = GeneratedColumn<int>(
    'stars',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isComfortFoodMeta = const VerificationMeta(
    'isComfortFood',
  );
  @override
  late final GeneratedColumn<bool> isComfortFood = GeneratedColumn<bool>(
    'is_comfort_food',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_comfort_food" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cookedAtMeta = const VerificationMeta(
    'cookedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cookedAt = GeneratedColumn<DateTime>(
    'cooked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recipeId,
    stars,
    isComfortFood,
    comment,
    cookedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ratings';
  @override
  VerificationContext validateIntegrity(
    Insertable<RatingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('recipe_id')) {
      context.handle(
        _recipeIdMeta,
        recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('stars')) {
      context.handle(
        _starsMeta,
        stars.isAcceptableOrUnknown(data['stars']!, _starsMeta),
      );
    } else if (isInserting) {
      context.missing(_starsMeta);
    }
    if (data.containsKey('is_comfort_food')) {
      context.handle(
        _isComfortFoodMeta,
        isComfortFood.isAcceptableOrUnknown(
          data['is_comfort_food']!,
          _isComfortFoodMeta,
        ),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('cooked_at')) {
      context.handle(
        _cookedAtMeta,
        cookedAt.isAcceptableOrUnknown(data['cooked_at']!, _cookedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cookedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RatingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RatingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recipeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_id'],
      )!,
      stars: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stars'],
      )!,
      isComfortFood: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_comfort_food'],
      )!,
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      cookedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cooked_at'],
      )!,
    );
  }

  @override
  $RatingsTable createAlias(String alias) {
    return $RatingsTable(attachedDatabase, alias);
  }
}

class RatingRow extends DataClass implements Insertable<RatingRow> {
  final int id;
  final String recipeId;
  final int stars;
  final bool isComfortFood;
  final String? comment;
  final DateTime cookedAt;
  const RatingRow({
    required this.id,
    required this.recipeId,
    required this.stars,
    required this.isComfortFood,
    this.comment,
    required this.cookedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['recipe_id'] = Variable<String>(recipeId);
    map['stars'] = Variable<int>(stars);
    map['is_comfort_food'] = Variable<bool>(isComfortFood);
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['cooked_at'] = Variable<DateTime>(cookedAt);
    return map;
  }

  RatingsCompanion toCompanion(bool nullToAbsent) {
    return RatingsCompanion(
      id: Value(id),
      recipeId: Value(recipeId),
      stars: Value(stars),
      isComfortFood: Value(isComfortFood),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      cookedAt: Value(cookedAt),
    );
  }

  factory RatingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RatingRow(
      id: serializer.fromJson<int>(json['id']),
      recipeId: serializer.fromJson<String>(json['recipeId']),
      stars: serializer.fromJson<int>(json['stars']),
      isComfortFood: serializer.fromJson<bool>(json['isComfortFood']),
      comment: serializer.fromJson<String?>(json['comment']),
      cookedAt: serializer.fromJson<DateTime>(json['cookedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recipeId': serializer.toJson<String>(recipeId),
      'stars': serializer.toJson<int>(stars),
      'isComfortFood': serializer.toJson<bool>(isComfortFood),
      'comment': serializer.toJson<String?>(comment),
      'cookedAt': serializer.toJson<DateTime>(cookedAt),
    };
  }

  RatingRow copyWith({
    int? id,
    String? recipeId,
    int? stars,
    bool? isComfortFood,
    Value<String?> comment = const Value.absent(),
    DateTime? cookedAt,
  }) => RatingRow(
    id: id ?? this.id,
    recipeId: recipeId ?? this.recipeId,
    stars: stars ?? this.stars,
    isComfortFood: isComfortFood ?? this.isComfortFood,
    comment: comment.present ? comment.value : this.comment,
    cookedAt: cookedAt ?? this.cookedAt,
  );
  RatingRow copyWithCompanion(RatingsCompanion data) {
    return RatingRow(
      id: data.id.present ? data.id.value : this.id,
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      stars: data.stars.present ? data.stars.value : this.stars,
      isComfortFood: data.isComfortFood.present
          ? data.isComfortFood.value
          : this.isComfortFood,
      comment: data.comment.present ? data.comment.value : this.comment,
      cookedAt: data.cookedAt.present ? data.cookedAt.value : this.cookedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RatingRow(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('stars: $stars, ')
          ..write('isComfortFood: $isComfortFood, ')
          ..write('comment: $comment, ')
          ..write('cookedAt: $cookedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, recipeId, stars, isComfortFood, comment, cookedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RatingRow &&
          other.id == this.id &&
          other.recipeId == this.recipeId &&
          other.stars == this.stars &&
          other.isComfortFood == this.isComfortFood &&
          other.comment == this.comment &&
          other.cookedAt == this.cookedAt);
}

class RatingsCompanion extends UpdateCompanion<RatingRow> {
  final Value<int> id;
  final Value<String> recipeId;
  final Value<int> stars;
  final Value<bool> isComfortFood;
  final Value<String?> comment;
  final Value<DateTime> cookedAt;
  const RatingsCompanion({
    this.id = const Value.absent(),
    this.recipeId = const Value.absent(),
    this.stars = const Value.absent(),
    this.isComfortFood = const Value.absent(),
    this.comment = const Value.absent(),
    this.cookedAt = const Value.absent(),
  });
  RatingsCompanion.insert({
    this.id = const Value.absent(),
    required String recipeId,
    required int stars,
    this.isComfortFood = const Value.absent(),
    this.comment = const Value.absent(),
    required DateTime cookedAt,
  }) : recipeId = Value(recipeId),
       stars = Value(stars),
       cookedAt = Value(cookedAt);
  static Insertable<RatingRow> custom({
    Expression<int>? id,
    Expression<String>? recipeId,
    Expression<int>? stars,
    Expression<bool>? isComfortFood,
    Expression<String>? comment,
    Expression<DateTime>? cookedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recipeId != null) 'recipe_id': recipeId,
      if (stars != null) 'stars': stars,
      if (isComfortFood != null) 'is_comfort_food': isComfortFood,
      if (comment != null) 'comment': comment,
      if (cookedAt != null) 'cooked_at': cookedAt,
    });
  }

  RatingsCompanion copyWith({
    Value<int>? id,
    Value<String>? recipeId,
    Value<int>? stars,
    Value<bool>? isComfortFood,
    Value<String?>? comment,
    Value<DateTime>? cookedAt,
  }) {
    return RatingsCompanion(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      stars: stars ?? this.stars,
      isComfortFood: isComfortFood ?? this.isComfortFood,
      comment: comment ?? this.comment,
      cookedAt: cookedAt ?? this.cookedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (stars.present) {
      map['stars'] = Variable<int>(stars.value);
    }
    if (isComfortFood.present) {
      map['is_comfort_food'] = Variable<bool>(isComfortFood.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (cookedAt.present) {
      map['cooked_at'] = Variable<DateTime>(cookedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RatingsCompanion(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('stars: $stars, ')
          ..write('isComfortFood: $isComfortFood, ')
          ..write('comment: $comment, ')
          ..write('cookedAt: $cookedAt')
          ..write(')'))
        .toString();
  }
}

class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _profileJsonMeta = const VerificationMeta(
    'profileJson',
  );
  @override
  late final GeneratedColumn<String> profileJson = GeneratedColumn<String>(
    'profile_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, profileJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_json')) {
      context.handle(
        _profileJsonMeta,
        profileJson.isAcceptableOrUnknown(
          data['profile_json']!,
          _profileJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_profileJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_json'],
      )!,
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }
}

class UserProfileRow extends DataClass implements Insertable<UserProfileRow> {
  final int id;
  final String profileJson;
  const UserProfileRow({required this.id, required this.profileJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_json'] = Variable<String>(profileJson);
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      id: Value(id),
      profileJson: Value(profileJson),
    );
  }

  factory UserProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileRow(
      id: serializer.fromJson<int>(json['id']),
      profileJson: serializer.fromJson<String>(json['profileJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileJson': serializer.toJson<String>(profileJson),
    };
  }

  UserProfileRow copyWith({int? id, String? profileJson}) => UserProfileRow(
    id: id ?? this.id,
    profileJson: profileJson ?? this.profileJson,
  );
  UserProfileRow copyWithCompanion(UserProfilesCompanion data) {
    return UserProfileRow(
      id: data.id.present ? data.id.value : this.id,
      profileJson: data.profileJson.present
          ? data.profileJson.value
          : this.profileJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileRow(')
          ..write('id: $id, ')
          ..write('profileJson: $profileJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, profileJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileRow &&
          other.id == this.id &&
          other.profileJson == this.profileJson);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfileRow> {
  final Value<int> id;
  final Value<String> profileJson;
  const UserProfilesCompanion({
    this.id = const Value.absent(),
    this.profileJson = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String profileJson,
  }) : profileJson = Value(profileJson);
  static Insertable<UserProfileRow> custom({
    Expression<int>? id,
    Expression<String>? profileJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileJson != null) 'profile_json': profileJson,
    });
  }

  UserProfilesCompanion copyWith({Value<int>? id, Value<String>? profileJson}) {
    return UserProfilesCompanion(
      id: id ?? this.id,
      profileJson: profileJson ?? this.profileJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileJson.present) {
      map['profile_json'] = Variable<String>(profileJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('profileJson: $profileJson')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingRow extends DataClass implements Insertable<AppSettingRow> {
  final String key;
  final String value;
  const AppSettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSettingRow copyWith({String? key, String? value}) =>
      AppSettingRow(key: key ?? this.key, value: value ?? this.value);
  AppSettingRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelStatusesTable extends ModelStatuses
    with TableInfo<$ModelStatusesTable, ModelStatusRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelStatusesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyOriginMeta = const VerificationMeta(
    'keyOrigin',
  );
  @override
  late final GeneratedColumn<String> keyOrigin = GeneratedColumn<String>(
    'key_origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('user'),
  );
  static const VerificationMeta _blockedUntilMeta = const VerificationMeta(
    'blockedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> blockedUntil = GeneratedColumn<DateTime>(
    'blocked_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestsTodayMeta = const VerificationMeta(
    'requestsToday',
  );
  @override
  late final GeneratedColumn<int> requestsToday = GeneratedColumn<int>(
    'requests_today',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _usageDayMeta = const VerificationMeta(
    'usageDay',
  );
  @override
  late final GeneratedColumn<String> usageDay = GeneratedColumn<String>(
    'usage_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    provider,
    model,
    keyOrigin,
    blockedUntil,
    requestsToday,
    usageDay,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_statuses';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModelStatusRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('key_origin')) {
      context.handle(
        _keyOriginMeta,
        keyOrigin.isAcceptableOrUnknown(data['key_origin']!, _keyOriginMeta),
      );
    }
    if (data.containsKey('blocked_until')) {
      context.handle(
        _blockedUntilMeta,
        blockedUntil.isAcceptableOrUnknown(
          data['blocked_until']!,
          _blockedUntilMeta,
        ),
      );
    }
    if (data.containsKey('requests_today')) {
      context.handle(
        _requestsTodayMeta,
        requestsToday.isAcceptableOrUnknown(
          data['requests_today']!,
          _requestsTodayMeta,
        ),
      );
    }
    if (data.containsKey('usage_day')) {
      context.handle(
        _usageDayMeta,
        usageDay.isAcceptableOrUnknown(data['usage_day']!, _usageDayMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {provider, model, keyOrigin};
  @override
  ModelStatusRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelStatusRow(
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      keyOrigin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_origin'],
      )!,
      blockedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}blocked_until'],
      ),
      requestsToday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}requests_today'],
      )!,
      usageDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}usage_day'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $ModelStatusesTable createAlias(String alias) {
    return $ModelStatusesTable(attachedDatabase, alias);
  }
}

class ModelStatusRow extends DataClass implements Insertable<ModelStatusRow> {
  final String provider;
  final String model;

  /// KeyOrigin.name: limiti važe posebno za svaki ključ.
  final String keyOrigin;
  final DateTime? blockedUntil;
  final int requestsToday;
  final String? usageDay;
  final String? lastError;
  const ModelStatusRow({
    required this.provider,
    required this.model,
    required this.keyOrigin,
    this.blockedUntil,
    required this.requestsToday,
    this.usageDay,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['provider'] = Variable<String>(provider);
    map['model'] = Variable<String>(model);
    map['key_origin'] = Variable<String>(keyOrigin);
    if (!nullToAbsent || blockedUntil != null) {
      map['blocked_until'] = Variable<DateTime>(blockedUntil);
    }
    map['requests_today'] = Variable<int>(requestsToday);
    if (!nullToAbsent || usageDay != null) {
      map['usage_day'] = Variable<String>(usageDay);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  ModelStatusesCompanion toCompanion(bool nullToAbsent) {
    return ModelStatusesCompanion(
      provider: Value(provider),
      model: Value(model),
      keyOrigin: Value(keyOrigin),
      blockedUntil: blockedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(blockedUntil),
      requestsToday: Value(requestsToday),
      usageDay: usageDay == null && nullToAbsent
          ? const Value.absent()
          : Value(usageDay),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory ModelStatusRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelStatusRow(
      provider: serializer.fromJson<String>(json['provider']),
      model: serializer.fromJson<String>(json['model']),
      keyOrigin: serializer.fromJson<String>(json['keyOrigin']),
      blockedUntil: serializer.fromJson<DateTime?>(json['blockedUntil']),
      requestsToday: serializer.fromJson<int>(json['requestsToday']),
      usageDay: serializer.fromJson<String?>(json['usageDay']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'provider': serializer.toJson<String>(provider),
      'model': serializer.toJson<String>(model),
      'keyOrigin': serializer.toJson<String>(keyOrigin),
      'blockedUntil': serializer.toJson<DateTime?>(blockedUntil),
      'requestsToday': serializer.toJson<int>(requestsToday),
      'usageDay': serializer.toJson<String?>(usageDay),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  ModelStatusRow copyWith({
    String? provider,
    String? model,
    String? keyOrigin,
    Value<DateTime?> blockedUntil = const Value.absent(),
    int? requestsToday,
    Value<String?> usageDay = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => ModelStatusRow(
    provider: provider ?? this.provider,
    model: model ?? this.model,
    keyOrigin: keyOrigin ?? this.keyOrigin,
    blockedUntil: blockedUntil.present ? blockedUntil.value : this.blockedUntil,
    requestsToday: requestsToday ?? this.requestsToday,
    usageDay: usageDay.present ? usageDay.value : this.usageDay,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  ModelStatusRow copyWithCompanion(ModelStatusesCompanion data) {
    return ModelStatusRow(
      provider: data.provider.present ? data.provider.value : this.provider,
      model: data.model.present ? data.model.value : this.model,
      keyOrigin: data.keyOrigin.present ? data.keyOrigin.value : this.keyOrigin,
      blockedUntil: data.blockedUntil.present
          ? data.blockedUntil.value
          : this.blockedUntil,
      requestsToday: data.requestsToday.present
          ? data.requestsToday.value
          : this.requestsToday,
      usageDay: data.usageDay.present ? data.usageDay.value : this.usageDay,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelStatusRow(')
          ..write('provider: $provider, ')
          ..write('model: $model, ')
          ..write('keyOrigin: $keyOrigin, ')
          ..write('blockedUntil: $blockedUntil, ')
          ..write('requestsToday: $requestsToday, ')
          ..write('usageDay: $usageDay, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    provider,
    model,
    keyOrigin,
    blockedUntil,
    requestsToday,
    usageDay,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelStatusRow &&
          other.provider == this.provider &&
          other.model == this.model &&
          other.keyOrigin == this.keyOrigin &&
          other.blockedUntil == this.blockedUntil &&
          other.requestsToday == this.requestsToday &&
          other.usageDay == this.usageDay &&
          other.lastError == this.lastError);
}

class ModelStatusesCompanion extends UpdateCompanion<ModelStatusRow> {
  final Value<String> provider;
  final Value<String> model;
  final Value<String> keyOrigin;
  final Value<DateTime?> blockedUntil;
  final Value<int> requestsToday;
  final Value<String?> usageDay;
  final Value<String?> lastError;
  final Value<int> rowid;
  const ModelStatusesCompanion({
    this.provider = const Value.absent(),
    this.model = const Value.absent(),
    this.keyOrigin = const Value.absent(),
    this.blockedUntil = const Value.absent(),
    this.requestsToday = const Value.absent(),
    this.usageDay = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelStatusesCompanion.insert({
    required String provider,
    required String model,
    this.keyOrigin = const Value.absent(),
    this.blockedUntil = const Value.absent(),
    this.requestsToday = const Value.absent(),
    this.usageDay = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : provider = Value(provider),
       model = Value(model);
  static Insertable<ModelStatusRow> custom({
    Expression<String>? provider,
    Expression<String>? model,
    Expression<String>? keyOrigin,
    Expression<DateTime>? blockedUntil,
    Expression<int>? requestsToday,
    Expression<String>? usageDay,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (provider != null) 'provider': provider,
      if (model != null) 'model': model,
      if (keyOrigin != null) 'key_origin': keyOrigin,
      if (blockedUntil != null) 'blocked_until': blockedUntil,
      if (requestsToday != null) 'requests_today': requestsToday,
      if (usageDay != null) 'usage_day': usageDay,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelStatusesCompanion copyWith({
    Value<String>? provider,
    Value<String>? model,
    Value<String>? keyOrigin,
    Value<DateTime?>? blockedUntil,
    Value<int>? requestsToday,
    Value<String?>? usageDay,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return ModelStatusesCompanion(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      keyOrigin: keyOrigin ?? this.keyOrigin,
      blockedUntil: blockedUntil ?? this.blockedUntil,
      requestsToday: requestsToday ?? this.requestsToday,
      usageDay: usageDay ?? this.usageDay,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (keyOrigin.present) {
      map['key_origin'] = Variable<String>(keyOrigin.value);
    }
    if (blockedUntil.present) {
      map['blocked_until'] = Variable<DateTime>(blockedUntil.value);
    }
    if (requestsToday.present) {
      map['requests_today'] = Variable<int>(requestsToday.value);
    }
    if (usageDay.present) {
      map['usage_day'] = Variable<String>(usageDay.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelStatusesCompanion(')
          ..write('provider: $provider, ')
          ..write('model: $model, ')
          ..write('keyOrigin: $keyOrigin, ')
          ..write('blockedUntil: $blockedUntil, ')
          ..write('requestsToday: $requestsToday, ')
          ..write('usageDay: $usageDay, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RecipesTable recipes = $RecipesTable(this);
  late final $RecipeVersionsTable recipeVersions = $RecipeVersionsTable(this);
  late final $PantryItemsTable pantryItems = $PantryItemsTable(this);
  late final $ShoppingListsTable shoppingLists = $ShoppingListsTable(this);
  late final $ShoppingItemsTable shoppingItems = $ShoppingItemsTable(this);
  late final $MealPlansTable mealPlans = $MealPlansTable(this);
  late final $MealPlanEntriesTable mealPlanEntries = $MealPlanEntriesTable(
    this,
  );
  late final $RatingsTable ratings = $RatingsTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $ModelStatusesTable modelStatuses = $ModelStatusesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    recipes,
    recipeVersions,
    pantryItems,
    shoppingLists,
    shoppingItems,
    mealPlans,
    mealPlanEntries,
    ratings,
    userProfiles,
    appSettings,
    modelStatuses,
  ];
}

typedef $$RecipesTableCreateCompanionBuilder = RecipesCompanion Function({
  required String id,
  required String title,
  required int servings,
  Value<int?> prepMinutes,
  required String source,
  required String ingredientsJson,
  required String stepsJson,
  Value<String?> imagePath,
  Value<String?> answeredBy,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$RecipesTableUpdateCompanionBuilder = RecipesCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<int> servings,
  Value<int?> prepMinutes,
  Value<String> source,
  Value<String> ingredientsJson,
  Value<String> stepsJson,
  Value<String?> imagePath,
  Value<String?> answeredBy,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$RecipesTableReferences
    extends BaseReferences<_$AppDatabase, $RecipesTable, RecipeRow> {
  $$RecipesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RecipeVersionsTable, List<RecipeVersionRow>>
  _recipeVersionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recipeVersions,
    aliasName: 'recipes__id__recipe_versions__recipe_id',
  );

  $$RecipeVersionsTableProcessedTableManager get recipeVersionsRefs {
    final manager = $$RecipeVersionsTableTableManager(
      $_db,
      $_db.recipeVersions,
    ).filter((f) => f.recipeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recipeVersionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MealPlanEntriesTable, List<MealPlanEntryRow>>
  _mealPlanEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mealPlanEntries,
    aliasName: 'recipes__id__meal_plan_entries__recipe_id',
  );

  $$MealPlanEntriesTableProcessedTableManager get mealPlanEntriesRefs {
    final manager = $$MealPlanEntriesTableTableManager(
      $_db,
      $_db.mealPlanEntries,
    ).filter((f) => f.recipeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _mealPlanEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RatingsTable, List<RatingRow>> _ratingsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.ratings,
    aliasName: 'recipes__id__ratings__recipe_id',
  );

  $$RatingsTableProcessedTableManager get ratingsRefs {
    final manager = $$RatingsTableTableManager(
      $_db,
      $_db.ratings,
    ).filter((f) => f.recipeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_ratingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RecipesTableFilterComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get servings => $composableBuilder(
    column: $table.servings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get prepMinutes => $composableBuilder(
    column: $table.prepMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ingredientsJson => $composableBuilder(
    column: $table.ingredientsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answeredBy => $composableBuilder(
    column: $table.answeredBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> recipeVersionsRefs(
    Expression<bool> Function($$RecipeVersionsTableFilterComposer f) f,
  ) {
    final $$RecipeVersionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipeVersions,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeVersionsTableFilterComposer(
            $db: $db,
            $table: $db.recipeVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> mealPlanEntriesRefs(
    Expression<bool> Function($$MealPlanEntriesTableFilterComposer f) f,
  ) {
    final $$MealPlanEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealPlanEntries,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealPlanEntriesTableFilterComposer(
            $db: $db,
            $table: $db.mealPlanEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> ratingsRefs(
    Expression<bool> Function($$RatingsTableFilterComposer f) f,
  ) {
    final $$RatingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ratings,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RatingsTableFilterComposer(
            $db: $db,
            $table: $db.ratings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecipesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get servings => $composableBuilder(
    column: $table.servings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get prepMinutes => $composableBuilder(
    column: $table.prepMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ingredientsJson => $composableBuilder(
    column: $table.ingredientsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answeredBy => $composableBuilder(
    column: $table.answeredBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecipesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get servings =>
      $composableBuilder(column: $table.servings, builder: (column) => column);

  GeneratedColumn<int> get prepMinutes => $composableBuilder(
    column: $table.prepMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get ingredientsJson => $composableBuilder(
    column: $table.ingredientsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stepsJson =>
      $composableBuilder(column: $table.stepsJson, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get answeredBy => $composableBuilder(
    column: $table.answeredBy,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> recipeVersionsRefs<T extends Object>(
    Expression<T> Function($$RecipeVersionsTableAnnotationComposer a) f,
  ) {
    final $$RecipeVersionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipeVersions,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeVersionsTableAnnotationComposer(
            $db: $db,
            $table: $db.recipeVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> mealPlanEntriesRefs<T extends Object>(
    Expression<T> Function($$MealPlanEntriesTableAnnotationComposer a) f,
  ) {
    final $$MealPlanEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealPlanEntries,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealPlanEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.mealPlanEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> ratingsRefs<T extends Object>(
    Expression<T> Function($$RatingsTableAnnotationComposer a) f,
  ) {
    final $$RatingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ratings,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RatingsTableAnnotationComposer(
            $db: $db,
            $table: $db.ratings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecipesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipesTable,
          RecipeRow,
          $$RecipesTableFilterComposer,
          $$RecipesTableOrderingComposer,
          $$RecipesTableAnnotationComposer,
          $$RecipesTableCreateCompanionBuilder,
          $$RecipesTableUpdateCompanionBuilder,
          (RecipeRow, $$RecipesTableReferences),
          RecipeRow,
          PrefetchHooks Function({
            bool recipeVersionsRefs,
            bool mealPlanEntriesRefs,
            bool ratingsRefs,
          })
        > {
  $$RecipesTableTableManager(_$AppDatabase db, $RecipesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> servings = const Value.absent(),
                Value<int?> prepMinutes = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> ingredientsJson = const Value.absent(),
                Value<String> stepsJson = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> answeredBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipesCompanion(
                id: id,
                title: title,
                servings: servings,
                prepMinutes: prepMinutes,
                source: source,
                ingredientsJson: ingredientsJson,
                stepsJson: stepsJson,
                imagePath: imagePath,
                answeredBy: answeredBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required int servings,
                Value<int?> prepMinutes = const Value.absent(),
                required String source,
                required String ingredientsJson,
                required String stepsJson,
                Value<String?> imagePath = const Value.absent(),
                Value<String?> answeredBy = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RecipesCompanion.insert(
                id: id,
                title: title,
                servings: servings,
                prepMinutes: prepMinutes,
                source: source,
                ingredientsJson: ingredientsJson,
                stepsJson: stepsJson,
                imagePath: imagePath,
                answeredBy: answeredBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecipesTable, RecipeRow>(table),
                  $$RecipesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                recipeVersionsRefs = false,
                mealPlanEntriesRefs = false,
                ratingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (recipeVersionsRefs) db.recipeVersions,
                    if (mealPlanEntriesRefs) db.mealPlanEntries,
                    if (ratingsRefs) db.ratings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (recipeVersionsRefs)
                        await $_getPrefetchedDataByColumns<
                          RecipeRow,
                          $RecipesTable,
                          RecipeVersionRow,
                          $RecipeVersionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$RecipesTableReferences
                              ._recipeVersionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecipesTableReferences(
                                db,
                                table,
                                p0,
                              ).recipeVersionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'recipe_id',
                          typedResults: items,
                        ),
                      if (mealPlanEntriesRefs)
                        await $_getPrefetchedDataByColumns<
                          RecipeRow,
                          $RecipesTable,
                          MealPlanEntryRow,
                          $MealPlanEntriesTable
                        >(
                          currentTable: table,
                          referencedTable: $$RecipesTableReferences
                              ._mealPlanEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecipesTableReferences(
                                db,
                                table,
                                p0,
                              ).mealPlanEntriesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'recipe_id',
                          typedResults: items,
                        ),
                      if (ratingsRefs)
                        await $_getPrefetchedDataByColumns<
                          RecipeRow,
                          $RecipesTable,
                          RatingRow,
                          $RatingsTable
                        >(
                          currentTable: table,
                          referencedTable: $$RecipesTableReferences
                              ._ratingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecipesTableReferences(
                                db,
                                table,
                                p0,
                              ).ratingsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'recipe_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RecipesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipesTable,
      RecipeRow,
      $$RecipesTableFilterComposer,
      $$RecipesTableOrderingComposer,
      $$RecipesTableAnnotationComposer,
      $$RecipesTableCreateCompanionBuilder,
      $$RecipesTableUpdateCompanionBuilder,
      (RecipeRow, $$RecipesTableReferences),
      RecipeRow,
      PrefetchHooks Function({
        bool recipeVersionsRefs,
        bool mealPlanEntriesRefs,
        bool ratingsRefs,
      })
    >;
typedef $$RecipeVersionsTableCreateCompanionBuilder =
    RecipeVersionsCompanion Function({
      Value<int> id,
      required String recipeId,
      required String recipeJson,
      Value<String?> instruction,
      required DateTime createdAt,
    });
typedef $$RecipeVersionsTableUpdateCompanionBuilder =
    RecipeVersionsCompanion Function({
      Value<int> id,
      Value<String> recipeId,
      Value<String> recipeJson,
      Value<String?> instruction,
      Value<DateTime> createdAt,
    });

final class $$RecipeVersionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $RecipeVersionsTable, RecipeVersionRow> {
  $$RecipeVersionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RecipesTable _recipeIdTable(_$AppDatabase db) =>
      db.recipes.createAlias('recipe_versions__recipe_id__recipes__id');

  $$RecipesTableProcessedTableManager get recipeId {
    final $_column = $_itemColumn<String>('recipe_id')!;

    final manager = $$RecipesTableTableManager(
      $_db,
      $_db.recipes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecipeVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $RecipeVersionsTable> {
  $$RecipeVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipeJson => $composableBuilder(
    column: $table.recipeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instruction => $composableBuilder(
    column: $table.instruction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RecipesTableFilterComposer get recipeId {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableFilterComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipeVersionsTable> {
  $$RecipeVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipeJson => $composableBuilder(
    column: $table.recipeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instruction => $composableBuilder(
    column: $table.instruction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecipesTableOrderingComposer get recipeId {
    final $$RecipesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableOrderingComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipeVersionsTable> {
  $$RecipeVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recipeJson => $composableBuilder(
    column: $table.recipeJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get instruction => $composableBuilder(
    column: $table.instruction,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$RecipesTableAnnotationComposer get recipeId {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipeVersionsTable,
          RecipeVersionRow,
          $$RecipeVersionsTableFilterComposer,
          $$RecipeVersionsTableOrderingComposer,
          $$RecipeVersionsTableAnnotationComposer,
          $$RecipeVersionsTableCreateCompanionBuilder,
          $$RecipeVersionsTableUpdateCompanionBuilder,
          (RecipeVersionRow, $$RecipeVersionsTableReferences),
          RecipeVersionRow,
          PrefetchHooks Function({bool recipeId})
        > {
  $$RecipeVersionsTableTableManager(
    _$AppDatabase db,
    $RecipeVersionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipeVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipeVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipeVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> recipeId = const Value.absent(),
                Value<String> recipeJson = const Value.absent(),
                Value<String?> instruction = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RecipeVersionsCompanion(
                id: id,
                recipeId: recipeId,
                recipeJson: recipeJson,
                instruction: instruction,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String recipeId,
                required String recipeJson,
                Value<String?> instruction = const Value.absent(),
                required DateTime createdAt,
              }) => RecipeVersionsCompanion.insert(
                id: id,
                recipeId: recipeId,
                recipeJson: recipeJson,
                instruction: instruction,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecipeVersionsTable, RecipeVersionRow>(table),
                  $$RecipeVersionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recipeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recipeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recipeId,
                        referencedTable: $$RecipeVersionsTableReferences
                            ._recipeIdTable(db),
                        referencedColumn: $$RecipeVersionsTableReferences
                            ._recipeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecipeVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipeVersionsTable,
      RecipeVersionRow,
      $$RecipeVersionsTableFilterComposer,
      $$RecipeVersionsTableOrderingComposer,
      $$RecipeVersionsTableAnnotationComposer,
      $$RecipeVersionsTableCreateCompanionBuilder,
      $$RecipeVersionsTableUpdateCompanionBuilder,
      (RecipeVersionRow, $$RecipeVersionsTableReferences),
      RecipeVersionRow,
      PrefetchHooks Function({bool recipeId})
    >;
typedef $$PantryItemsTableCreateCompanionBuilder =
    PantryItemsCompanion Function({
      Value<int> id,
      required String name,
      Value<double?> quantity,
      Value<String?> unit,
      required String category,
      required DateTime addedAt,
      Value<DateTime?> expiresAt,
    });
typedef $$PantryItemsTableUpdateCompanionBuilder =
    PantryItemsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<double?> quantity,
      Value<String?> unit,
      Value<String> category,
      Value<DateTime> addedAt,
      Value<DateTime?> expiresAt,
    });

class $$PantryItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PantryItemsTable> {
  $$PantryItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PantryItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PantryItemsTable> {
  $$PantryItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PantryItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PantryItemsTable> {
  $$PantryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$PantryItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PantryItemsTable,
          PantryItemRow,
          $$PantryItemsTableFilterComposer,
          $$PantryItemsTableOrderingComposer,
          $$PantryItemsTableAnnotationComposer,
          $$PantryItemsTableCreateCompanionBuilder,
          $$PantryItemsTableUpdateCompanionBuilder,
          (
            PantryItemRow,
            BaseReferences<_$AppDatabase, $PantryItemsTable, PantryItemRow>,
          ),
          PantryItemRow,
          PrefetchHooks Function()
        > {
  $$PantryItemsTableTableManager(_$AppDatabase db, $PantryItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PantryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PantryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PantryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> quantity = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
              }) => PantryItemsCompanion(
                id: id,
                name: name,
                quantity: quantity,
                unit: unit,
                category: category,
                addedAt: addedAt,
                expiresAt: expiresAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<double?> quantity = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                required String category,
                required DateTime addedAt,
                Value<DateTime?> expiresAt = const Value.absent(),
              }) => PantryItemsCompanion.insert(
                id: id,
                name: name,
                quantity: quantity,
                unit: unit,
                category: category,
                addedAt: addedAt,
                expiresAt: expiresAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PantryItemsTable, PantryItemRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PantryItemsTable,
                    PantryItemRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PantryItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PantryItemsTable,
      PantryItemRow,
      $$PantryItemsTableFilterComposer,
      $$PantryItemsTableOrderingComposer,
      $$PantryItemsTableAnnotationComposer,
      $$PantryItemsTableCreateCompanionBuilder,
      $$PantryItemsTableUpdateCompanionBuilder,
      (
        PantryItemRow,
        BaseReferences<_$AppDatabase, $PantryItemsTable, PantryItemRow>,
      ),
      PantryItemRow,
      PrefetchHooks Function()
    >;
typedef $$ShoppingListsTableCreateCompanionBuilder =
    ShoppingListsCompanion Function({
      required String id,
      required String name,
      Value<String?> mealPlanId,
      Value<int?> week,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ShoppingListsTableUpdateCompanionBuilder =
    ShoppingListsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> mealPlanId,
      Value<int?> week,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ShoppingListsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ShoppingListsTable, ShoppingListRow> {
  $$ShoppingListsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ShoppingItemsTable, List<ShoppingItemRow>>
  _shoppingItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.shoppingItems,
    aliasName: 'shopping_lists__id__shopping_items__list_id',
  );

  $$ShoppingItemsTableProcessedTableManager get shoppingItemsRefs {
    final manager = $$ShoppingItemsTableTableManager(
      $_db,
      $_db.shoppingItems,
    ).filter((f) => f.listId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_shoppingItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ShoppingListsTableFilterComposer
    extends Composer<_$AppDatabase, $ShoppingListsTable> {
  $$ShoppingListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealPlanId => $composableBuilder(
    column: $table.mealPlanId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get week => $composableBuilder(
    column: $table.week,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> shoppingItemsRefs(
    Expression<bool> Function($$ShoppingItemsTableFilterComposer f) f,
  ) {
    final $$ShoppingItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shoppingItems,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingItemsTableFilterComposer(
            $db: $db,
            $table: $db.shoppingItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShoppingListsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShoppingListsTable> {
  $$ShoppingListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealPlanId => $composableBuilder(
    column: $table.mealPlanId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get week => $composableBuilder(
    column: $table.week,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShoppingListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShoppingListsTable> {
  $$ShoppingListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get mealPlanId => $composableBuilder(
    column: $table.mealPlanId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get week =>
      $composableBuilder(column: $table.week, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> shoppingItemsRefs<T extends Object>(
    Expression<T> Function($$ShoppingItemsTableAnnotationComposer a) f,
  ) {
    final $$ShoppingItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shoppingItems,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.shoppingItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShoppingListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShoppingListsTable,
          ShoppingListRow,
          $$ShoppingListsTableFilterComposer,
          $$ShoppingListsTableOrderingComposer,
          $$ShoppingListsTableAnnotationComposer,
          $$ShoppingListsTableCreateCompanionBuilder,
          $$ShoppingListsTableUpdateCompanionBuilder,
          (ShoppingListRow, $$ShoppingListsTableReferences),
          ShoppingListRow,
          PrefetchHooks Function({bool shoppingItemsRefs})
        > {
  $$ShoppingListsTableTableManager(_$AppDatabase db, $ShoppingListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShoppingListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShoppingListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShoppingListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> mealPlanId = const Value.absent(),
                Value<int?> week = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShoppingListsCompanion(
                id: id,
                name: name,
                mealPlanId: mealPlanId,
                week: week,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> mealPlanId = const Value.absent(),
                Value<int?> week = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ShoppingListsCompanion.insert(
                id: id,
                name: name,
                mealPlanId: mealPlanId,
                week: week,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShoppingListsTable, ShoppingListRow>(table),
                  $$ShoppingListsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shoppingItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (shoppingItemsRefs) db.shoppingItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (shoppingItemsRefs)
                    await $_getPrefetchedDataByColumns<
                      ShoppingListRow,
                      $ShoppingListsTable,
                      ShoppingItemRow,
                      $ShoppingItemsTable
                    >(
                      currentTable: table,
                      referencedTable: $$ShoppingListsTableReferences
                          ._shoppingItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ShoppingListsTableReferences(
                            db,
                            table,
                            p0,
                          ).shoppingItemsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'list_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ShoppingListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShoppingListsTable,
      ShoppingListRow,
      $$ShoppingListsTableFilterComposer,
      $$ShoppingListsTableOrderingComposer,
      $$ShoppingListsTableAnnotationComposer,
      $$ShoppingListsTableCreateCompanionBuilder,
      $$ShoppingListsTableUpdateCompanionBuilder,
      (ShoppingListRow, $$ShoppingListsTableReferences),
      ShoppingListRow,
      PrefetchHooks Function({bool shoppingItemsRefs})
    >;
typedef $$ShoppingItemsTableCreateCompanionBuilder =
    ShoppingItemsCompanion Function({
      Value<int> id,
      required String listId,
      required String name,
      Value<double?> quantity,
      Value<String?> unit,
      required String category,
      Value<bool> isBought,
      Value<bool> isManual,
      Value<String> fromRecipeIdsJson,
    });
typedef $$ShoppingItemsTableUpdateCompanionBuilder =
    ShoppingItemsCompanion Function({
      Value<int> id,
      Value<String> listId,
      Value<String> name,
      Value<double?> quantity,
      Value<String?> unit,
      Value<String> category,
      Value<bool> isBought,
      Value<bool> isManual,
      Value<String> fromRecipeIdsJson,
    });

final class $$ShoppingItemsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ShoppingItemsTable, ShoppingItemRow> {
  $$ShoppingItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ShoppingListsTable _listIdTable(_$AppDatabase db) => db.shoppingLists
      .createAlias('shopping_items__list_id__shopping_lists__id');

  $$ShoppingListsTableProcessedTableManager get listId {
    final $_column = $_itemColumn<String>('list_id')!;

    final manager = $$ShoppingListsTableTableManager(
      $_db,
      $_db.shoppingLists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_listIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShoppingItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBought => $composableBuilder(
    column: $table.isBought,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isManual => $composableBuilder(
    column: $table.isManual,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromRecipeIdsJson => $composableBuilder(
    column: $table.fromRecipeIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  $$ShoppingListsTableFilterComposer get listId {
    final $$ShoppingListsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.shoppingLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingListsTableFilterComposer(
            $db: $db,
            $table: $db.shoppingLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShoppingItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBought => $composableBuilder(
    column: $table.isBought,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isManual => $composableBuilder(
    column: $table.isManual,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromRecipeIdsJson => $composableBuilder(
    column: $table.fromRecipeIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShoppingListsTableOrderingComposer get listId {
    final $$ShoppingListsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.shoppingLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingListsTableOrderingComposer(
            $db: $db,
            $table: $db.shoppingLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShoppingItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get isBought =>
      $composableBuilder(column: $table.isBought, builder: (column) => column);

  GeneratedColumn<bool> get isManual =>
      $composableBuilder(column: $table.isManual, builder: (column) => column);

  GeneratedColumn<String> get fromRecipeIdsJson => $composableBuilder(
    column: $table.fromRecipeIdsJson,
    builder: (column) => column,
  );

  $$ShoppingListsTableAnnotationComposer get listId {
    final $$ShoppingListsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.shoppingLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingListsTableAnnotationComposer(
            $db: $db,
            $table: $db.shoppingLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShoppingItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShoppingItemsTable,
          ShoppingItemRow,
          $$ShoppingItemsTableFilterComposer,
          $$ShoppingItemsTableOrderingComposer,
          $$ShoppingItemsTableAnnotationComposer,
          $$ShoppingItemsTableCreateCompanionBuilder,
          $$ShoppingItemsTableUpdateCompanionBuilder,
          (ShoppingItemRow, $$ShoppingItemsTableReferences),
          ShoppingItemRow,
          PrefetchHooks Function({bool listId})
        > {
  $$ShoppingItemsTableTableManager(_$AppDatabase db, $ShoppingItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShoppingItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShoppingItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShoppingItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> listId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> quantity = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<bool> isBought = const Value.absent(),
                Value<bool> isManual = const Value.absent(),
                Value<String> fromRecipeIdsJson = const Value.absent(),
              }) => ShoppingItemsCompanion(
                id: id,
                listId: listId,
                name: name,
                quantity: quantity,
                unit: unit,
                category: category,
                isBought: isBought,
                isManual: isManual,
                fromRecipeIdsJson: fromRecipeIdsJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String listId,
                required String name,
                Value<double?> quantity = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                required String category,
                Value<bool> isBought = const Value.absent(),
                Value<bool> isManual = const Value.absent(),
                Value<String> fromRecipeIdsJson = const Value.absent(),
              }) => ShoppingItemsCompanion.insert(
                id: id,
                listId: listId,
                name: name,
                quantity: quantity,
                unit: unit,
                category: category,
                isBought: isBought,
                isManual: isManual,
                fromRecipeIdsJson: fromRecipeIdsJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShoppingItemsTable, ShoppingItemRow>(table),
                  $$ShoppingItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({listId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (listId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.listId,
                        referencedTable: $$ShoppingItemsTableReferences
                            ._listIdTable(db),
                        referencedColumn: $$ShoppingItemsTableReferences
                            ._listIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShoppingItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShoppingItemsTable,
      ShoppingItemRow,
      $$ShoppingItemsTableFilterComposer,
      $$ShoppingItemsTableOrderingComposer,
      $$ShoppingItemsTableAnnotationComposer,
      $$ShoppingItemsTableCreateCompanionBuilder,
      $$ShoppingItemsTableUpdateCompanionBuilder,
      (ShoppingItemRow, $$ShoppingItemsTableReferences),
      ShoppingItemRow,
      PrefetchHooks Function({bool listId})
    >;
typedef $$MealPlansTableCreateCompanionBuilder = MealPlansCompanion Function({
  required String id,
  required DateTime startDate,
  required DateTime endDate,
  required String mealTypesJson,
  Value<bool> usePantry,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$MealPlansTableUpdateCompanionBuilder = MealPlansCompanion Function({
  Value<String> id,
  Value<DateTime> startDate,
  Value<DateTime> endDate,
  Value<String> mealTypesJson,
  Value<bool> usePantry,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$MealPlansTableReferences
    extends BaseReferences<_$AppDatabase, $MealPlansTable, MealPlanRow> {
  $$MealPlansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MealPlanEntriesTable, List<MealPlanEntryRow>>
  _mealPlanEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mealPlanEntries,
    aliasName: 'meal_plans__id__meal_plan_entries__plan_id',
  );

  $$MealPlanEntriesTableProcessedTableManager get mealPlanEntriesRefs {
    final manager = $$MealPlanEntriesTableTableManager(
      $_db,
      $_db.mealPlanEntries,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _mealPlanEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MealPlansTableFilterComposer
    extends Composer<_$AppDatabase, $MealPlansTable> {
  $$MealPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealTypesJson => $composableBuilder(
    column: $table.mealTypesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get usePantry => $composableBuilder(
    column: $table.usePantry,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mealPlanEntriesRefs(
    Expression<bool> Function($$MealPlanEntriesTableFilterComposer f) f,
  ) {
    final $$MealPlanEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealPlanEntries,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealPlanEntriesTableFilterComposer(
            $db: $db,
            $table: $db.mealPlanEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $MealPlansTable> {
  $$MealPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealTypesJson => $composableBuilder(
    column: $table.mealTypesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get usePantry => $composableBuilder(
    column: $table.usePantry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MealPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealPlansTable> {
  $$MealPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get mealTypesJson => $composableBuilder(
    column: $table.mealTypesJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get usePantry =>
      $composableBuilder(column: $table.usePantry, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> mealPlanEntriesRefs<T extends Object>(
    Expression<T> Function($$MealPlanEntriesTableAnnotationComposer a) f,
  ) {
    final $$MealPlanEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealPlanEntries,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealPlanEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.mealPlanEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealPlansTable,
          MealPlanRow,
          $$MealPlansTableFilterComposer,
          $$MealPlansTableOrderingComposer,
          $$MealPlansTableAnnotationComposer,
          $$MealPlansTableCreateCompanionBuilder,
          $$MealPlansTableUpdateCompanionBuilder,
          (MealPlanRow, $$MealPlansTableReferences),
          MealPlanRow,
          PrefetchHooks Function({bool mealPlanEntriesRefs})
        > {
  $$MealPlansTableTableManager(_$AppDatabase db, $MealPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> endDate = const Value.absent(),
                Value<String> mealTypesJson = const Value.absent(),
                Value<bool> usePantry = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealPlansCompanion(
                id: id,
                startDate: startDate,
                endDate: endDate,
                mealTypesJson: mealTypesJson,
                usePantry: usePantry,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime startDate,
                required DateTime endDate,
                required String mealTypesJson,
                Value<bool> usePantry = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MealPlansCompanion.insert(
                id: id,
                startDate: startDate,
                endDate: endDate,
                mealTypesJson: mealTypesJson,
                usePantry: usePantry,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MealPlansTable, MealPlanRow>(table),
                  $$MealPlansTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mealPlanEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (mealPlanEntriesRefs) db.mealPlanEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mealPlanEntriesRefs)
                    await $_getPrefetchedDataByColumns<
                      MealPlanRow,
                      $MealPlansTable,
                      MealPlanEntryRow,
                      $MealPlanEntriesTable
                    >(
                      currentTable: table,
                      referencedTable: $$MealPlansTableReferences
                          ._mealPlanEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MealPlansTableReferences(
                            db,
                            table,
                            p0,
                          ).mealPlanEntriesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'plan_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MealPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealPlansTable,
      MealPlanRow,
      $$MealPlansTableFilterComposer,
      $$MealPlansTableOrderingComposer,
      $$MealPlansTableAnnotationComposer,
      $$MealPlansTableCreateCompanionBuilder,
      $$MealPlansTableUpdateCompanionBuilder,
      (MealPlanRow, $$MealPlansTableReferences),
      MealPlanRow,
      PrefetchHooks Function({bool mealPlanEntriesRefs})
    >;
typedef $$MealPlanEntriesTableCreateCompanionBuilder =
    MealPlanEntriesCompanion Function({
      Value<int> id,
      required String planId,
      required DateTime date,
      required String mealType,
      Value<String?> recipeId,
      Value<bool> isLocked,
      Value<bool> isCooked,
    });
typedef $$MealPlanEntriesTableUpdateCompanionBuilder =
    MealPlanEntriesCompanion Function({
      Value<int> id,
      Value<String> planId,
      Value<DateTime> date,
      Value<String> mealType,
      Value<String?> recipeId,
      Value<bool> isLocked,
      Value<bool> isCooked,
    });

final class $$MealPlanEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $MealPlanEntriesTable, MealPlanEntryRow> {
  $$MealPlanEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MealPlansTable _planIdTable(_$AppDatabase db) =>
      db.mealPlans.createAlias('meal_plan_entries__plan_id__meal_plans__id');

  $$MealPlansTableProcessedTableManager get planId {
    final $_column = $_itemColumn<String>('plan_id')!;

    final manager = $$MealPlansTableTableManager(
      $_db,
      $_db.mealPlans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RecipesTable _recipeIdTable(_$AppDatabase db) =>
      db.recipes.createAlias('meal_plan_entries__recipe_id__recipes__id');

  $$RecipesTableProcessedTableManager? get recipeId {
    final $_column = $_itemColumn<String>('recipe_id');
    if ($_column == null) return null;
    final manager = $$RecipesTableTableManager(
      $_db,
      $_db.recipes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MealPlanEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MealPlanEntriesTable> {
  $$MealPlanEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLocked => $composableBuilder(
    column: $table.isLocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCooked => $composableBuilder(
    column: $table.isCooked,
    builder: (column) => ColumnFilters(column),
  );

  $$MealPlansTableFilterComposer get planId {
    final $$MealPlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.mealPlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealPlansTableFilterComposer(
            $db: $db,
            $table: $db.mealPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecipesTableFilterComposer get recipeId {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableFilterComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealPlanEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MealPlanEntriesTable> {
  $$MealPlanEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLocked => $composableBuilder(
    column: $table.isLocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCooked => $composableBuilder(
    column: $table.isCooked,
    builder: (column) => ColumnOrderings(column),
  );

  $$MealPlansTableOrderingComposer get planId {
    final $$MealPlansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.mealPlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealPlansTableOrderingComposer(
            $db: $db,
            $table: $db.mealPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecipesTableOrderingComposer get recipeId {
    final $$RecipesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableOrderingComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealPlanEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealPlanEntriesTable> {
  $$MealPlanEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get mealType =>
      $composableBuilder(column: $table.mealType, builder: (column) => column);

  GeneratedColumn<bool> get isLocked =>
      $composableBuilder(column: $table.isLocked, builder: (column) => column);

  GeneratedColumn<bool> get isCooked =>
      $composableBuilder(column: $table.isCooked, builder: (column) => column);

  $$MealPlansTableAnnotationComposer get planId {
    final $$MealPlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.mealPlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealPlansTableAnnotationComposer(
            $db: $db,
            $table: $db.mealPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecipesTableAnnotationComposer get recipeId {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealPlanEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealPlanEntriesTable,
          MealPlanEntryRow,
          $$MealPlanEntriesTableFilterComposer,
          $$MealPlanEntriesTableOrderingComposer,
          $$MealPlanEntriesTableAnnotationComposer,
          $$MealPlanEntriesTableCreateCompanionBuilder,
          $$MealPlanEntriesTableUpdateCompanionBuilder,
          (MealPlanEntryRow, $$MealPlanEntriesTableReferences),
          MealPlanEntryRow,
          PrefetchHooks Function({bool planId, bool recipeId})
        > {
  $$MealPlanEntriesTableTableManager(
    _$AppDatabase db,
    $MealPlanEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealPlanEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealPlanEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealPlanEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> mealType = const Value.absent(),
                Value<String?> recipeId = const Value.absent(),
                Value<bool> isLocked = const Value.absent(),
                Value<bool> isCooked = const Value.absent(),
              }) => MealPlanEntriesCompanion(
                id: id,
                planId: planId,
                date: date,
                mealType: mealType,
                recipeId: recipeId,
                isLocked: isLocked,
                isCooked: isCooked,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String planId,
                required DateTime date,
                required String mealType,
                Value<String?> recipeId = const Value.absent(),
                Value<bool> isLocked = const Value.absent(),
                Value<bool> isCooked = const Value.absent(),
              }) => MealPlanEntriesCompanion.insert(
                id: id,
                planId: planId,
                date: date,
                mealType: mealType,
                recipeId: recipeId,
                isLocked: isLocked,
                isCooked: isCooked,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MealPlanEntriesTable, MealPlanEntryRow>(table),
                  $$MealPlanEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({planId = false, recipeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (planId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.planId,
                        referencedTable: $$MealPlanEntriesTableReferences
                            ._planIdTable(db),
                        referencedColumn: $$MealPlanEntriesTableReferences
                            ._planIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (recipeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recipeId,
                        referencedTable: $$MealPlanEntriesTableReferences
                            ._recipeIdTable(db),
                        referencedColumn: $$MealPlanEntriesTableReferences
                            ._recipeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MealPlanEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealPlanEntriesTable,
      MealPlanEntryRow,
      $$MealPlanEntriesTableFilterComposer,
      $$MealPlanEntriesTableOrderingComposer,
      $$MealPlanEntriesTableAnnotationComposer,
      $$MealPlanEntriesTableCreateCompanionBuilder,
      $$MealPlanEntriesTableUpdateCompanionBuilder,
      (MealPlanEntryRow, $$MealPlanEntriesTableReferences),
      MealPlanEntryRow,
      PrefetchHooks Function({bool planId, bool recipeId})
    >;
typedef $$RatingsTableCreateCompanionBuilder = RatingsCompanion Function({
  Value<int> id,
  required String recipeId,
  required int stars,
  Value<bool> isComfortFood,
  Value<String?> comment,
  required DateTime cookedAt,
});
typedef $$RatingsTableUpdateCompanionBuilder = RatingsCompanion Function({
  Value<int> id,
  Value<String> recipeId,
  Value<int> stars,
  Value<bool> isComfortFood,
  Value<String?> comment,
  Value<DateTime> cookedAt,
});

final class $$RatingsTableReferences
    extends BaseReferences<_$AppDatabase, $RatingsTable, RatingRow> {
  $$RatingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecipesTable _recipeIdTable(_$AppDatabase db) =>
      db.recipes.createAlias('ratings__recipe_id__recipes__id');

  $$RecipesTableProcessedTableManager get recipeId {
    final $_column = $_itemColumn<String>('recipe_id')!;

    final manager = $$RecipesTableTableManager(
      $_db,
      $_db.recipes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RatingsTableFilterComposer
    extends Composer<_$AppDatabase, $RatingsTable> {
  $$RatingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stars => $composableBuilder(
    column: $table.stars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isComfortFood => $composableBuilder(
    column: $table.isComfortFood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cookedAt => $composableBuilder(
    column: $table.cookedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RecipesTableFilterComposer get recipeId {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableFilterComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RatingsTableOrderingComposer
    extends Composer<_$AppDatabase, $RatingsTable> {
  $$RatingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stars => $composableBuilder(
    column: $table.stars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isComfortFood => $composableBuilder(
    column: $table.isComfortFood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cookedAt => $composableBuilder(
    column: $table.cookedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecipesTableOrderingComposer get recipeId {
    final $$RecipesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableOrderingComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RatingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RatingsTable> {
  $$RatingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get stars =>
      $composableBuilder(column: $table.stars, builder: (column) => column);

  GeneratedColumn<bool> get isComfortFood => $composableBuilder(
    column: $table.isComfortFood,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<DateTime> get cookedAt =>
      $composableBuilder(column: $table.cookedAt, builder: (column) => column);

  $$RecipesTableAnnotationComposer get recipeId {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RatingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RatingsTable,
          RatingRow,
          $$RatingsTableFilterComposer,
          $$RatingsTableOrderingComposer,
          $$RatingsTableAnnotationComposer,
          $$RatingsTableCreateCompanionBuilder,
          $$RatingsTableUpdateCompanionBuilder,
          (RatingRow, $$RatingsTableReferences),
          RatingRow,
          PrefetchHooks Function({bool recipeId})
        > {
  $$RatingsTableTableManager(_$AppDatabase db, $RatingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RatingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RatingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RatingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> recipeId = const Value.absent(),
                Value<int> stars = const Value.absent(),
                Value<bool> isComfortFood = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<DateTime> cookedAt = const Value.absent(),
              }) => RatingsCompanion(
                id: id,
                recipeId: recipeId,
                stars: stars,
                isComfortFood: isComfortFood,
                comment: comment,
                cookedAt: cookedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String recipeId,
                required int stars,
                Value<bool> isComfortFood = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                required DateTime cookedAt,
              }) => RatingsCompanion.insert(
                id: id,
                recipeId: recipeId,
                stars: stars,
                isComfortFood: isComfortFood,
                comment: comment,
                cookedAt: cookedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RatingsTable, RatingRow>(table),
                  $$RatingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recipeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recipeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recipeId,
                        referencedTable: $$RatingsTableReferences
                            ._recipeIdTable(db),
                        referencedColumn: $$RatingsTableReferences
                            ._recipeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RatingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RatingsTable,
      RatingRow,
      $$RatingsTableFilterComposer,
      $$RatingsTableOrderingComposer,
      $$RatingsTableAnnotationComposer,
      $$RatingsTableCreateCompanionBuilder,
      $$RatingsTableUpdateCompanionBuilder,
      (RatingRow, $$RatingsTableReferences),
      RatingRow,
      PrefetchHooks Function({bool recipeId})
    >;
typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      required String profileJson,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({Value<int> id, Value<String> profileJson});

class $$UserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileJson => $composableBuilder(
    column: $table.profileJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileJson => $composableBuilder(
    column: $table.profileJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileJson => $composableBuilder(
    column: $table.profileJson,
    builder: (column) => column,
  );
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesTable,
          UserProfileRow,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (
            UserProfileRow,
            BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfileRow>,
          ),
          UserProfileRow,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> profileJson = const Value.absent(),
          }) => UserProfilesCompanion(id: id, profileJson: profileJson),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String profileJson,
          }) => UserProfilesCompanion.insert(id: id, profileJson: profileJson),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserProfilesTable, UserProfileRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $UserProfilesTable,
                    UserProfileRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesTable,
      UserProfileRow,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (
        UserProfileRow,
        BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfileRow>,
      ),
      UserProfileRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSettingRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>,
          ),
          AppSettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSettingRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AppSettingsTable,
                    AppSettingRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSettingRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>,
      ),
      AppSettingRow,
      PrefetchHooks Function()
    >;
typedef $$ModelStatusesTableCreateCompanionBuilder =
    ModelStatusesCompanion Function({
      required String provider,
      required String model,
      Value<String> keyOrigin,
      Value<DateTime?> blockedUntil,
      Value<int> requestsToday,
      Value<String?> usageDay,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$ModelStatusesTableUpdateCompanionBuilder =
    ModelStatusesCompanion Function({
      Value<String> provider,
      Value<String> model,
      Value<String> keyOrigin,
      Value<DateTime?> blockedUntil,
      Value<int> requestsToday,
      Value<String?> usageDay,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$ModelStatusesTableFilterComposer
    extends Composer<_$AppDatabase, $ModelStatusesTable> {
  $$ModelStatusesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyOrigin => $composableBuilder(
    column: $table.keyOrigin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get blockedUntil => $composableBuilder(
    column: $table.blockedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requestsToday => $composableBuilder(
    column: $table.requestsToday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get usageDay => $composableBuilder(
    column: $table.usageDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ModelStatusesTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelStatusesTable> {
  $$ModelStatusesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyOrigin => $composableBuilder(
    column: $table.keyOrigin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get blockedUntil => $composableBuilder(
    column: $table.blockedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requestsToday => $composableBuilder(
    column: $table.requestsToday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get usageDay => $composableBuilder(
    column: $table.usageDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModelStatusesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelStatusesTable> {
  $$ModelStatusesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get keyOrigin =>
      $composableBuilder(column: $table.keyOrigin, builder: (column) => column);

  GeneratedColumn<DateTime> get blockedUntil => $composableBuilder(
    column: $table.blockedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get requestsToday => $composableBuilder(
    column: $table.requestsToday,
    builder: (column) => column,
  );

  GeneratedColumn<String> get usageDay =>
      $composableBuilder(column: $table.usageDay, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$ModelStatusesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModelStatusesTable,
          ModelStatusRow,
          $$ModelStatusesTableFilterComposer,
          $$ModelStatusesTableOrderingComposer,
          $$ModelStatusesTableAnnotationComposer,
          $$ModelStatusesTableCreateCompanionBuilder,
          $$ModelStatusesTableUpdateCompanionBuilder,
          (
            ModelStatusRow,
            BaseReferences<_$AppDatabase, $ModelStatusesTable, ModelStatusRow>,
          ),
          ModelStatusRow,
          PrefetchHooks Function()
        > {
  $$ModelStatusesTableTableManager(_$AppDatabase db, $ModelStatusesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelStatusesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelStatusesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelStatusesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> provider = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> keyOrigin = const Value.absent(),
                Value<DateTime?> blockedUntil = const Value.absent(),
                Value<int> requestsToday = const Value.absent(),
                Value<String?> usageDay = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelStatusesCompanion(
                provider: provider,
                model: model,
                keyOrigin: keyOrigin,
                blockedUntil: blockedUntil,
                requestsToday: requestsToday,
                usageDay: usageDay,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String provider,
                required String model,
                Value<String> keyOrigin = const Value.absent(),
                Value<DateTime?> blockedUntil = const Value.absent(),
                Value<int> requestsToday = const Value.absent(),
                Value<String?> usageDay = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelStatusesCompanion.insert(
                provider: provider,
                model: model,
                keyOrigin: keyOrigin,
                blockedUntil: blockedUntil,
                requestsToday: requestsToday,
                usageDay: usageDay,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModelStatusesTable, ModelStatusRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ModelStatusesTable,
                    ModelStatusRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ModelStatusesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModelStatusesTable,
      ModelStatusRow,
      $$ModelStatusesTableFilterComposer,
      $$ModelStatusesTableOrderingComposer,
      $$ModelStatusesTableAnnotationComposer,
      $$ModelStatusesTableCreateCompanionBuilder,
      $$ModelStatusesTableUpdateCompanionBuilder,
      (
        ModelStatusRow,
        BaseReferences<_$AppDatabase, $ModelStatusesTable, ModelStatusRow>,
      ),
      ModelStatusRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RecipesTableTableManager get recipes =>
      $$RecipesTableTableManager(_db, _db.recipes);
  $$RecipeVersionsTableTableManager get recipeVersions =>
      $$RecipeVersionsTableTableManager(_db, _db.recipeVersions);
  $$PantryItemsTableTableManager get pantryItems =>
      $$PantryItemsTableTableManager(_db, _db.pantryItems);
  $$ShoppingListsTableTableManager get shoppingLists =>
      $$ShoppingListsTableTableManager(_db, _db.shoppingLists);
  $$ShoppingItemsTableTableManager get shoppingItems =>
      $$ShoppingItemsTableTableManager(_db, _db.shoppingItems);
  $$MealPlansTableTableManager get mealPlans =>
      $$MealPlansTableTableManager(_db, _db.mealPlans);
  $$MealPlanEntriesTableTableManager get mealPlanEntries =>
      $$MealPlanEntriesTableTableManager(_db, _db.mealPlanEntries);
  $$RatingsTableTableManager get ratings =>
      $$RatingsTableTableManager(_db, _db.ratings);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$ModelStatusesTableTableManager get modelStatuses =>
      $$ModelStatusesTableTableManager(_db, _db.modelStatuses);
}
