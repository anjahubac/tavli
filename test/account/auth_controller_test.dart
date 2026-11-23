import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/account_api.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/account/auth_gateway.dart';
import 'package:tavli/account/session_store.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/features/recipes/recipe_providers.dart';
import 'package:tavli/providers.dart';
import 'package:tavli/sync/synced_writer.dart';

import '../helpers/fake_backend.dart';
import '../helpers/fake_photo_store.dart';
import '../helpers/fake_secret_storage.dart';

void main() {
  late AppDatabase db;
  late FakeBackend backend;
  late MapSecretStorage secrets;
  late ProviderContainer c;
  var now = DateTime(2026, 10, 30, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    backend = FakeBackend();
    secrets = MapSecretStorage();
    now = DateTime(2026, 10, 30, 12);
    c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sessionStoreProvider.overrideWithValue(SessionStore(secrets)),
        authGatewayProvider.overrideWithValue(backend.auth),
        accountApiProvider.overrideWithValue(backend.accounts),
        authClockProvider.overrideWithValue(() => now),
        syncRemoteProvider.overrideWithValue(backend.sync),
        photoRemoteProvider.overrideWithValue(backend.photos),
        recipePhotoStoreProvider.overrideWithValue(FakePhotoStore()),
      ],
    );
    // Nalog za "Prijava" postoji na serveru (bez imena).
    backend.server.userFor('ana@mail.com');
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  AuthState state() => c.read(authControllerProvider);
  AuthController ctrl() => c.read(authControllerProvider.notifier);

  Future<void> cacheAccount(AuthSession s, {String? name}) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          userId: s.userId,
          email: s.email,
          displayName: Value(name),
          householdId: backend.server.households[s.userId]!,
          householdName: 'Moje domaćinstvo',
          role: 'owner',
          createdAt: now,
        ),
      );

  test('bez sačuvane sesije: odjavljen', () async {
    expect(state(), isA<Starting>());
    await ctrl().start();
    expect(state(), isA<SignedOut>());
    expect((state() as SignedOut).reason, isNull);
  });

  test('odbijeno čitanje sesije: odjavljen uz bezbedan razlog', () async {
    secrets.deniedReads.add(SessionStore.key);

    await ctrl().start();

    expect(state(), isA<SignedOut>());
    expect((state() as SignedOut).reason, SignOutReason.storageUnavailable);
  });

  test('odbijeno čuvanje obnovljene sesije zatvara pristup nalogu', () async {
    final session = backend.auth.sessionFor('ana@mail.com');
    secrets.values[SessionStore.key] = session.json;
    secrets.deniedWrites.add(SessionStore.key);

    await ctrl().start();

    expect((state() as SignedOut).reason, SignOutReason.storageUnavailable);
    expect(backend.auth.current, isNull);
    expect(secrets.values[SessionStore.key], session.json);
    expect(await db.select(db.accounts).get(), isEmpty);
  });

  test('sačuvana sesija i keširan nalog: prijavljen bez mreže', () async {
    final s = backend.auth.sessionFor('ana@mail.com');
    secrets.values[SessionStore.key] = s.json;
    await cacheAccount(s, name: 'Ana');
    backend.server.offline = true;

    await ctrl().start();
    final st = state();
    expect(st, isA<SignedIn>());
    expect((st as SignedIn).account.displayName, 'Ana');
    expect(c.read(accountScopeProvider)?.userId, s.userId);
    await pumpEventQueue();
    // Obnova bez mreže ne odjavljuje.
    expect(state(), isA<SignedIn>());
    expect(secrets.values[SessionStore.key], s.json);
  });

  for (final coldStart in [true, false]) {
    test(
      '${coldStart ? 'pokretanje' : 'ponovna prijava'} proverava članstvo pre sync-a',
      () async {
        final session = backend.auth.sessionFor('ana@mail.com');
        final source = backend.server.households[session.userId]!;
        backend.server.profiles[session.userId]!['display_name'] = 'Ana';
        await cacheAccount(session, name: 'Ana');
        await db
            .into(db.syncOutbox)
            .insert(
              SyncOutboxCompanion.insert(
                accountId: session.userId,
                entity: 'photo',
                recordId: 'old.jpg',
                op: OutboxOp.photoDelete,
                createdAt: now,
              ),
            );

        final otherDevice = FakeBackend(sharedServer: backend.server);
        final destinationOwner = backend.server.userFor(
          'destination@test.local',
        );
        final destination = backend.server.households[destinationOwner]!;
        otherDevice.accounts.joinTargetHousehold = destination;
        await otherDevice.auth.verifyCode(session.email, FakeServer.code);
        expect(
          (await otherDevice.accounts.confirmHouseholdJoin(
            token: 'code',
            expectedSourceHouseholdId: source,
            recipeChoice: JoinRecipeChoice.leaveRecipes,
            acknowledgeSourceDeletion: true,
            operationId: 'operation',
          )).status,
          'joined',
        );

        final fetchStarted = Completer<void>();
        final finishFetch = Completer<void>();
        backend.accounts.beforeFetch = () {
          fetchStarted.complete();
          return finishFetch.future;
        };
        final syncScopes = <String>[];
        final authSubscription = c.listen(authControllerProvider, (_, next) {
          if (next case SignedIn(:final account)) {
            syncScopes.add(account.householdId);
          }
        });
        addTearDown(authSubscription.close);

        final Future<void> loading;
        if (coldStart) {
          secrets.values[SessionStore.key] = session.json;
          loading = ctrl().start();
        } else {
          await ctrl().start();
          await ctrl().sendCode(session.email);
          loading = ctrl().verify(FakeServer.code);
        }
        await fetchStarted.future;
        expect(c.read(syncEngineProvider), isNull);
        expect(syncScopes, isEmpty);
        expect(
          (await db.select(db.syncOutbox).getSingle()).state,
          OutboxState.pending,
        );
        finishFetch.complete();
        await loading;

        expect(syncScopes, [destination]);
        expect(c.read(accountScopeProvider)?.householdId, destination);
        expect(
          (await db.select(db.syncOutbox).getSingle()).state,
          OutboxState.quarantined,
        );
        expect(backend.server.calls, isEmpty);
      },
    );
  }

  test('offline keš je vidljiv, a prvi sync čeka potvrdu članstva', () async {
    final session = backend.auth.sessionFor('ana@mail.com');
    secrets.values[SessionStore.key] = session.json;
    await cacheAccount(session, name: 'Ana');
    backend.server.offline = true;

    await ctrl().start();
    expect((state() as SignedIn).membershipVerified, isFalse);
    expect(c.read(accountScopeProvider), isNotNull);
    expect(c.read(syncEngineProvider), isNull);

    backend.server.offline = false;
    backend.server.households[session.userId] = 'new-home';
    await ctrl().restoreSession();
    expect((state() as SignedIn).membershipVerified, isTrue);
    expect(c.read(accountScopeProvider)?.householdId, 'new-home');
  });

  test('odbijanje tokom provere članstva pokreće još jednu proveru', () async {
    final session = backend.auth.sessionFor('ana@mail.com');
    secrets.values[SessionStore.key] = session.json;
    backend.server.profiles[session.userId]!['display_name'] = 'Ana';
    await cacheAccount(session, name: 'Ana');
    await ctrl().start();
    await pumpEventQueue();
    final engine = c.read(syncEngineProvider)!;

    var fetches = 0;
    final fetchStarted = Completer<void>();
    final finishFetch = Completer<void>();
    backend.accounts.beforeFetch = () {
      fetches++;
      if (fetches > 1) return Future.value();
      fetchStarted.complete();
      return finishFetch.future;
    };
    final running = ctrl().restoreSession(sync: engine);
    await fetchStarted.future;

    // The running check may have read membership before the removal.
    await ctrl().recheckMembership(engine);
    expect(fetches, 1);
    finishFetch.complete();
    await running;
    expect(fetches, 2);

    // Nothing pending: a later denial checks once.
    await ctrl().recheckMembership(engine);
    expect(fetches, 3);
    engine.stop();
    await pumpEventQueue();
  });

  test('keširan nalog bez imena: korak sa imenom', () async {
    final s = backend.auth.sessionFor('ana@mail.com');
    secrets.values[SessionStore.key] = s.json;
    await cacheAccount(s);
    await ctrl().start();
    expect(state(), isA<NeedsName>());
    expect(c.read(accountScopeProvider), isNull);
  });

  test('slanje koda: CodeSent sa sređenom adresom, ništa se ne čuva', () async {
    await ctrl().start();
    await ctrl().sendCode(' Ana@Mail.com ');
    final st = state() as CodeSent;
    expect(st.email, 'ana@mail.com');
    expect(st.sentAt, now);
    expect(secrets.values, isEmpty);
    expect(backend.auth.sentCodes, ['ana@mail.com']);
  });

  test('ispravan kod: čuva sesiju, nov nalog traži ime', () async {
    await ctrl().start();
    await ctrl().sendCode('ana@mail.com');
    await ctrl().verify(FakeServer.code);
    final st = state() as NeedsName;
    expect(st.account.email, 'ana@mail.com');
    expect(st.account.householdName, 'Moje domaćinstvo');
    expect(st.account.roleLabel, 'Vlasnik');
    expect(secrets.values[SessionStore.key], isNotNull);
    expect(await db.select(db.accounts).get(), hasLength(1));
  });

  test('odbijeno čuvanje sesije ne završava prijavu ni keširanje', () async {
    await ctrl().start();
    await ctrl().sendCode('ana@mail.com');
    secrets.deniedWrites.add(SessionStore.key);

    await expectLater(
      ctrl().verify(FakeServer.code),
      throwsA(isA<SecureStorageUnavailable>()),
    );

    expect(state(), isA<CodeSent>());
    expect(backend.auth.current, isNull);
    expect(secrets.values, isEmpty);
    expect(await db.select(db.accounts).get(), isEmpty);
  });

  test('postojeći nalog sa imenom: odmah prijavljen', () async {
    final uid = backend.server.userFor('ana@mail.com');
    backend.server.profiles[uid]!['display_name'] = 'Ana Petrović';
    await ctrl().start();
    await ctrl().sendCode('ana@mail.com');
    await ctrl().verify('123 456');
    expect(state(), isA<SignedIn>());
  });

  test('promena e-pošte vraća na prvi korak', () async {
    await ctrl().start();
    await ctrl().sendCode('ana@mail.com');
    ctrl().changeEmail();
    expect(state(), isA<SignedOut>());
  });

  test('greške ostavljaju stanje i prenose razlog', () async {
    await ctrl().start();
    backend.auth.failNext = const RateLimited();
    await expectLater(
      ctrl().sendCode('ana@mail.com'),
      throwsA(isA<RateLimited>()),
    );
    expect(state(), isA<SignedOut>());

    await ctrl().sendCode('ana@mail.com');
    await expectLater(ctrl().verify('000000'), throwsA(isA<WrongCode>()));
    expect(state(), isA<CodeSent>());
    expect(secrets.values, isEmpty);

    backend.server.offline = true;
    await expectLater(ctrl().verify(FakeServer.code), throwsA(isA<Offline>()));
    expect(state(), isA<CodeSent>());
  });

  group('registracija i link iz mejla', () {
    test('signUp: ConfirmSent, ništa se ne čuva', () async {
      await ctrl().start();
      await ctrl().signUp(' Nova@Mail.com ');
      final st = state() as ConfirmSent;
      expect(st.email, 'nova@mail.com');
      expect(st.sentAt, now);
      expect(secrets.values, isEmpty);
      expect(backend.auth.sentConfirmations, ['nova@mail.com']);
    });

    test(
      'signUp za postojeći nalog: AlreadyRegistered, stanje ostaje',
      () async {
        await ctrl().start();
        await expectLater(
          ctrl().signUp('ana@mail.com'),
          throwsA(isA<AlreadyRegistered>()),
        );
        expect(state(), isA<SignedOut>());
      },
    );

    test(
      'sendCode za nepoznatu adresu: NoAccount, nalog se ne pravi',
      () async {
        await ctrl().start();
        await expectLater(
          ctrl().sendCode('nova@mail.com'),
          throwsA(isA<NoAccount>()),
        );
        expect(state(), isA<SignedOut>());
        expect(backend.server.users, isNot(contains('nova@mail.com')));
      },
    );

    test('kod iz mejla za potvrdu prijavljuje (ConfirmSent)', () async {
      await ctrl().start();
      await ctrl().signUp('nova@mail.com');
      await ctrl().verify(FakeServer.code);
      expect(state(), isA<NeedsName>());
      expect(secrets.values[SessionStore.key], isNotNull);
    });

    test(
      '"Pošalji mi kod" i "Pošalji mejl ponovo" ostaju na ConfirmSent',
      () async {
        await ctrl().start();
        await ctrl().signUp('nova@mail.com');
        now = now.add(const Duration(seconds: 31));
        await ctrl().sendCodeInstead();
        expect((state() as ConfirmSent).sentAt, now);
        expect(backend.auth.sentCodes, ['nova@mail.com']);
        await ctrl().resendConfirmation();
        expect(backend.auth.sentConfirmations, [
          'nova@mail.com',
          'nova@mail.com',
        ]);
        expect(state(), isA<ConfirmSent>());
      },
    );

    test('link iz mejla prijavljuje i posle ponovnog pokretanja', () async {
      await ctrl().start();
      expect(state(), isA<SignedOut>());
      // Aplikacija je zatvorena posle registracije; link je otvori.
      await ctrl().openLink(backend.auth.linkFor('nova@mail.com'));
      expect(state(), isA<NeedsName>());
      expect(secrets.values[SessionStore.key], isNotNull);
    });

    test('istekao link: greška u stanju, ništa se ne čuva', () async {
      await ctrl().start();
      await ctrl().signUp('nova@mail.com');
      await ctrl().openLink(Uri.parse('tavli://auth-callback?code=star'));
      final st = state() as ConfirmSent;
      expect(st.linkError, isA<LinkExpired>());
      expect(secrets.values, isEmpty);
    });

    test('link dok je neko prijavljen se zanemaruje', () async {
      final s = backend.auth.sessionFor('ana@mail.com');
      secrets.values[SessionStore.key] = s.json;
      await cacheAccount(s, name: 'Ana');
      await ctrl().start();
      final link = backend.auth.linkFor('nova@mail.com');
      await ctrl().openLink(link);
      expect((state() as SignedIn).account.email, 'ana@mail.com');
    });

    test('server bez potvrde adrese: signUp odmah prijavljuje', () async {
      backend.auth.autoconfirm = true;
      await ctrl().start();
      await ctrl().signUp('nova@mail.com');
      expect(state(), isA<NeedsName>());
    });
  });

  group('ime samo jednom', () {
    test('nov uređaj: ime sa servera, bez koraka sa imenom', () async {
      final uid = backend.server.users['ana@mail.com']!;
      backend.server.profiles[uid]!['display_name'] = 'Ana';
      await ctrl().start();
      await ctrl().sendCode('ana@mail.com');
      await ctrl().verify(FakeServer.code);
      expect((state() as SignedIn).account.displayName, 'Ana');
    });

    test('keš bez imena, a server ga ima: prijavljen bez koraka', () async {
      final s = backend.auth.sessionFor('ana@mail.com');
      backend.server.profiles[s.userId]!['display_name'] = 'Ana';
      secrets.values[SessionStore.key] = s.json;
      await cacheAccount(s);
      await ctrl().start();
      expect((state() as SignedIn).account.displayName, 'Ana');
    });

    test('keš bez imena i bez mreže: korak sa imenom', () async {
      final s = backend.auth.sessionFor('ana@mail.com');
      secrets.values[SessionStore.key] = s.json;
      await cacheAccount(s);
      backend.server.offline = true;
      await ctrl().start();
      expect(state(), isA<NeedsName>());
    });
  });
}
