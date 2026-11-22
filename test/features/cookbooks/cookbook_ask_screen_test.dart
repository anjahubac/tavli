import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/data/cookbook_repository.dart';
import 'package:tavli/domain/cookbook.dart';
import 'package:tavli/features/cookbooks/cookbook_providers.dart';

import '../../helpers/fake_cookbooks.dart';
import '../../helpers/test_app.dart';

const _answer = CookbookAnswer(
  content: 'Pasulj se kuva sat i po na tihoj vatri.',
  sources: [
    CookbookSource(bookId: 'b-ready', title: 'Velika kuvarica', page: 10),
    CookbookSource(bookId: 'b-ready', title: 'Velika kuvarica', page: 31),
  ],
);

void main() {
  late FakeCookbookRepository repo;

  Future<TestApp> open(
    WidgetTester tester, {
    List<Cookbook> books = const [readyBook],
    Size size = phone,
  }) async {
    repo = FakeCookbookRepository(books: books);
    return pumpTavli(
      tester,
      location: '/recipes/cookbooks/ask',
      size: size,
      overrides: [cookbookRepositoryProvider.overrideWithValue(repo)],
    );
  }

  Future<void> ask(WidgetTester tester, String question) async {
    await tester.enterText(textField('Pitanje'), question);
    await tester.pump();
    await tapButton(tester, 'Pitaj');
  }

  testTavli('odgovor se prikazuje sa knjigom i stranicom', (tester) async {
    await open(tester);
    repo.answer = _answer;
    await ask(tester, 'Koliko se kuva pasulj?');

    expect(repo.questions, [
      (question: 'Koliko se kuva pasulj?', bookId: null),
    ]);
    expect(
      find.text('Pasulj se kuva sat i po na tihoj vatri.'),
      findsOneWidget,
    );
    expect(find.text('Velika kuvarica, str. 10'), findsOneWidget);
    expect(find.text('Velika kuvarica, str. 31'), findsOneWidget);
  });

  testTavli('prazno pitanje ne može da se pošalje', (tester) async {
    await open(tester);
    expect(tester.widget<ButtonStyleButton>(button('Pitaj')).enabled, isFalse);
    await tester.enterText(textField('Pitanje'), '   ');
    await tester.pump();
    expect(tester.widget<ButtonStyleButton>(button('Pitaj')).enabled, isFalse);
  });

  testTavli('nema odgovora: jasna poruka, bez izvora i bez čuvanja', (
    tester,
  ) async {
    await open(tester);
    await ask(tester, 'Nešto što nije u knjigama');

    expect(find.text('Nema odgovora u tvojim knjigama.'), findsOneWidget);
    expect(find.textContaining('str.'), findsNothing);
    expect(find.text('Sačuvaj kao recept'), findsNothing);
  });

  testTavli('greške imaju svoje poruke i pitanje ostaje u polju', (
    tester,
  ) async {
    await open(tester);
    final cases = <CookbookFailure, String>{
      const CookbookQuotaExceeded(Duration(minutes: 1)):
          'Limit je trenutno potrošen. Pokušaj malo kasnije.',
      const CookbookOffline():
          'Nema veze sa internetom. Knjige i pitanja rade samo uz mrežu.',
      const CookbookServerError():
          'Nešto nije u redu sa serverom. Pokušaj ponovo.',
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      repo.failure = key;
      await ask(tester, 'Pitanje');
      expect(find.text(value), findsOneWidget, reason: key.toString());
    }
    expect(find.text('Pitanje'), findsWidgets);
    expect(
      tester.widget<TextField>(textField('Pitanje')).controller!.text,
      'Pitanje',
    );
  });

  testTavli('izbor knjige se šalje; ponuđene su samo spremne knjige', (
    tester,
  ) async {
    await open(
      tester,
      books: const [
        readyBook,
        Cookbook(
          id: 'p',
          title: 'Torte',
          filename: 't.pdf',
          status: CookbookStatus.processing,
          pages: 10,
          nextPage: 2,
        ),
      ],
    );
    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    expect(find.text('Torte'), findsNothing);
    await tester.tap(find.text('Velika kuvarica').last);
    await tester.pumpAndSettle();

    await ask(tester, 'Kako se kuva pasulj?');
    expect(repo.questions.single.bookId, 'b-ready');
  });

  testTavli('čuvanje kao recept otvara formu sa odgovorom i izvorom', (
    tester,
  ) async {
    await open(tester);
    repo.answer = _answer;
    await ask(tester, 'Koliko se kuva pasulj?');
    await tapButton(tester, 'Sačuvaj kao recept');

    expect(find.text('Novi recept'), findsWidgets);
    final steps = tester
        .widget<TextField>(textField('Koraci pripreme (jedan po redu)'))
        .controller!
        .text;
    expect(steps, contains('Pasulj se kuva sat i po na tihoj vatri.'));
    expect(steps, contains('Izvor: Velika kuvarica, str. 10, str. 31'));
  });

  testTavli('veliki odgovor na širokom ekranu staje bez greške', (
    tester,
  ) async {
    await open(tester, size: wide);
    repo.answer = CookbookAnswer(
      content: List.filled(80, 'Pasulj se kuva dugo.').join(' '),
      sources: const [
        CookbookSource(bookId: 'b-ready', title: 'Velika kuvarica', page: 10),
      ],
    );
    await ask(tester, 'Pitanje');
    expect(tester.takeException(), isNull);
  });
}
