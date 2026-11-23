import 'dart:async';

import '../../account/auth_controller.dart';
import '../../ai/ai_errors.dart';
import '../../ai/recipe_image_client.dart';
import '../../data/recipe_image_jobs.dart';
import '../../data/recipe_photo_store.dart';
import '../../data/recipe_repository.dart';
import '../../domain/plan_calendar.dart';
import '../../domain/recipe.dart';
import '../../sync/entities.dart';
import '../../sync/sync_remote.dart';

/// Opis slike kad ga AI recept nema (rezervni poziv kroz AIRouter).
typedef DescribeRecipeImage = Future<String> Function(Recipe recipe);

/// Pravi AI slike za AI recepte u pozadini (TRELLO-130). Ne blokira
/// ekran; recept bez slike prikazuje zamensku sliku dok slika ne stigne.
///
/// Red je lokalni ([RecipeImageJobStore]). Limit (korisnik, projekat,
/// Cloudflare) odlaže sve poslove do isteka; posao se ponovo pokušava pri
/// pokretanju, povratku u aplikaciju ili kad istekne odlaganje, a recepti iz
/// plana idu po najbližem danu. AI slika nikad ne zamenjuje sliku korisnika
/// ([RecipeRepository.attachAiImage]).
class RecipeImageQueue {
  RecipeImageQueue({
    required this._jobs,
    required this._recipes,
    required this._client,
    required this._photos,
    required this._store,
    required this._scope,
    required this._describe,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RecipeImageJobStore _jobs;
  final RecipeRepository _recipes;
  final RecipeImageClient _client;
  final PhotoRemote _photos;
  final RecipePhotoStore _store;
  final AccountScope _scope;
  final DescribeRecipeImage _describe;
  final DateTime Function() _clock;

  /// Posle ovoliko neuspelih pokušaja (greška provajdera) recept odustaje.
  static const maxFailures = 3;

  /// Pauza posle greške provajdera ili opisa, puta broj pokušaja.
  static const failurePause = Duration(minutes: 10);

  /// Pauza kad nema mreže; sledeći povratak u aplikaciju ne čeka duže.
  static const offlinePause = Duration(minutes: 2);

  /// Pauza kad su tekstualni modeli iscrpljeni a ne zna se do kada.
  static const describePause = Duration(hours: 1);

  /// Najkraće odlaganje: server može da vrati 0, a red ne sme da se vrti.
  static const minPause = Duration(minutes: 1);

  bool _running = false;
  bool _again = false;
  bool _stopped = false;

  /// Isključeno na serveru ili sesija ne važi: do sledećeg pokretanja.
  bool _paused = false;
  StreamSubscription<void>? _watch;
  Timer? _timer;

  /// Prati red i obrađuje ga kad se promeni (nov AI recept).
  void start() {
    _watch ??= _jobs.watch().listen((_) => unawaited(run()));
  }

  void stop() {
    _stopped = true;
    unawaited(_watch?.cancel());
    _timer?.cancel();
  }

  /// Povratak u aplikaciju: limit je možda istekao.
  Future<void> onResume() {
    _paused = false;
    return run();
  }

  /// Obrađuje sve poslove koji su na redu. Istovremen poziv samo traži još
  /// jedan prolaz posle tekućeg.
  Future<void> run() async {
    if (_stopped || _paused) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _pass();
      } while (_again && !_stopped && !_paused);
    } finally {
      _running = false;
    }
    await _schedule();
  }

  Future<void> _pass() async {
    final now = _clock();
    final today = CivilDate.today(_clock).toWire();
    for (final job in await _jobs.due(now, today: today)) {
      if (_stopped || _paused) return;
      if (!await _process(job)) return;
    }
  }

  /// false = stani (limit, isključeno); ostali poslovi čekaju.
  Future<bool> _process(RecipeImageJob job) async {
    final recipe = await _recipes.get(job.recipeId);
    if (recipe == null || !recipe.wantsAiImage) {
      await _jobs.remove(job.recipeId);
      return true;
    }

    var description = recipe.imageDescription;
    if (description == null) {
      try {
        description = await _describe(recipe);
        await _recipes.setImageDescription(recipe.id, description);
      } on AllModelsExhausted catch (e) {
        // Neispravan odgovor je neuspeh; limit ili mreža nisu.
        if (e.invalidOutput || e.repairFailed || e.emptyOutput) {
          await _fail(job);
        } else {
          final until = e.nextAvailableAt ?? _clock().add(describePause);
          await _jobs.defer(job.recipeId, _notBefore(until));
        }
        return true;
      } on Exception {
        await _fail(job);
        return true;
      }
    }

    if (_stopped) return false;
    final result = await _client.generate(recipe.id, description);
    switch (result) {
      case RecipeImageReady(:final file):
        await _attach(recipe.id, file);
        await _jobs.remove(recipe.id);
        return true;
      case RecipeImageDeferred(:final retryAfter):
        await _jobs.deferAll(_notBefore(_clock().add(retryAfter)));
        return false;
      case RecipeImageOffline():
        await _jobs.deferAll(_clock().add(offlinePause));
        return false;
      case RecipeImageDisabled() || RecipeImageUnauthorized():
        _paused = true;
        return false;
      case RecipeImageRejected():
        await _jobs.remove(recipe.id);
        return true;
      case RecipeImageFailed():
        await _fail(job);
        return true;
    }
  }

  DateTime _notBefore(DateTime until) {
    final earliest = _clock().add(minPause);
    return until.isBefore(earliest) ? earliest : until;
  }

  Future<void> _fail(RecipeImageJob job) async {
    final attempts = job.attempts + 1;
    if (attempts >= maxFailures) {
      await _jobs.remove(job.recipeId);
    } else {
      await _jobs.defer(
        job.recipeId,
        _clock().add(failurePause * attempts),
        failed: true,
      );
    }
  }

  /// Preuzima gotovu sliku i upisuje je u recept. Ako je recept u
  /// međuvremenu dobio sliku korisnika ili je obrisan, slika se briše.
  Future<void> _attach(String recipeId, String file) async {
    final path = photoLocalPath(file)!;
    final key = '${_scope.householdId}/$file';
    try {
      final bytes = await _photos.download(key);
      await _store.write(path, bytes);
    } on Exception {
      // Slika je na serveru; preuzimanje slika (PhotoSync) pokušava ponovo.
    }
    if (!await _recipes.attachAiImage(recipeId, path)) {
      try {
        await _store.delete(path);
        await _photos.remove([key]);
      } on Exception {
        // Ostaje siroče na serveru; ne utiče na recepte.
      }
    }
  }

  /// Budi se kad istekne najranije odlaganje (dok je aplikacija otvorena).
  Future<void> _schedule() async {
    _timer?.cancel();
    if (_stopped || _paused) return;
    final next = await _jobs.nextRetryAt();
    if (next == null) return;
    final wait = next.difference(_clock());
    if (wait > const Duration(hours: 24)) return;
    _timer = Timer(
      wait.isNegative ? Duration.zero : wait + const Duration(seconds: 1),
      () => unawaited(run()),
    );
  }
}
