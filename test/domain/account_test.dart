import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/account.dart';

void main() {
  group('initials', () {
    test('prvo slovo prvog i poslednjeg imena', () {
      expect(initials('Ana Petrović'), 'AP');
      expect(initials('Ana Marija Petrović'), 'AP');
    });
    test('jedna reč daje jedno slovo', () => expect(initials('Ana'), 'A'));
    test('čuva dijakritike i pravi velika slova', () {
      expect(initials('đorđe šćepanović'), 'ĐŠ');
      expect(initials('Đorđe Šćepanović'), 'ĐŠ');
    });
    test('višak razmaka se ignoriše', () {
      expect(initials('  ana   petrović  '), 'AP');
      expect(initials('   '), '');
    });
  });

  group('normalizeEmail', () {
    test('skida razmake i pravi mala slova', () {
      expect(normalizeEmail(' Ana@Mail.com '), 'ana@mail.com');
    });
    test('proverava oblik adrese', () {
      expect(isValidEmail('ana@mail.com'), isTrue);
      expect(isValidEmail(' Ana@Mail.com '), isTrue);
      expect(isValidEmail('ana@mail'), isFalse);
      expect(isValidEmail('ana mail.com'), isFalse);
      expect(isValidEmail('@mail.com'), isFalse);
      expect(isValidEmail('ana@@mail.com'), isFalse);
      expect(isValidEmail(''), isFalse);
    });
  });

  group('normalizeCode', () {
    test('uzima samo cifre, najviše 6', () {
      expect(normalizeCode('123 456'), '123456');
      expect(normalizeCode('12a-3'), '123');
      expect(normalizeCode('1234567'), '123456');
      expect(normalizeCode(''), '');
    });
  });

  group('normalizeName', () {
    test('skida razmake; prazno je null', () {
      expect(normalizeName('  Ana  '), 'Ana');
      expect(normalizeName('   '), isNull);
      expect(normalizeName(''), isNull);
    });
    test('najviše 40 znakova', () {
      expect(normalizeName('a' * 40), 'a' * 40);
      expect(normalizeName('a' * 41), isNull);
    });
  });

  test('Account.copyWith menja ime', () {
    const a = Account(
      userId: 'u1',
      email: 'ana@mail.com',
      householdId: 'h1',
      householdName: 'Moje domaćinstvo',
      role: 'owner',
    );
    expect(a.displayName, isNull);
    expect(a.copyWith(displayName: 'Ana').displayName, 'Ana');
    expect(a.roleLabel, 'Vlasnik');
  });
}
