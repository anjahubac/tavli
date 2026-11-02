import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account/auth_controller.dart';
import 'ai/ai_router.dart';
import 'ai/chain_config.dart';
import 'ai/chat_client.dart';
import 'ai/key_store.dart';
import 'ai/recipe_ai.dart';
import 'data/database.dart';
import 'data/drift_model_status_store.dart';
import 'sync/synced_writer.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Upisuje izmene prijavljenog naloga u red za slanje.
final syncedWriterProvider = Provider<SyncedWriter>(
  (ref) => SyncedWriter(
    ref.watch(databaseProvider),
    accountId: (ref.watch(accountScopeProvider) ?? noAccountScope).userId,
  ),
);

final keyStoreProvider = Provider<KeyStore>((ref) => SecureKeyStore());

/// Ugrađeni ključevi iz `--dart-define-from-file=secrets.json`.
final builtInKeysProvider = Provider<BuiltInKeys>(
  (ref) => BuiltInKeys.fromEnvironment(),
);

/// Sopstveni ključ pa ugrađeni. Kasnije ga menja Cloudflare proxy.
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

final aiRouterProvider = Provider<AIRouter>(
  (ref) => AIRouter(
    config: () => ref.read(chainConfigProvider),
    client: ref.watch(chatClientProvider),
    keys: ref.watch(keySourceProvider),
    status: DriftModelStatusStore(ref.watch(databaseProvider)),
  ),
);

final recipeAIProvider = Provider<RecipeAI>(
  (ref) => RecipeAI(ref.watch(aiRouterProvider)),
);
