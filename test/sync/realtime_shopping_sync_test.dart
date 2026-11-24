import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/shopping_repository.dart';
import 'package:tavli/sync/downloader.dart';
import 'package:tavli/sync/realtime_sync.dart';
import 'package:tavli/sync/sync_engine.dart';
import 'package:tavli/sync/synced_writer.dart';
import 'package:tavli/sync/uploader.dart';

import '../helpers/fake_backend.dart';
import '../helpers/fake_photo_store.dart';
import '../helpers/fake_timers.dart';

void main() {
  test(
    'one account on two devices receives shared edits and deletes',
    () async {
      final first = FakeBackend();
      final a = await _Device.create(first, 'solo@example.test');
      final b = await _Device.create(
        FakeBackend(sharedServer: first.server),
        'solo@example.test',
      );
      addTearDown(a.close);
      addTearDown(b.close);
      expect(b.scope.userId, a.scope.userId);
      final timers = FakeTimers();
      final signals = _SoloSignals();
      var finished = Completer<void>();
      final realtime = RealtimeSync(
        remote: signals,
        userId: b.scope.userId,
        householdId: b.scope.householdId,
        refreshMembership: () async {},
        pull: () async {
          final result = await b.engine.pullAfterCurrent();
          finished.complete();
          return result;
        },
        timer: timers.call,
      );
      addTearDown(realtime.dispose);
      realtime.setForeground(true);
      signals.accountReady(true);
      await finished.future;
      final list = await a.shopping.recipeList();
      final item = await a.shopping.addManual(list, 'So');
      await a.engine.push();
      finished = Completer<void>();
      signals.householdChanged();
      await timers.fire(const Duration(milliseconds: 250));
      await finished.future;
      expect((await b.shopping.listItems(list)).single.id, item);
      await a.shopping.deleteManual(item);
      await a.engine.push();
      finished = Completer<void>();
      signals.householdChanged();
      await timers.fire(const Duration(milliseconds: 250));
      await finished.future;
      expect(await b.shopping.listItems(list), isEmpty);
    },
  );

  for (final aFirst in [true, false]) {
    test(
      'independent shopping edits and deletion converge (A first: $aFirst)',
      () async {
        final previous = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        addTearDown(() {
          driftRuntimeOptions.dontWarnAboutMultipleDatabases = previous;
        });
        final first = FakeBackend();
        final second = FakeBackend(sharedServer: first.server);
        final a = await _Device.create(first, 'a@example.test');
        final b = await _Device.create(
          second,
          'b@example.test',
          a.scope.householdId,
        );
        addTearDown(a.close);
        addTearDown(b.close);
        final list = await a.shopping.recipeList();
        final milk = await a.shopping.addManual(list, 'Mleko');
        final bread = await a.shopping.addManual(list, 'Hleb', quantity: 1);
        final salt = await a.shopping.addManual(list, 'So');
        await a.engine.push();
        await b.engine.pull();

        first.server.offline = true;
        expect(await a.shopping.setBought([milk], bought: true), 1);
        expect(await a.shopping.deleteManual(salt), isTrue);
        await a.engine.push();
        await b.db.transaction(() async {
          await (b.db.update(b.db.shoppingItems)
                ..where((row) => row.id.equals(bread)))
              .write(const ShoppingItemsCompanion(quantity: Value(2)));
          await b.writer.upsert('shopping_item', bread);
        });
        await b.engine.push();
        expect(await a.db.select(a.db.syncOutbox).get(), hasLength(2));
        expect(await b.db.select(b.db.syncOutbox).get(), hasLength(1));

        first.server.offline = false;
        final order = aFirst ? [a, b] : [b, a];
        for (final device in order) {
          await device.engine.push();
          await device.engine.pullAfterCurrent();
        }
        // Requeue the same acknowledged edit and pull twice as if duplicate
        // invalidations arrived. Independent edits and the tombstone survive.
        await b.writer.upsert('shopping_item', bread);
        await b.engine.push();
        for (final device in [a, b]) {
          await device.engine.pullAfterCurrent();
          await device.engine.pullAfterCurrent();
          final items = await device.shopping.listItems(list);
          expect(items.map((item) => item.id), unorderedEquals([milk, bread]));
          expect(items.singleWhere((item) => item.id == milk).isBought, isTrue);
          expect(items.singleWhere((item) => item.id == bread).quantity, 2);
          expect(await device.db.select(device.db.syncOutbox).get(), isEmpty);
        }
        expect(
          first.server.table('shopping_items').keys,
          unorderedEquals([milk, bread]),
        );
      },
    );
  }
}

class _Device {
  _Device(this.db, this.scope, FakeBackend backend) {
    writer = SyncedWriter(db, accountId: scope.userId);
    shopping = ShoppingRepository(db, scope: scope, writer: writer);
    engine = SyncEngine(
      db: db,
      scope: scope,
      uploader: Uploader(
        db: db,
        remote: backend.sync,
        photos: backend.photos,
        photoStore: FakePhotoStore(),
        scope: scope,
        refreshSession: () async => true,
      ),
      downloader: Downloader(db: db, remote: backend.sync, scope: scope),
    );
  }

  final AppDatabase db;
  final AccountScope scope;
  late final SyncEngine engine;
  late final SyncedWriter writer;
  late final ShoppingRepository shopping;

  static Future<_Device> create(
    FakeBackend backend,
    String email, [
    String? householdId,
  ]) async {
    final user = await backend.auth.verifyCode(email, FakeServer.code);
    final home = householdId ?? backend.server.households[user.userId]!;
    backend.server.households[user.userId] = home;
    final db = AppDatabase(NativeDatabase.memory());
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            userId: user.userId,
            email: email,
            householdId: home,
            householdName: 'Synthetic',
            role: householdId == null ? 'owner' : 'member',
            createdAt: DateTime.utc(2026, 11),
          ),
        );
    return _Device(
      db,
      AccountScope(userId: user.userId, householdId: home),
      backend,
    );
  }

  Future<void> close() async {
    engine.stop();
    await db.close();
  }
}

class _SoloSignals implements SyncSignalRemote {
  late void Function(bool) accountReady;
  late void Function() householdChanged;

  @override
  Future<bool?> householdEligible(String householdId) async => true;

  @override
  void Function() subscribe({
    required SyncSignalScope scope,
    required String id,
    required void Function(bool) onConnection,
    required void Function() onSignal,
  }) {
    if (scope == SyncSignalScope.account) {
      accountReady = onConnection;
    } else {
      householdChanged = onSignal;
    }
    return () {};
  }
}
