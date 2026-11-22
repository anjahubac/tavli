import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/account/auth_gateway.dart';
import 'package:tavli/account/session_store.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/providers.dart';

import '../helpers/fake_backend.dart';
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
