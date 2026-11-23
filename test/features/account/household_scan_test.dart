import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/account.dart';
import 'package:tavli/features/account/household_scan_screen.dart';

void main() {
  test('QR: sam kod, aplikacijski link i HTTPS link sa fragmentom', () {
    expect(householdCodeFromScan('0123456789AB')?.value, '0123456789AB');
    expect(householdCodeFromScan(' 0123-4567-89ab ')?.value, '0123456789AB');
    expect(
      householdCodeFromScan('tavli://household/join#0123456789AB')?.value,
      '0123456789AB',
    );
    expect(
      householdCodeFromScan(
        'https://x.supabase.co/functions/v1/household-invite#0123456789AB',
      )?.value,
      '0123456789AB',
    );
  });

  test('QR: tuđ link, običan tekst i HTTP se zanemaruju', () {
    expect(householdCodeFromScan('https://example.com/'), isNull);
    expect(householdCodeFromScan('http://x.test/#0123456789AB'), isNull);
    expect(householdCodeFromScan('tavli://auth-callback#0123456789AB'), isNull);
    expect(householdCodeFromScan('zdravo'), isNull);
    expect(householdCodeFromScan(''), isNull);
  });

  test('broj članova u množini', () {
    expect(memberCountLabel(1), '1 član');
    expect(memberCountLabel(2), '2 člana');
    expect(memberCountLabel(4), '4 člana');
    expect(memberCountLabel(5), '5 članova');
    expect(memberCountLabel(11), '11 članova');
    expect(memberCountLabel(12), '12 članova');
    expect(memberCountLabel(21), '21 član');
    expect(memberCountLabel(22), '22 člana');
  });

  test('naziv domaćinstva: razmaci, prazno i najviše 40 znakova', () {
    expect(normalizeHouseholdName('  Kuća  '), 'Kuća');
    expect(normalizeHouseholdName('   '), isNull);
    expect(normalizeHouseholdName('a' * 40), 'a' * 40);
    expect(normalizeHouseholdName('a' * 41), isNull);
    expect(normalizeHouseholdName('č' * 40), 'č' * 40);
  });
}
