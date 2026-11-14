import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/features/account/sync_banner.dart';
import 'package:tavli/providers.dart';
import 'package:tavli/sync/sync_engine.dart';

import '../../helpers/test_app.dart';

void main() {
  for (final size in [phone, wide]) {
    testTavli(
      'traka "Preuzimam…" dok traje preuzimanje, recepti su upotrebljivi '
      '(${size.width.toInt()} px)',
      (tester) async {
        final phase = StreamController<SyncPhase?>();
        addTearDown(phase.close);
        await pumpTavli(
          tester,
          size: size,
          recipes: [sampleRecipe('r1', 'Sarma')],
          overrides: [syncPhaseProvider.overrideWith((ref) => phase.stream)],
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);

        phase.add(SyncPhase.downloading);
        await tester.pump();
        await tester.pump();
        expect(find.text('Preuzimam tvoje podatke…'), findsOneWidget);
        expect(find.text('Sarma'), findsWidgets);
        await tester.tap(find.text('Sarma').first);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Preuzimam tvoje podatke…'), findsOneWidget);

        phase.add(SyncPhase.moving);
        await tester.pump();
        await tester.pump();
        expect(find.text('Čuvam tvoje podatke…'), findsOneWidget);

        phase.add(null);
        await tester.pump();
        await tester.pump();
        expect(find.byType(SyncBanner), findsOneWidget);
        expect(find.text('Čuvam tvoje podatke…'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testTavli('nov uređaj: nalog se preuzima posle prijave', (tester) async {
    final app = await pumpTavli(tester, signedIn: false);
    // Na serveru već postoji recept naloga (sa drugog uređaja).
    final hid = app.scope.householdId;
    app.backend.server.profiles[app.session.userId]!['display_name'] = 'Ana';
    app.backend.server.upsert('recipes', [
      {
        'id': 'r9',
        'household_id': hid,
        'title': 'Pasulj sa drugog uređaja',
        'servings': 4,
        'source': 'manual',
        'ingredients': <Object>[],
        'steps': <Object>[],
        'image_path': 'p.jpg',
        'created_at': '2026-10-30T10:00:00.000Z',
      },
    ], 'id');
    await tester.enterText(
      find.widgetWithText(TextField, 'E-pošta'),
      testEmail,
    );
    await tester.pump();
    await tester.tap(button('Pošalji kod'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Kod iz poruke'),
      '123456',
    );
    await tester.pumpAndSettle();
    expect(find.text('Pasulj sa drugog uređaja'), findsOneWidget);
  });
}
