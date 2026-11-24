import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_gateway.dart';

void main() {
  group('webAuthCallbackFrom', () {
    test('kod iz mejla postaje tavli://auth-callback povratak', () {
      final uri = webAuthCallbackFrom(
        Uri.parse('https://app.example/?code=abc'),
      );
      expect(uri, isNotNull);
      expect(isAuthCallback(uri!), isTrue);
      expect(uri.queryParameters['code'], 'abc');
    });

    test('greška iz mejla se prenosi', () {
      final uri = webAuthCallbackFrom(
        Uri.parse('https://app.example/?error_code=otp_expired'),
      );
      expect(uri?.queryParameters['error_code'], 'otp_expired');
    });

    test('obična stranica nije povratak', () {
      expect(webAuthCallbackFrom(Uri.parse('https://app.example/')), isNull);
      expect(
        webAuthCallbackFrom(Uri.parse('https://app.example/?a=1')),
        isNull,
      );
    });
  });
}
