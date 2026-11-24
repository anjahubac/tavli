import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/key_store.dart';
import '../../data/database.dart';
import '../../providers.dart';

/// Redosled korisnikovih ključeva; čuva se u AppSettings, samo na uređaju.
class OwnKeyOrderNotifier extends AsyncNotifier<OwnKeyOrder> {
  static const settingKey = 'own_key_order';

  @override
  Future<OwnKeyOrder> build() async {
    final db = ref.watch(databaseProvider);
    final row = await (db.select(
      db.appSettings,
    )..where((t) => t.key.equals(settingKey))).getSingleOrNull();
    return OwnKeyOrder.values.asNameMap()[row?.value] ?? OwnKeyOrder.paidFirst;
  }

  Future<void> set(OwnKeyOrder order) async {
    state = AsyncData(order);
    final db = ref.read(databaseProvider);
    await db
        .into(db.appSettings)
        .insert(
          AppSettingsCompanion.insert(key: settingKey, value: order.name),
          mode: InsertMode.insertOrReplace,
        );
  }
}

final ownKeyOrderProvider =
    AsyncNotifierProvider<OwnKeyOrderNotifier, OwnKeyOrder>(
      OwnKeyOrderNotifier.new,
    );
