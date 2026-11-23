import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase/supabase.dart';

import 'account/account_api.dart';
import 'account/account_service.dart';
import 'account/auth_controller.dart';
import 'account/auth_gateway.dart';
import 'account/session_store.dart';
import 'account/supabase_client.dart';
import 'account/supabase_config.dart';
import 'ai/ai_router.dart';
import 'ai/chain_config.dart';
import 'ai/chat_client.dart';
import 'ai/gateway_chat_client.dart';
import 'ai/key_store.dart';
import 'ai/meal_plan_ai.dart';
import 'ai/pantry_ai.dart';
import 'ai/recipe_ai.dart';
import 'data/allergen_repository.dart';
import 'data/database.dart';
import 'data/drift_model_status_store.dart';
import 'data/favorite_repository.dart';
import 'data/food_catalog_reader.dart';
import 'data/planning_sharing_repository.dart';
import 'data/planning_tastes_remote.dart';
import 'data/shopping_repository.dart';
import 'data/taste_profile_repository.dart';
import 'domain/planning_tastes.dart';
import 'features/planning/planning_providers.dart';
import 'features/recipes/recipe_providers.dart';
import 'sync/downloader.dart';
import 'sync/legacy_mover.dart';
import 'sync/photo_sync.dart';
import 'sync/realtime_sync.dart';
import 'sync/supabase_sync_signals.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_remote.dart';
import 'sync/synced_writer.dart';
import 'sync/uploader.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => const SessionStore(KeychainSecretStorage()),
);

/// Adresa i anon ključ iz `--dart-define-from-file=secrets.json`.
final supabaseConfigProvider = Provider<SupabaseConfig>(
  (ref) => SupabaseConfig.fromEnvironment(),
);

/// null kad build nema Supabase podešavanja (prijava tada nije dostupna).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final config = ref.watch(supabaseConfigProvider);
  if (!config.isConfigured) return null;
  final client = createSupabaseClient(
    config,
    secrets: const KeychainSecretStorage(),
  );
  ref.onDispose(client.dispose);
  return client;
});

final authGatewayProvider = Provider<AuthGateway>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null
      ? const UnconfiguredAuthGateway()
      : SupabaseAuthGateway(client);
});

/// Linkovi kojima je aplikacija otvorena (tavli://auth-callback iz mejla
/// za potvrdu), uključujući onaj kojim je pokrenuta; menja se u testovima.
final appLinksProvider = Provider<Stream<Uri>>(
  (ref) => AppLinks().uriLinkStream,
);

/// Vreme za prijavu (kada je poslat kod); menja se u testovima.
final authClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final accountApiProvider = Provider<AccountApi>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null
      ? const UnconfiguredAccountApi()
      : SupabaseAccountApi(client);
});

/// Nalog na uređaju: keš profila i domaćinstva, ime, brisanje.
final accountServiceProvider = Provider<AccountService>(
  (ref) => AccountService(
    ref.watch(databaseProvider),
    ref.watch(accountApiProvider),
    photos: ref.watch(recipePhotoStoreProvider),
    keys: ref.watch(keyStoreProvider),
    onChange: () => ref.read(syncEngineProvider)?.kick(),
  ),
);

/// Upisuje izmene prijavljenog naloga u red za slanje i budi slanje.
final Provider<SyncedWriter> syncedWriterProvider = Provider<SyncedWriter>(
  (ref) => SyncedWriter(
    ref.watch(databaseProvider),
    accountId: (ref.watch(accountScopeProvider) ?? noAccountScope).userId,
    onChange: () => ref.read(syncEngineProvider)?.kick(),
  ),
);

final syncRemoteProvider = Provider<SyncRemote?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseSyncRemote(client);
});

final photoRemoteProvider = Provider<PhotoRemote?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabasePhotoRemote(client);
});

/// Obnavlja sesiju posle odgovora 401; false kad je obnova odbijena.
Future<bool> _refreshSession(Ref ref) async {
  final gateway = ref.read(authGatewayProvider);
  final store = ref.read(sessionStoreProvider);
  try {
    final session = await gateway.refresh();
    await store.write(session.json);
    return true;
  } on Offline {
    return true; // sledeće slanje će naići na mrežu i sačekati
  } on Unavailable {
    return true;
  } on AccountGone {
    // Nalog obrisan na drugom uređaju: i njegov keš ovde se briše.
    await ref
        .read(authControllerProvider.notifier)
        .sessionExpired(accountGone: true);
    return false;
  } on AuthFailure {
    return false;
  }
}

/// Slanje i preuzimanje za prijavljen nalog; null bez naloga ili servera.
/// Nov nalog → nov engine (stari se zaustavlja).
final Provider<SyncEngine?> syncEngineProvider = Provider<SyncEngine?>((ref) {
  final verified = ref.watch(
    authControllerProvider.select(
      (state) => state is SignedIn && state.membershipVerified,
    ),
  );
  if (!verified) return null;
  final scope = ref.watch(accountScopeProvider);
  final remote = ref.watch(syncRemoteProvider);
  final photos = ref.watch(photoRemoteProvider);
  if (scope == null || remote == null || photos == null) return null;
  final db = ref.watch(databaseProvider);
  // Reconciliation only touches the cache and never queues an upload.
  final favorites = FavoriteRepository(
    db,
    scope: scope,
    writer: SyncedWriter(db, accountId: scope.userId),
  );
  late final SyncEngine engine;
  engine = SyncEngine(
    db: db,
    scope: scope,
    uploader: Uploader(
      db: db,
      remote: remote,
      photos: photos,
      photoStore: ref.watch(recipePhotoStoreProvider),
      scope: scope,
      refreshSession: () => _refreshSession(ref),
      beforeFavoriteUpload: favorites.dropStaleFavorites,
    ),
    downloader: Downloader(db: db, remote: remote, scope: scope),
    photoSync: PhotoSync(
      db: db,
      remote: photos,
      store: ref.watch(recipePhotoStoreProvider),
      scope: scope,
    ),
    legacyMover: LegacyMover(db),
    refreshSession: () => _refreshSession(ref),
    onUnauthorized: () =>
        ref.read(authControllerProvider.notifier).sessionExpired(),
    // A removed member's writes are denied by RLS: re-check membership, which
    // quarantines old-household writes and switches the scope.
    onForbidden: () =>
        ref.read(authControllerProvider.notifier).recheckMembership(engine),
    // Ceo red obroka može da stigne zastareo; oznaka „skuvano“ se ponovo
    // izvodi iz zapisa kuvanja.
    afterPull: () async {
      await ref.read(cookingRepositoryProvider).reconcileCookedFlags();
      await favorites.dropStaleFavorites();
    },
  );
  ref.onDispose(engine.stop);
  unawaited(engine.onStart());
  return engine;
});

final realtimeSyncProvider = Provider.autoDispose<RealtimeSync?>((ref) {
  final scope = ref.watch(accountScopeProvider);
  final engine = ref.watch(syncEngineProvider);
  final client = ref.watch(supabaseClientProvider);
  if (scope == null || engine == null || client == null) return null;
  final realtime = RealtimeSync(
    remote: SupabaseSyncSignals(client),
    userId: scope.userId,
    householdId: scope.householdId,
    refreshMembership: () =>
        ref.read(authControllerProvider.notifier).restoreSession(sync: engine),
    pull: engine.pullAfterCurrent,
  );
  ref.onDispose(realtime.dispose);
  return realtime;
});

/// Stanje čuvanja u nalogu za "Profil".
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine == null ? Stream.value(const AllSaved()) : engine.watchStatus();
});

/// Broj prebačenih starih zapisa, kad stignu na server.
final movedSavedProvider = StreamProvider<int>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine == null ? const Stream.empty() : engine.watchMovedSaved();
});

final syncPhaseProvider = StreamProvider<SyncPhase?>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine == null ? Stream.value(null) : engine.watchPhase();
});

final keyStoreProvider = Provider<KeyStore>((ref) => SecureKeyStore());

/// Stari izvor postoji za testne zamene. App učitava deljene modele sa servera.
final builtInKeysProvider = Provider<BuiltInKeys>((ref) => const BuiltInKeys());

final keySourceProvider = Provider<KeySource>(
  (ref) => LayeredKeySource(
    ref.watch(keyStoreProvider),
    ref.watch(builtInKeysProvider),
  ),
);

class ChainConfigNotifier extends Notifier<ChainConfig> {
  @override
  ChainConfig build() => ChainConfig.defaults;

  // Čuvanje u bazi dolazi sa ekranom "AI modeli" (Faza 7).
  void set(ChainConfig config) => state = config;
}

final chainConfigProvider = NotifierProvider<ChainConfigNotifier, ChainConfig>(
  ChainConfigNotifier.new,
);

final chatClientProvider = Provider<OpenAICompatibleClient>(
  (ref) => OpenAICompatibleClient(),
);

final gatewayChatClientProvider = Provider<GatewayChatClient?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null
      ? null
      : GatewayChatClient.supabase(client, refresh: () => _refreshSession(ref));
});

final aiRouterProvider = Provider<AIRouter>(
  (ref) => AIRouter(
    config: () => ref.read(chainConfigProvider),
    client: ref.watch(chatClientProvider),
    keys: ref.watch(keySourceProvider),
    status: DriftModelStatusStore(ref.watch(databaseProvider)),
    gateway: ref.watch(gatewayChatClientProvider),
  ),
);

final recipeAIProvider = Provider<RecipeAI>(
  (ref) => RecipeAI(ref.watch(aiRouterProvider)),
);

/// Ukusi članova za plan (TRELLO-41); bez Supabase klijenta nema ukusa.
final planningTastesProvider = Provider<PlanningTastesSource?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  final db = ref.watch(databaseProvider);
  return RemotePlanningTastes.supabase(
    client,
    householdId: () => ref.read(accountScopeProvider)?.householdId,
    foodNames: (household) async => {
      for (final food in await CatalogFoodList(
        db,
      ).watchVisible(household).first)
        food.id: food.name,
    },
  );
});

final mealPlanAIProvider = Provider<MealPlanAI>(
  (ref) => MealPlanAI(
    ref.watch(aiRouterProvider),
    tastes: ref.watch(planningTastesProvider),
  ),
);

final pantryAIProvider = Provider<PantryAI>(
  (ref) => PantryAI(ref.watch(aiRouterProvider)),
);

/// Lista prijavljenog domaćinstva; demo koristi zasebnu bazu u memoriji.
final shoppingRepositoryProvider = Provider<ShoppingRepository>(
  (ref) => ShoppingRepository(
    ref.watch(databaseProvider),
    scope: ref.watch(accountScopeProvider) ?? noAccountScope,
    writer: ref.watch(syncedWriterProvider),
    clock: ref.watch(clockProvider),
  ),
);

final favoriteRepositoryProvider = Provider<FavoriteRepository>(
  (ref) => FavoriteRepository(
    ref.watch(databaseProvider),
    scope: ref.watch(accountScopeProvider) ?? noAccountScope,
    writer: ref.watch(syncedWriterProvider),
  ),
);

final allergenRepositoryProvider = Provider<AllergenRepository>((ref) {
  final scope = ref.watch(accountScopeProvider) ?? noAccountScope;
  return AllergenRepository(
    ref.watch(databaseProvider),
    scope: scope,
    writer: ref.watch(syncedWriterProvider),
  );
});

final tasteProfileRepositoryProvider = Provider<TasteProfileRepository>((ref) {
  final scope = ref.watch(accountScopeProvider) ?? noAccountScope;
  return TasteProfileRepository(
    ref.watch(databaseProvider),
    scope: scope,
    writer: ref.watch(syncedWriterProvider),
  );
});

final planningSharingRepositoryProvider = Provider<PlanningSharingRepository?>((
  ref,
) {
  final scope = ref.watch(accountScopeProvider);
  final client = ref.watch(supabaseClientProvider);
  if (scope == null || client == null) return null;
  return SupabasePlanningSharingRepository(client, userId: scope.userId);
});
