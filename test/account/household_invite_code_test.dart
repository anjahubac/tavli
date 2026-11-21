import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/household_invite_code.dart';

void main() {
  test('ručni unos, QR i link koriste isti kod', () {
    final invite = HouseholdInviteCode.parse('abcd 2345-efgh')!;
    expect(invite.displayValue, 'ABCD-2345-EFGH');
    expect(invite.qrPayload, 'ABCD2345EFGH');
    final url = invite.shareUrl(Uri.parse('https://example.test'));
    expect(url.path, '/functions/v1/household-invite');
    expect(url.hasQuery, isFalse);
    expect(url.fragment, invite.value);
    final appLink = Uri.parse('tavli://household/join#${url.fragment}');
    expect(HouseholdInviteCode.fromAppLink(appLink)?.value, invite.value);
  });

  test('ranije podeljeni formati i dalje važe', () {
    expect(
      HouseholdInviteCode.parse('abcd-2345-efgh-6789')?.value,
      'ABCD2345EFGH6789',
    );
    final legacy = 'a' * 64;
    expect(HouseholdInviteCode.parse(legacy)?.value, legacy);
  });

  test('druga ruta i nevažeći kod se odbijaju', () {
    expect(HouseholdInviteCode.parse('ABCI-2345-EFGH'), isNull);
    expect(HouseholdInviteCode.parse('ABCD'), isNull);
    expect(
      HouseholdInviteCode.fromAppLink(
        Uri.parse('tavli://auth-callback#ABCD2345EFGH'),
      ),
      isNull,
    );
  });
}
