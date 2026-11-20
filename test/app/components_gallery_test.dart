import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/app/router.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testTavli('Profil > Komponente otvara galeriju i vraća se nazad', (
    tester,
  ) async {
    await pumpTavli(tester, location: '/profile');
    await tester.tap(find.text('Komponente'));
    await tester.pumpAndSettle();
    expect(find.byType(TavliGallery), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(TavliGallery), findsNothing);
    expect(find.text('Profil'), findsOneWidget);
  });

  testTavli('galerija se u debug verziji otvara i bez prijave', (tester) async {
    await pumpTavli(tester, location: '/plan', signedIn: false);
    expect(find.text('Prijava'), findsOneWidget);

    await tester.tap(find.text('Komponente (samo za razvoj)'));
    await tester.pumpAndSettle();
    expect(find.byType(TavliGallery), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Prijava'), findsOneWidget);
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
