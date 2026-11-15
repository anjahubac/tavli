import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/shopping_repository.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/shopping_source.dart';
import 'package:tavli/sync/downloader.dart';
import 'package:tavli/sync/synced_writer.dart';
import 'package:tavli/sync/uploader.dart';

import '../helpers/fake_backend.dart';
import '../helpers/fake_photo_store.dart';

void main() {
  test(
    'offline shopping survives restart and syncs to another device',
    () async {
      // Each synthetic device has its own executor and database.
      final previousWarningSetting =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases =
            previousWarningSetting;
      });
      final directory = await Directory.systemTemp.createTemp(
        'tavli-shopping-',
      );
      final deviceFile = File('${directory.path}/device.sqlite');
      AppDatabase? first = AppDatabase(NativeDatabase(deviceFile));
      final second = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await first?.close();
        await second.close();
        await directory.delete(recursive: true);
      });

      final backend = FakeBackend();
      final auth = await backend.auth.verifyCode(
        'synthetic@example.test',
        FakeServer.code,
      );
      final scope = AccountScope(
        userId: auth.userId,
        householdId: backend.server.households[auth.userId]!,
      );
      final now = DateTime.utc(2026, 11, 1, 9);
      final monday = CivilDate(2026, 11, 2);

      Future<void> addAccount(AppDatabase db) => db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              userId: scope.userId,
              email: 'synthetic@example.test',
              householdId: scope.householdId,
              householdName: 'Synthetic household',
              role: 'owner',
              createdAt: now,
            ),
          );

      SyncedWriter writer(AppDatabase db) =>
          SyncedWriter(db, accountId: scope.userId, clock: () => now);
      ShoppingRepository shopping(AppDatabase db) => ShoppingRepository(
        db,
        scope: scope,
        writer: writer(db),
        clock: () => now,
      );
      Uploader uploader(AppDatabase db) => Uploader(
        db: db,
        remote: backend.sync,
        photos: backend.photos,
        photoStore: FakePhotoStore(),
        scope: scope,
        refreshSession: () async => true,
        clock: () => now,
      );
      Downloader downloader(AppDatabase db) =>
          Downloader(db: db, remote: backend.sync, scope: scope);

      Future<void> expectLocalShoppingState(AppDatabase db) async {
        final item = await db.select(db.shoppingItems).getSingle();
        final contribution = await db
            .select(db.shoppingContributions)
            .getSingle();
        final allocation = await db.select(db.supplyAllocations).getSingle();
        expect(item.quantity, 200);
        expect(item.unit, 'g');
        expect(contribution.micros, 300000000);
        expect(contribution.shoppingItemId, item.id);
        expect(allocation.contributionId, contribution.id);
        expect(allocation.pantryItemId, 'stock');
        expect(allocation.micros, 100000000);
      }

      await addAccount(first);
      await addAccount(second);
      await first
          .into(first.mealPlans)
          .insert(
            MealPlansCompanion.insert(
              id: 'plan',
              startDate: monday.toWire(),
              endDate: monday.addDays(6).toWire(),
              mealTypesJson: '["lunch"]',
              createdAt: now,
              householdId: Value(scope.householdId),
            ),
          );
      await first
          .into(first.mealPlanEntries)
          .insert(
            MealPlanEntriesCompanion.insert(
              id: 'meal',
              planId: 'plan',
              date: monday.toWire(),
              mealType: 'lunch',
              recipeSnapshotJson: Value(
                jsonEncode(
                  const RecipeSnapshot(
                    title: 'Synthetic recipe',
                    baseServings: 2,
                    ingredients: [
                      Ingredient(name: 'Kupus', quantity: 300, unit: 'g'),
                    ],
                  ).toJson(),
                ),
              ),
              householdId: Value(scope.householdId),
            ),
          );
      await first
          .into(first.pantryItems)
          .insert(
            PantryItemsCompanion.insert(
              id: 'stock',
              name: 'Kupus',
              quantity: const Value(100),
              unit: const Value('g'),
              category: 'ostalo',
              addedAt: now,
              confirmedAt: Value(now),
              householdId: Value(scope.householdId),
            ),
          );
      await writer(first).upsert('meal_plan', 'plan');
      await writer(first).upsert('meal_plan_entry', 'meal');
      await writer(first).upsert('pantry_item', 'stock');
      await shopping(first).reconcilePlan('plan');

      backend.server.offline = true;
      expect((await uploader(first).run()).offline, isTrue);
      final queuedBeforeRestart = await first.select(first.syncOutbox).get();
      expect(queuedBeforeRestart, isNotEmpty);
      expect(
        queuedBeforeRestart.every((row) => row.state == OutboxState.pending),
        isTrue,
      );
      expect(backend.server.rows('shopping_items'), isEmpty);
      await expectLocalShoppingState(first);

      await first.close();
      first = null;
      first = AppDatabase(NativeDatabase(deviceFile));
      final queuedAfterRestart = await first.select(first.syncOutbox).get();
      expect(queuedAfterRestart, unorderedEquals(queuedBeforeRestart));
      await expectLocalShoppingState(first);
      backend.server.offline = false;
      expect((await uploader(first).run()).stoppedBy, isNull);
      expect(await first.select(first.syncOutbox).get(), isEmpty);
      expect(backend.server.rows('shopping_items').single['quantity'], 200);
      expect(backend.server.rows('supply_allocations'), hasLength(1));
      expect(
        backend.server.rows('supply_allocations').single['micros'],
        100000000,
      );
      expect(
        backend.server.rows('shopping_contributions').single['micros'],
        300000000,
      );

      await downloader(second).run();
      final secondList =
          (await second.select(second.shoppingLists).get()).single;
      final items = await shopping(second).listItems(secondList.id);
      expect(items.single.quantity, 200);
      expect(items.single.unit, 'g');
      expect(await second.select(second.supplyAllocations).get(), hasLength(1));

      await shopping(second).reconcilePlan('plan');
      expect((await uploader(second).run()).stoppedBy, isNull);
      expect(await second.select(second.syncOutbox).get(), isEmpty);
      expect(backend.server.rows('shopping_items').single['quantity'], 200);
      expect(backend.server.rows('supply_allocations'), hasLength(1));
      expect(backend.server.rows('shopping_contributions'), hasLength(1));
      await downloader(first).run();
      final firstList = (await first.select(first.shoppingLists).get()).single;
      expect(
        (await shopping(first).listItems(firstList.id)).single.quantity,
        200,
      );
      expect(await first.select(first.supplyAllocations).get(), hasLength(1));
    },
  );
}
