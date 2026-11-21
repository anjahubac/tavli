import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/household_invite_code.dart';

void main() {
  test('ručni unos, QR i link koriste isti kod', () {
    final invite = HouseholdInviteCode.parse('abcd 2345-efgh-6789')!;
    expect(invite.displayValue, 'ABCD-2345-EFGH-6789');
    expect(invite.qrPayload, 'ABCD2345EFGH6789');
    final url = invite.shareUrl(Uri.parse('https://example.test'));
    expect(url.path, '/functions/v1/household-invite');
    expect(url.hasQuery, isFalse);
    expect(url.fragment, invite.value);
    final appLink = Uri.parse('tavli://household/join#${url.fragment}');
    expect(HouseholdInviteCode.fromAppLink(appLink)?.value, invite.value);
  });

  test('druga ruta i nevažeći kod se odbijaju', () {
    expect(HouseholdInviteCode.parse('ABCI-2345-EFGH-6789'), isNull);
    expect(HouseholdInviteCode.parse('ABCD'), isNull);
    expect(
      HouseholdInviteCode.fromAppLink(
        Uri.parse('tavli://auth-callback#ABCD2345EFGH6789'),
      ),
      isNull,
    );
  });
}
