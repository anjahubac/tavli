import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/data/cookbook_repository.dart';
import 'package:tavli/domain/cookbook.dart';
import 'package:tavli/features/cookbooks/book_picker.dart';
import 'package:tavli/features/cookbooks/cookbook_providers.dart';

import '../../helpers/fake_cookbooks.dart';
import '../../helpers/test_app.dart';

void main() {
  late FakeCookbookRepository repo;
  late FakeBookPicker picker;

  Future<TestApp> open(
    WidgetTester tester, {
    List<Cookbook> books = const [],
    Size size = phone,
  }) async {
    repo = FakeCookbookRepository(books: books);
    picker = FakeBookPicker();
    return pumpTavli(
      tester,
      location: '/recipes/cookbooks',
      size: size,
      overrides: [
        cookbookRepositoryProvider.overrideWithValue(repo),
        bookPickerProvider.overrideWithValue(picker),
      ],
    );
  }

  testTavli('bez knjiga: prazno stanje sa dugmetom za dodavanje', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Još nema kuvarskih knjiga'), findsOneWidget);
    expect(button('Dodaj knjigu'), findsOneWidget);
  });

  testTavli('lista pokazuje stanje svake knjige', (tester) async {
    await open(
      tester,
      books: const [
        readyBook,
        Cookbook(
          id: 'p',
          title: 'Torte',
          filename: 'torte.epub',
          status: CookbookStatus.processing,
          pages: 100,
          nextPage: 41,
        ),
        Cookbook(
          id: 'f',
          title: 'Skenirana',
          filename: 'sken.pdf',
          status: CookbookStatus.failed,
          errorCode: 'no_text',
        ),
      ],
    );
    expect(find.text('Velika kuvarica'), findsOneWidget);
    expect(find.text('Spremno, 120 stranica'), findsOneWidget);
    expect(find.text('Obrada: 40 od 100 stranica'), findsOneWidget);
    expect(
      find.text(
        'Knjiga nema tekst (možda je skenirana). Podržani su PDF i EPUB sa tekstom.',
      ),
      findsOneWidget,
    );
  });

  testTavli('dodavanje: izabrana knjiga se otprema i pojavljuje u listi', (
    tester,
  ) async {
    await open(tester);
    picker.next = PickedBook(name: 'sarma.pdf', bytes: Uint8List(2048));
    await tapButton(tester, 'Dodaj knjigu');

    expect(repo.uploads, [(filename: 'sarma.pdf', bytes: 2048)]);
    expect(find.text('sarma'), findsOneWidget);
    expect(find.text('Knjiga je spremna.'), findsOneWidget);
  });

  testTavli('odustajanje od izbora ne otprema ništa', (tester) async {
    await open(tester);
    picker.next = null;
    await tapButton(tester, 'Dodaj knjigu');
    expect(picker.calls, 1);
    expect(repo.uploads, isEmpty);
  });

  testTavli('greške otpremanja imaju svoju poruku i ne dodaju knjigu', (
    tester,
  ) async {
    await open(tester);
    final cases = <CookbookFailure, String>{
      const CookbookLimitReached(): 'Domaćinstvo već ima najviše 20 knjiga. Obriši neku pa pokušaj ponovo.',
      const CookbookRejected('no_text'): 'Knjiga nema tekst (možda je skenirana). Podržani su PDF i EPUB sa tekstom.',
      const CookbookRejected('too_large'):
          'Knjiga je prevelika (najviše 15 MB i 500 stranica).',
      const CookbookRejected('too_many_pages'):
          'Knjiga je prevelika (najviše 15 MB i 500 stranica).',
      const CookbookOffline():
          'Nema veze sa internetom. Knjige i pitanja rade samo uz mrežu.',
      const CookbookQuotaExceeded(Duration(minutes: 2)):
          'Limit je trenutno potrošen. Pokušaj malo kasnije.',
      const CookbookServerError():
          'Nešto nije u redu sa serverom. Pokušaj ponovo.',
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      picker.next = PickedBook(name: 'a.pdf', bytes: Uint8List(10));
      repo.failure = key;
      await tapButton(tester, 'Dodaj knjigu');
      expect(find.text(value), findsOneWidget, reason: key.toString());
    }
    expect(repo.books, isEmpty);
  });

  testTavli('brisanje traži potvrdu, pa uklanja knjigu', (tester) async {
    await open(tester, books: const [readyBook]);
    await tester.tap(iconButton('Obriši knjigu Velika kuvarica'));
    await tester.pumpAndSettle();
    expect(find.text('Obrisati knjigu?'), findsOneWidget);

    await tapButton(tester, 'Odustani');
    expect(repo.deletes, isEmpty);
    expect(find.text('Velika kuvarica'), findsOneWidget);

    await tester.tap(iconButton('Obriši knjigu Velika kuvarica'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Obriši');
    expect(repo.deletes, ['b-ready']);
    expect(find.text('Velika kuvarica'), findsNothing);
  });

  testTavli('pitanje je moguće samo kad ima spremna knjiga', (tester) async {
    await open(
      tester,
      books: const [
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
    expect(
      tester.widget<ButtonStyleButton>(button('Postavi pitanje')).enabled,
      isFalse,
    );
  });

  testTavli('postavi pitanje otvara ekran za pitanja', (tester) async {
    await open(tester, books: const [readyBook]);
    await tapButton(tester, 'Postavi pitanje');
    expect(find.text('Pitanje o knjigama'), findsOneWidget);
  });

  testTavli('bez prijave ili mreže: objašnjenje umesto liste', (tester) async {
    await pumpTavli(
      tester,
      location: '/recipes/cookbooks',
      overrides: [cookbookRepositoryProvider.overrideWithValue(null)],
    );
    expect(
      find.text('Kuvarske knjige traže prijavu i vezu sa internetom.'),
      findsOneWidget,
    );
    expect(find.text('Dodaj knjigu'), findsNothing);
  });

  testTavli('široki ekran i veliki tekst: sve staje', (tester) async {
    await open(tester, books: const [readyBook], size: wide);
    expect(tester.takeException(), isNull);
    expect(find.text('Velika kuvarica'), findsOneWidget);
  });

  testTavli('iz menija „Dodaj recept“ se stiže do kuvarskih knjiga', (
    tester,
  ) async {
    repo = FakeCookbookRepository(books: const [readyBook]);
    await pumpTavli(
      tester,
      overrides: [cookbookRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.tap(find.text('Dodaj recept'));
    await tester.pumpAndSettle();
    expect(find.text('Iz kuvarske knjige'), findsOneWidget);

    await tester.tap(find.text('Iz kuvarske knjige'));
    await tester.pumpAndSettle();
    expect(find.text('Kuvarske knjige'), findsOneWidget);
    expect(find.text('Velika kuvarica'), findsOneWidget);
  });

  testTavli('prekinuta obrada: „Nastavi obradu“ je završava', (tester) async {
    await open(
      tester,
      books: const [
        Cookbook(
          id: 'p',
          title: 'Torte',
          filename: 't.pdf',
          status: CookbookStatus.processing,
          pages: 100,
          nextPage: 41,
        ),
      ],
    );
    expect(find.text('Obrada: 40 od 100 stranica'), findsOneWidget);
    await tapButton(tester, 'Nastavi obradu');

    expect(repo.resumes, ['p']);
    expect(find.text('Spremno, 100 stranica'), findsOneWidget);
    expect(find.text('Nastavi obradu'), findsNothing);
    expect(find.text('Knjiga je spremna.'), findsOneWidget);
  });

  testTavli('spremna i neuspela knjiga nemaju „Nastavi obradu“', (
    tester,
  ) async {
    await open(
      tester,
      books: const [
        readyBook,
        Cookbook(
          id: 'f',
          title: 'Skenirana',
          filename: 's.pdf',
          status: CookbookStatus.failed,
          errorCode: 'no_text',
        ),
      ],
    );
    expect(find.text('Nastavi obradu'), findsNothing);
  });

  testTavli('greška pri nastavku obrade se prikazuje', (tester) async {
    await open(
      tester,
      books: const [
        Cookbook(
          id: 'p',
          title: 'Torte',
          filename: 't.pdf',
          status: CookbookStatus.uploaded,
        ),
      ],
    );
    repo.failure = const CookbookOffline();
    await tapButton(tester, 'Nastavi obradu');
    expect(
      find.text(
        'Nema veze sa internetom. Knjige i pitanja rade samo uz mrežu.',
      ),
      findsOneWidget,
    );
  });
}
