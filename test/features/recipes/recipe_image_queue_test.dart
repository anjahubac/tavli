import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/ai/ai_errors.dart';
import 'package:tavli/ai/recipe_image_client.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/recipe_image_jobs.dart';
import 'package:tavli/data/recipe_repository.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/recipe_version.dart';
import 'package:tavli/features/recipes/recipe_image_queue.dart';
import 'package:tavli/sync/sync_remote.dart';
import 'package:tavli/sync/synced_writer.dart';

import '../../helpers/fake_photo_store.dart';

const _scope = AccountScope(userId: 'u1', householdId: 'h1');
const _file = 'ai_00000000-0000-4000-8000-000000000001.jpg';
final _jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);

Recipe _recipe(
  String id, {
  RecipeSource source = RecipeSource.ai,
  String? description = 'Beans in a clay pot, top-down.',
  String? imagePath,
  DateTime? createdAt,
}) => Recipe(
  id: id,
  title: 'Pasulj $id',
  servings: 4,
  ingredients: const [Ingredient(name: 'pasulj')],
  steps: const ['Kuvati.'],
  source: source,
  createdAt: createdAt ?? DateTime.utc(2026, 11),
  imageDescription: description,
  imagePath: imagePath,
);

class _Remote implements PhotoRemote {
  final objects = <String, Uint8List>{};
  final removed = <String>[];

  @override
  Future<Uint8List> download(String objectKey) async =>
      objects[objectKey] ?? (throw const PermanentSyncError('404'));

  @override
  Future<void> remove(List<String> objectKeys) async {
    removed.addAll(objectKeys);
    objectKeys.forEach(objects.remove);
  }

  @override
  Future<void> upload(String objectKey, Uint8List jpeg) async =>
      objects[objectKey] = jpeg;
}

void main() {
  late AppDatabase db;
  late FakePhotoStore store;
  late RecipeRepository repo;
  late RecipeImageJobStore jobs;
  late _Remote remote;
  late DateTime now;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = FakePhotoStore();
    remote = _Remote();
    now = DateTime.utc(2026, 11, 23, 12);
    repo = RecipeRepository(
      db,
      store,
      writer: SyncedWriter(db, accountId: _scope.userId, clock: () => now),
      scope: _scope,
      clock: () => now,
    );
    jobs = RecipeImageJobStore(db, _scope);
  });
  tearDown(() => db.close());

  Future<List<String>> queued() async => [
    for (final r in await db.select(db.recipeImageJobs).get()) r.recipeId,
  ];

  group('repository image rules', () {
    test('an AI recipe without an image is queued; manual and photo '
        'recipes are not', () async {
      await repo.create(_recipe('ai'));
      await repo.create(_recipe('manual', source: RecipeSource.manual));
      await repo.create(
        _recipe(
          'photo',
          source: RecipeSource.photo,
          imagePath: 'recipe_photos/mine.jpg',
        ),
      );
      expect(await queued(), ['ai']);
      expect((await repo.get('photo'))!.imageSource, RecipeImageSource.user);
      expect((await repo.get('ai'))!.imageSource, isNull);
    });

    test('an AI image fills an empty recipe without a new version', () async {
      await repo.create(_recipe('r'));
      expect(await repo.attachAiImage('r', 'recipe_photos/$_file'), isTrue);
      final saved = (await repo.get('r'))!;
      expect(saved.imagePath, 'recipe_photos/$_file');
      expect(saved.imageSource, RecipeImageSource.ai);
      expect(await repo.watchVersions('r').first, isEmpty);
    });

    test('an AI image never replaces a user photo', () async {
      await repo.create(_recipe('r'));
      final current = (await repo.get('r'))!;
      await repo.update(
        current.copyWith(imagePath: 'recipe_photos/mine.jpg'),
        kind: ChangeKind.manual,
      );
      expect((await repo.get('r'))!.imageSource, RecipeImageSource.user);

      expect(await repo.attachAiImage('r', 'recipe_photos/$_file'), isFalse);
      final saved = (await repo.get('r'))!;
      expect(saved.imagePath, 'recipe_photos/mine.jpg');
      expect(saved.imageSource, RecipeImageSource.user);
    });

    test('a user photo replaces an AI image and becomes the user\'s', () async {
      await repo.create(_recipe('r'));
      await repo.attachAiImage('r', 'recipe_photos/$_file');
      final current = (await repo.get('r'))!;
      await repo.update(
        current.copyWith(imagePath: 'recipe_photos/mine.jpg'),
        kind: ChangeKind.manual,
      );
      expect((await repo.get('r'))!.imageSource, RecipeImageSource.user);
    });

    test('an edit and undo keep the AI image', () async {
      await repo.create(_recipe('r'));
      final before = (await repo.get('r'))!;
      await repo.update(
        before.copyWith(title: 'Prebranac'),
        kind: ChangeKind.manual,
      );
      // Slika stiže posle izmene: verzija je nema.
      await repo.attachAiImage('r', 'recipe_photos/$_file');
      await repo.undoLast('r');
      final saved = (await repo.get('r'))!;
      expect(saved.title, 'Pasulj r');
      expect(saved.imagePath, 'recipe_photos/$_file');
      expect(saved.imageSource, RecipeImageSource.ai);
      expect(saved.imageDescription, isNotNull);
    });

    test('the fallback description is saved only when missing', () async {
      await repo.create(_recipe('r', description: null));
      await repo.setImageDescription('r', 'First description.');
      await repo.setImageDescription('r', 'Second description.');
      expect((await repo.get('r'))!.imageDescription, 'First description.');
    });
  });

  group('queue ordering', () {
    test('nearest planned day first, then unplanned by age', () {
      final ordered = orderImageJobs([
        RecipeImageJob(recipeId: 'old', createdAt: DateTime.utc(2026)),
        RecipeImageJob(
          recipeId: 'friday',
          createdAt: DateTime.utc(2026, 11, 20),
          nextPlannedDay: DateTime.utc(2026, 11, 27),
        ),
        RecipeImageJob(recipeId: 'new', createdAt: DateTime.utc(2026, 11)),
        RecipeImageJob(
          recipeId: 'today',
          createdAt: DateTime.utc(2026, 11, 22),
          nextPlannedDay: DateTime.utc(2026, 11, 23),
        ),
      ]);
      expect(ordered.map((j) => j.recipeId), ['today', 'friday', 'old', 'new']);
    });

    test('the store uses upcoming, uncooked plan entries', () async {
      for (final id in ['a', 'b', 'c']) {
        await queueAiImage(db, _scope, id, DateTime.utc(2026, 11));
      }
      Future<void> entry(
        String id,
        String recipe,
        DateTime day, {
        bool cooked = false,
      }) => db
          .into(db.mealPlanEntries)
          .insert(
            MealPlanEntriesCompanion.insert(
              id: id,
              planId: 'plan',
              date: day,
              mealType: 'lunch',
              recipeId: Value(recipe),
              householdId: const Value('h1'),
              isCooked: Value(cooked),
            ),
          );
      await entry('e1', 'b', DateTime.utc(2026, 11, 25));
      await entry('e2', 'c', DateTime.utc(2026, 11, 24));
      await entry('e3', 'a', DateTime.utc(2026, 11, 20)); // prošao
      await entry('e4', 'a', DateTime.utc(2026, 11, 23), cooked: true);
      final due = await jobs.due(now, today: DateTime.utc(2026, 11, 23));
      expect(due.map((j) => j.recipeId), ['c', 'b', 'a']);
    });
  });

  group('RecipeImageQueue', () {
    late List<RecipeImageResult> answers;
    late List<(String, String)> requests;
    late List<String> described;

    RecipeImageQueue queue({String Function(Recipe)? describe}) =>
        RecipeImageQueue(
          jobs: jobs,
          recipes: repo,
          client: RecipeImageClient((body) async {
            requests.add((
              body['recipeId']! as String,
              body['description']! as String,
            ));
            final next = answers.removeAt(0);
            return switch (next) {
              RecipeImageReady(:final file) => () {
                remote.objects['h1/$file'] = _jpeg;
                return FunctionResponse(status: 200, data: {'file': file});
              }(),
              RecipeImageDeferred(:final retryAfter) => FunctionResponse(
                status: 429,
                data: {
                  'error': 'quota_exceeded',
                  'limit': 'user',
                  'retryAfterSeconds': retryAfter.inSeconds,
                },
              ),
              RecipeImageDisabled() => const FunctionResponse(
                status: 503,
                data: {'error': 'disabled'},
              ),
              _ => const FunctionResponse(
                status: 502,
                data: {'error': 'provider_error'},
              ),
            };
          }),
          photos: remote,
          store: store,
          scope: _scope,
          describe: (recipe) async {
            described.add(recipe.id);
            if (describe == null) throw Exception('no AI');
            return describe(recipe);
          },
          clock: () => now,
        );

    setUp(() {
      answers = [];
      requests = [];
      described = [];
    });

    test(
      'a ready image is downloaded, attached and leaves the queue',
      () async {
        await repo.create(_recipe('r'));
        answers = [const RecipeImageReady(_file)];
        final q = queue();
        await q.run();
        q.stop();
        expect(requests, [('r', 'Beans in a clay pot, top-down.')]);
        final saved = (await repo.get('r'))!;
        expect(saved.imagePath, 'recipe_photos/$_file');
        expect(saved.imageSource, RecipeImageSource.ai);
        expect(store.saved['recipe_photos/$_file'], _jpeg);
        expect(await queued(), isEmpty);
      },
    );

    test('a recipe without a description gets one from the fallback '
        'call', () async {
      await repo.create(_recipe('r', description: null));
      answers = [const RecipeImageReady(_file)];
      final q = queue(describe: (_) => 'Rolled cabbage parcels in sauce.');
      await q.run();
      q.stop();
      expect(described, ['r']);
      expect(requests.single.$2, 'Rolled cabbage parcels in sauce.');
      expect(
        (await repo.get('r'))!.imageDescription,
        'Rolled cabbage parcels in sauce.',
      );
    });

    test('a user photo that arrives first leaves the queue without a '
        'request', () async {
      await repo.create(_recipe('r'));
      final current = (await repo.get('r'))!;
      await repo.update(
        current.copyWith(imagePath: 'recipe_photos/mine.jpg'),
        kind: ChangeKind.manual,
      );
      // Posao je i dalje u redu, ali recept više ne želi AI sliku.
      final q = queue();
      await q.run();
      q.stop();
      expect(requests, isEmpty);
      expect(await queued(), isEmpty);
      expect((await repo.get('r'))!.imagePath, 'recipe_photos/mine.jpg');
    });

    test('quota defers every job until the reset, then retries', () async {
      await repo.create(_recipe('a', createdAt: DateTime.utc(2026, 11)));
      await repo.create(_recipe('b', createdAt: DateTime.utc(2026, 11, 2)));
      answers = [const RecipeImageDeferred(Duration(hours: 2))];
      final q = queue();
      await q.run();
      expect(requests.map((r) => r.$1), ['a']);
      expect(await queued(), unorderedEquals(['a', 'b']));

      await q.run();
      expect(requests, hasLength(1), reason: 'still paused');

      now = now.add(const Duration(hours: 2, minutes: 1));
      answers = [
        const RecipeImageReady(_file),
        const RecipeImageReady('ai_00000000-0000-4000-8000-000000000002.jpg'),
      ];
      await q.onResume();
      q.stop();
      expect(requests.map((r) => r.$1), ['a', 'a', 'b']);
      expect(await queued(), isEmpty);
    });

    test('provider errors retry later and give up after three', () async {
      await repo.create(_recipe('r'));
      answers = [
        const RecipeImageFailed(),
        const RecipeImageFailed(),
        const RecipeImageFailed(),
      ];
      final q = queue();
      for (var i = 0; i < 3; i++) {
        await q.run();
        now = now.add(const Duration(hours: 1));
      }
      q.stop();
      expect(requests, hasLength(3));
      expect(await queued(), isEmpty);
      expect((await repo.get('r'))!.imagePath, isNull);
    });

    test('being offline never drops a recipe', () async {
      await repo.create(_recipe('r'));
      final q = RecipeImageQueue(
        jobs: jobs,
        recipes: repo,
        client: RecipeImageClient((_) async {
          requests.add(('r', ''));
          throw Exception('no network');
        }),
        photos: remote,
        store: store,
        scope: _scope,
        describe: (_) async => '',
        clock: () => now,
      );
      for (var i = 0; i < 5; i++) {
        await q.run();
        now = now.add(const Duration(hours: 1));
      }
      q.stop();
      expect(requests, hasLength(5));
      final row = await db.select(db.recipeImageJobs).getSingle();
      expect(row.attempts, 0);
    });

    test('exhausted text models defer the description without dropping '
        'the recipe', () async {
      await repo.create(_recipe('r', description: null));
      final q = queue(
        describe: (_) => throw AllModelsExhausted(
          const [],
          nextAvailableAt: now.add(const Duration(minutes: 30)),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await q.run();
        now = now.add(const Duration(hours: 1));
      }
      q.stop();
      expect(described, hasLength(4));
      expect(requests, isEmpty);
      expect(await queued(), ['r']);
    });

    test('a zero retry never spins the queue', () async {
      await repo.create(_recipe('r'));
      answers = [const RecipeImageDeferred(Duration.zero)];
      final q = queue();
      await q.run();
      await q.run();
      q.stop();
      expect(requests, hasLength(1));
    });

    test('a user photo added while the image is generated wins and the AI '
        'image is removed', () async {
      await repo.create(_recipe('r'));
      final q = RecipeImageQueue(
        jobs: jobs,
        recipes: repo,
        client: RecipeImageClient((_) async {
          remote.objects['h1/$_file'] = _jpeg;
          final current = (await repo.get('r'))!;
          await repo.update(
            current.copyWith(imagePath: 'recipe_photos/mine.jpg'),
            kind: ChangeKind.manual,
          );
          return const FunctionResponse(status: 200, data: {'file': _file});
        }),
        photos: remote,
        store: store,
        scope: _scope,
        describe: (_) async => '',
        clock: () => now,
      );
      await q.run();
      q.stop();
      final saved = (await repo.get('r'))!;
      expect(saved.imagePath, 'recipe_photos/mine.jpg');
      expect(saved.imageSource, RecipeImageSource.user);
      expect(remote.removed, ['h1/$_file']);
      expect(store.saved, isEmpty);
      expect(await queued(), isEmpty);
    });

    test('a disabled server pauses the queue until resume', () async {
      await repo.create(_recipe('r'));
      answers = [const RecipeImageDisabled(), const RecipeImageReady(_file)];
      final q = queue();
      await q.run();
      await q.run();
      expect(requests, hasLength(1));
      expect(await queued(), ['r']);
      await q.onResume();
      q.stop();
      expect(requests, hasLength(2));
      expect(await queued(), isEmpty);
    });
  });
}
