import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/data/cookbook_repository.dart';
import 'package:tavli/domain/cookbook.dart';

Map<String, dynamic> _r(
  String status, {
  int next = 1,
  int? pages = 10,
  String? error,
}) => {
  'id': 'b1',
  'status': status,
  'nextPage': next,
  'pages': pages,
  'errorCode': error,
};

void main() {
  late List<Map<String, Object?>> bodies;
  late List<Duration> waits;
  late List<Cookbook> progress;

  setUp(() {
    bodies = [];
    waits = [];
    progress = [];
  });

  Future<Cookbook> drive(
    List<Map<String, dynamic>> results, {
    int maxSteps = 60,
    int maxStalls = 3,
  }) {
    var i = 0;
    return driveProcessing(
      step: (body) async {
        bodies.add(body);
        return results[i < results.length ? i++ : results.length - 1];
      },
      first: {'storagePath': 'hh/a.pdf', 'title': 'a'},
      title: 'a',
      filename: 'a.pdf',
      pause: const Duration(seconds: 2),
      wait: (d) async => waits.add(d),
      maxSteps: maxSteps,
      maxStalls: maxStalls,
      onProgress: progress.add,
    );
  }

  test('spremna knjiga odmah: bez čekanja, prvi poziv nosi putanju', () async {
    final book = await drive([_r('ready', next: 11)]);
    expect(book.status, CookbookStatus.ready);
    expect(bodies, [
      {'storagePath': 'hh/a.pdf', 'title': 'a'},
    ]);
    expect(waits, isEmpty);
  });

  test(
    'delovi koji napreduju se nastavljaju bez pauze po id-u knjige',
    () async {
      final book = await drive([
        _r('partial', next: 4),
        _r('partial', next: 8),
        _r('ready', next: 11),
      ]);
      expect(book.status, CookbookStatus.ready);
      expect(bodies[1], {'bookId': 'b1'});
      expect(bodies, hasLength(3));
      expect(waits, isEmpty);
      expect(progress.map((b) => b.nextPage), [4, 8, 11]);
    },
  );

  test('zauzeta obrada: pauza pa nastavak', () async {
    final book = await drive([_r('busy'), _r('ready', next: 11)]);
    expect(book.status, CookbookStatus.ready);
    expect(waits, [const Duration(seconds: 2)]);
  });

  test('prekid bez napretka (provajder ne odgovara): pauza, pa greška posle tri zastoja', () async {
    await expectLater(
      drive([_r('partial', next: 2, error: 'embed_failed')]),
      throwsA(isA<CookbookServerError>()),
    );
    // prvi odgovor je napredak (stranica 2), zatim tri ista; pauza pre dva ponavljanja
    expect(bodies, hasLength(4));
    expect(waits, hasLength(2));
  });

  test(
    'oporavak posle prekida: brojač zastoja se vraća kad ima napretka',
    () async {
      final book = await drive([
        _r('partial', next: 2, error: 'embed_failed'),
        _r('partial', next: 2, error: 'embed_failed'),
        _r('partial', next: 5),
        _r('partial', next: 5, error: 'embed_failed'),
        _r('ready', next: 11),
      ]);
      expect(book.status, CookbookStatus.ready);
    },
  );

  test('neuspela knjiga baca CookbookRejected sa kodom servera', () async {
    await expectLater(
      drive([_r('failed', error: 'no_text')]),
      throwsA(isA<CookbookRejected>().having((e) => e.code, 'code', 'no_text')),
    );
  });

  test('previše koraka je greška servera, ne beskonačna petlja', () async {
    await expectLater(
      drive([
        _r('partial', next: 2),
        _r('partial', next: 3),
        _r('partial', next: 4),
      ], maxSteps: 3),
      throwsA(isA<CookbookServerError>()),
    );
  });
}
