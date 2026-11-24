import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/app/router.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testTavli('Profil i prijava nemaju ulaz u galerije', (tester) async {
    await pumpTavli(tester, location: '/profile');
    expect(find.text('Komponente'), findsNothing);
    expect(find.text('Animacije'), findsNothing);
  });

  testTavli('prijava nema dugme za galeriju', (tester) async {
    await pumpTavli(tester, location: '/plan', signedIn: false);
    expect(find.text('Prijava'), findsOneWidget);
    expect(find.text('Komponente (samo za razvoj)'), findsNothing);
  });

  testTavli('galerija se u debug verziji otvara direktnom adresom', (
    tester,
  ) async {
    await pumpTavli(tester, location: componentsPath, signedIn: false);
    expect(find.byType(TavliGallery), findsOneWidget);
  });

  test('bez alata za razvoj galerija traži prijavu i nema rutu', () {
    final uri = Uri.parse(componentsPath);
    expect(authRedirect(const SignedOut(), uri), isNull);
    expect(
      authRedirect(const SignedOut(), uri, debugTools: false),
      '/sign-in?from=%2Fcomponents',
    );

    final release = createRouter(debugTools: false);
    addTearDown(release.dispose);
    expect(
      release.configuration.findMatch(uri).matches,
      isEmpty,
      reason: 'u verziji za objavu ruta /components ne postoji',
    );
    final debug = createRouter(); // testovi rade u debug režimu
    addTearDown(debug.dispose);
    expect(debug.configuration.findMatch(uri).matches, isNotEmpty);
  });
}
