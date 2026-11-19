import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

/// Ekran sa jednim dugmetom „Otvori“ koje poziva [open].
Future<void> pumpOpener(
  WidgetTester tester,
  void Function(BuildContext context) open, {
  TargetPlatform platform = TargetPlatform.android,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTavliTheme(
        TavliMotif.bosiljak,
        Brightness.light,
      ).copyWith(platform: platform),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('Otvori'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> openIt(WidgetTester tester) async {
  await tester.tap(find.text('Otvori'));
  await tester.pumpAndSettle();
}

void main() {
  group('showTavliConfirm', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
      testWidgets('${platform.name}: Material dijalog radijusa 24', (
        tester,
      ) async {
        bool? result;
        await pumpOpener(tester, (context) async {
          result = await showTavliConfirm(
            context,
            title: 'Ukloniti recept?',
            message: 'Sarma će biti uklonjena.',
            confirmLabel: 'Ukloni',
            destructive: true,
          );
        }, platform: platform);
        await openIt(tester);
        expect(find.byType(CupertinoAlertDialog), findsNothing);
        final dialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(
          (dialog.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(24),
        );
        // Dugmad u istom redu su iste visine.
        expect(
          tester.getSize(find.widgetWithText(TextButton, 'Otkaži')).height,
          tester.getSize(find.widgetWithText(TextButton, 'Ukloni')).height,
        );
        await tester.tap(find.text('Ukloni'));
        await tester.pumpAndSettle();
        expect(result, isTrue);
      });
    }

    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      testWidgets('${platform.name}: sistemski dijalog', (tester) async {
        bool? result;
        await pumpOpener(tester, (context) async {
          result = await showTavliConfirm(
            context,
            title: 'Ukloniti recept?',
            confirmLabel: 'Ukloni',
            destructive: true,
          );
        }, platform: platform);
        await openIt(tester);
        expect(find.byType(CupertinoAlertDialog), findsOneWidget);
        final remove = tester.widget<CupertinoDialogAction>(
          find.widgetWithText(CupertinoDialogAction, 'Ukloni'),
        );
        expect(remove.isDestructiveAction, isTrue);
        await tester.tap(find.text('Otkaži'));
        await tester.pumpAndSettle();
        expect(result, isFalse);
      });
    }

    testWidgets('zatvaranje van dijaloga znači „ne“', (tester) async {
      bool? result;
      await pumpOpener(tester, (context) async {
        result = await showTavliConfirm(
          context,
          title: 'Ukloniti?',
          confirmLabel: 'Ukloni',
        );
      });
      await openIt(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(result, isFalse);
    });
  });

  testWidgets('dijalog sa poljem vraća vrednost dugmeta', (tester) async {
    String? result;
    await pumpOpener(tester, (context) async {
      result = await showTavliDialog<String>(
        context,
        title: 'Novi spisak',
        content: const TavliTextField(label: 'Naziv'),
        actions: const [
          TavliDialogAction('Otkaži', 'no'),
          TavliDialogAction('Napravi', 'ok', isDefault: true),
        ],
      );
    });
    await openIt(tester);
    expect(find.text('Naziv'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Napravi'), findsOneWidget);
    await tester.tap(find.text('Napravi'));
    await tester.pumpAndSettle();
    expect(result, 'ok');
  });

  testWidgets('donji list: ručica, naslov, radijus 24 i vrednost', (
    tester,
  ) async {
    int? result;
    await pumpOpener(tester, (context) async {
      result = await showTavliSheet<int>(
        context,
        title: 'Dodaj namirnicu',
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).pop(7),
          child: const Text('Dodaj'),
        ),
      );
    });
    await openIt(tester);
    expect(find.text('Dodaj namirnicu'), findsOneWidget);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(TavliSheet),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(
      (material.shape! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.vertical(top: Radius.circular(24)),
    );
    await tester.tap(find.text('Dodaj'));
    await tester.pumpAndSettle();
    expect(result, 7);
  });

  group('showTavliMessage', () {
    testWidgets('akcija se poziva i poruka nestaje', (tester) async {
      var undone = 0;
      await pumpOpener(
        tester,
        (context) => showTavliMessage(
          context,
          'Jaja su uklonjena.',
          actionLabel: 'Vrati',
          onAction: () => undone++,
        ),
      );
      await openIt(tester);
      expect(find.text('Jaja su uklonjena.'), findsOneWidget);
      await tester.tap(find.text('Vrati'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text('Jaja su uklonjena.'), findsNothing);
    });

    testWidgets('nestaje posle 5 s i kada ima akciju', (tester) async {
      await pumpOpener(
        tester,
        (context) => showTavliMessage(
          context,
          'Jaja su uklonjena.',
          actionLabel: 'Vrati',
          onAction: () {},
        ),
      );
      await openIt(tester);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Jaja su uklonjena.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Jaja su uklonjena.'), findsNothing);
    });

    testWidgets('nova poruka zamenjuje staru', (tester) async {
      var n = 0;
      await pumpOpener(
        tester,
        (context) => showTavliMessage(context, 'Poruka ${++n}'),
      );
      await openIt(tester);
      await openIt(tester);
      expect(find.text('Poruka 1'), findsNothing);
      expect(find.text('Poruka 2'), findsOneWidget);
    });
  });

  group('showTavliActionMenu', () {
    List<TavliMenuAction> actions(List<String> log) => [
      TavliMenuAction('Izmeni', onSelected: () => log.add('izmeni')),
      TavliMenuAction(
        'Ukloni',
        isDestructive: true,
        onSelected: () => log.add('ukloni'),
      ),
    ];

    testWidgets('Android: donji list sa akcijama', (tester) async {
      final log = <String>[];
      await pumpOpener(
        tester,
        (context) =>
            showTavliActionMenu(context, title: 'Sarma', actions: actions(log)),
      );
      await openIt(tester);
      expect(find.byType(TavliSheet), findsOneWidget);
      final remove = tester.widget<Text>(find.text('Ukloni'));
      expect(
        remove.style?.color,
        Theme.of(tester.element(find.text('Ukloni'))).colorScheme.error,
      );
      await tester.tap(find.text('Ukloni'));
      await tester.pumpAndSettle();
      expect(log, ['ukloni']);
      expect(find.byType(TavliSheet), findsNothing);
    });

    testWidgets('iOS: sistemski akcioni list sa „Otkaži“', (tester) async {
      final log = <String>[];
      await pumpOpener(
        tester,
        (context) => showTavliActionMenu(context, actions: actions(log)),
        platform: TargetPlatform.iOS,
      );
      await openIt(tester);
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text('Otkaži'));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
    });

    testWidgets('računar: meni na mestu klika', (tester) async {
      final log = <String>[];
      await pumpOpener(
        tester,
        (context) => showTavliActionMenu(
          context,
          actions: actions(log),
          position: const Offset(300, 200),
        ),
        platform: TargetPlatform.macOS,
        size: const Size(1000, 700),
      );
      await openIt(tester);
      expect(find.byType(CupertinoActionSheet), findsNothing);
      final topLeft = tester.getTopLeft(find.text('Izmeni'));
      expect(topLeft.dx, greaterThan(290));
      expect(topLeft.dy, greaterThan(190));
      await tester.tap(find.text('Izmeni'));
      await tester.pumpAndSettle();
      expect(log, ['izmeni']);
    });

    testWidgets('dugme „Još opcija“ otvara meni', (tester) async {
      final log = <String>[];
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTavliTheme(TavliMotif.bosiljak, Brightness.light),
          home: Scaffold(
            body: Center(child: TavliMenuButton(actions: actions(log))),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Još opcija'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Izmeni'));
      await tester.pumpAndSettle();
      expect(log, ['izmeni']);
    });
  });

  testWidgets('desni klik na red tabele daje mesto klika', (tester) async {
    Offset? at;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTavliTheme(TavliMotif.bosiljak, Brightness.light),
        home: Scaffold(
          body: TavliDataTable(
            columns: const [TavliColumn('Namirnica')],
            rows: [
              TavliTableRow(const ['Brašno'], onSecondaryTap: (p) => at = p),
            ],
          ),
        ),
      ),
    );
    final center = tester.getCenter(find.text('Brašno'));
    await tester.tapAt(center, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(at, center);
  });
}
