// Mogućnosti komponenti dodate za seobu ekrana Nalog i podešavanja.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

TargetPlatform _target(TavliPlatform p) => switch (p) {
  TavliPlatform.android => TargetPlatform.android,
  TavliPlatform.ios => TargetPlatform.iOS,
  TavliPlatform.macos => TargetPlatform.macOS,
  TavliPlatform.windows => TargetPlatform.windows,
};

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  TavliPlatform platform = TavliPlatform.android,
  Size size = const Size(400, 800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTavliTheme(
        TavliMotif.bosiljak,
        Brightness.light,
      ).copyWith(platform: _target(platform)),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _iconButton(String label) => find.byWidgetPredicate(
  (w) => w is TavliIconButton && w.semanticLabel == label,
);

void main() {
  group('TavliBackAppBar', () {
    testWidgets('Android: strelica nazad i naslov levo', (tester) async {
      var back = 0;
      await pump(
        tester,
        TavliBackAppBar(title: 'Izgled', onBack: () => back++),
      );
      expect(find.text('Izgled'), findsOneWidget);
      expect(find.text('Nazad'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Izgled')).dx,
        lessThan(tester.getCenter(find.byType(TavliBackAppBar)).dx),
      );
      await tester.tap(_iconButton('Nazad'));
      expect(back, 1);
    });

    testWidgets('iOS: naziv prethodnog ekrana levo, naslov u sredini', (
      tester,
    ) async {
      var back = 0;
      await pump(
        tester,
        TavliBackAppBar(
          title: 'Izgled',
          backLabel: 'Profil',
          onBack: () => back++,
        ),
        platform: TavliPlatform.ios,
      );
      final bar = tester.getCenter(find.byType(TavliBackAppBar)).dx;
      expect(tester.getCenter(find.text('Izgled')).dx, closeTo(bar, 1));
      expect(find.bySemanticsLabel('Nazad na Profil'), findsOneWidget);
      await tester.tap(find.text('Profil'));
      expect(back, 1);
    });

    testWidgets('320 px, tekst 2×: bez prelivanja', (tester) async {
      await pump(
        tester,
        TavliBackAppBar(
          title: 'AI ključevi',
          backLabel: 'Profil',
          onBack: () {},
        ),
        platform: TavliPlatform.ios,
        size: const Size(320, 400),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('TavliPageHeader: povratak iznad naslova', (tester) async {
    var back = 0;
    await pump(
      tester,
      TavliPageHeader(
        title: 'Izgled',
        backLabel: 'Profil',
        onBack: () => back++,
      ),
      platform: TavliPlatform.macos,
      size: const Size(1000, 400),
    );
    expect(
      tester.getBottomLeft(find.text('Profil')).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text('Izgled')).dy),
    );
    await tester.tap(find.text('Profil'));
    expect(back, 1);
  });

  group('TavliListRow', () {
    testWidgets('dugmad desno ostaju posebna za čitač ekrana', (tester) async {
      var checked = 0;
      var removed = 0;
      await pump(
        tester,
        TavliListGroup(
          children: [
            TavliListRow(
              title: '••••1234',
              subtitle: 'Dodat 1.11.2026',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TavliButton.text(
                    label: 'Proveri',
                    onPressed: () => checked++,
                  ),
                  TavliIconButton(
                    icon: Icons.delete_outline_rounded,
                    semanticLabel: 'Obriši ključ',
                    onPressed: () => removed++,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      await tester.tap(find.text('Proveri'));
      await tester.tap(_iconButton('Obriši ključ'));
      expect((checked, removed), (1, 1));
      expect(find.bySemanticsLabel('Obriši ključ'), findsOneWidget);
    });

    testWidgets('za brisanje: naziv i ikonica u boji greške', (tester) async {
      await pump(
        tester,
        const TavliListGroup(
          children: [
            TavliListRow(
              title: 'Obriši nalog',
              leading: Icon(Icons.delete_forever_outlined),
              destructive: true,
            ),
          ],
        ),
      );
      final error = Theme.of(tester.element(find.text('Obriši nalog')))
          .colorScheme
          .error;
      expect(
        tester.widget<Text>(find.text('Obriši nalog')).style?.color,
        error,
      );
      final icon = IconTheme.of(
        tester.element(find.byIcon(Icons.delete_forever_outlined)),
      );
      expect(icon.color, error);
    });
  });

  testWidgets('TavliTextField: dugme na kraju polja', (tester) async {
    var shown = 0;
    await pump(
      tester,
      TavliTextField(
        label: 'API ključ',
        obscureText: true,
        trailing: TavliIconButton(
          icon: Icons.visibility_outlined,
          semanticLabel: 'Prikaži',
          onPressed: () => shown++,
        ),
      ),
    );
    await tester.tap(_iconButton('Prikaži'));
    expect(shown, 1);
  });

  group('TavliDialogAction', () {
    testWidgets('isključeno dugme ne zatvara dijalog', (tester) async {
      await pump(
        tester,
        const TavliDialog<String>(
          title: 'Izmeni ime',
          actions: [TavliDialogAction('Sačuvaj', 'x', enabled: false)],
        ),
      );
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Sačuvaj'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('computed: vrednost se uzima tek na dodir', (tester) async {
      var current = 'staro';
      String? result;
      await pump(
        tester,
        Builder(
          builder: (context) => TavliButton.primary(
            label: 'Otvori',
            onPressed: () async {
              result = await showTavliDialog<String>(
                context,
                title: 'Ime',
                actions: [
                  TavliDialogAction.computed(
                    'Sačuvaj',
                    () => current,
                    isDefault: true,
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Otvori'));
      await tester.pumpAndSettle();
      current = 'novo';
      await tester.tap(find.text('Sačuvaj'));
      await tester.pumpAndSettle();
      expect(result, 'novo');
    });

    testWidgets('dugmad koja ne staju u red idu jedno ispod drugog', (
      tester,
    ) async {
      await pump(
        tester,
        const TavliDialog<bool>(
          title: 'Obrisati nalog?',
          actions: [
            TavliDialogAction('Odustani', false),
            TavliDialogAction('Obriši nalog', true, isDestructive: true),
          ],
        ),
        size: const Size(320, 600),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('Obriši nalog')).dy,
        greaterThan(tester.getBottomLeft(find.text('Odustani')).dy),
      );
    });
  });

  testWidgets('segmentno dugme se slaže uspravno kad ne staje u red', (
    tester,
  ) async {
    await pump(
      tester,
      TavliChoice<int>.segmented(
        options: const [
          TavliOption(0, 'Svetla'),
          TavliOption(1, 'Tamna'),
          TavliOption(2, 'Sistem'),
        ],
        selected: 0,
        onChanged: (_) {},
      ),
      size: const Size(320, 600),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('Tamna')).dy,
      greaterThan(tester.getBottomLeft(find.text('Svetla')).dy),
    );
  });

  testWidgets('segmentno dugme ostaje u redu kad staje', (tester) async {
    await pump(
      tester,
      TavliChoice<int>.segmented(
        options: const [
          TavliOption(0, 'Svetla'),
          TavliOption(1, 'Tamna'),
          TavliOption(2, 'Sistem'),
        ],
        selected: 0,
        onChanged: (_) {},
      ),
    );
    expect(
      tester.getCenter(find.text('Tamna')).dy,
      tester.getCenter(find.text('Svetla')).dy,
    );
  });

  testWidgets('isLargeText i veliki avatar', (tester) async {
    late bool normal;
    late bool large;
    await pump(
      tester,
      Builder(
        builder: (context) {
          normal = isLargeText(context);
          return const TavliAvatar(initials: 'AH', size: TavliAvatar.large);
        },
      ),
    );
    expect(normal, isFalse);
    expect(tester.getSize(find.byType(TavliAvatar)), const Size.square(56));
    await pump(
      tester,
      Builder(
        builder: (context) {
          large = isLargeText(context);
          return const SizedBox();
        },
      ),
      textScale: 1.5,
    );
    expect(large, isTrue);
  });
}
