import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/app/animations/intro_overlay.dart';

import '../helpers/test_app.dart';

class _ControlledAuth extends AuthController {
  @override
  AuthState build() => const Starting();

  @override
  Future<void> start() async {}

  void ready() => state = const SignedOut();
}

void main() {
  testTavli('uvod prati stvarno učitavanje i ne zadržava spremnu prijavu', (
    tester,
  ) async {
    final auth = _ControlledAuth();
    await pumpTavli(
      tester,
      intro: true,
      settle: false,
      overrides: [authControllerProvider.overrideWith(() => auth)],
    );
    expect(find.byType(IntroScreen), findsOneWidget);
    auth.ready();
    await tester.pump();
    await tester.pump();
    expect(find.byType(IntroScreen), findsNothing);
    expect(find.text('Prijava'), findsOneWidget);
  });
}
