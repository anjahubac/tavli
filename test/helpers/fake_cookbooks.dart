import 'dart:typed_data';

import 'package:tavli/data/cookbook_repository.dart';
import 'package:tavli/domain/cookbook.dart';
import 'package:tavli/features/cookbooks/book_picker.dart';

/// Lažna knjižara u memoriji: beleži pozive i vraća zadate odgovore.
class FakeCookbookRepository implements CookbookRepository {
  FakeCookbookRepository({List<Cookbook> books = const []})
    : books = [...books];

  final List<Cookbook> books;
  final uploads = <({String filename, int bytes})>[];
  final deletes = <String>[];
  final questions = <({String question, String? bookId})>[];

  /// Greška koju sledeći poziv baca (jednom).
  CookbookFailure? failure;

  /// Šta upload vraća; podrazumevano spremna knjiga po imenu fajla.
  Cookbook Function(String filename)? uploadResult;

  CookbookAnswer answer = const CookbookAnswer.unknown();

  CookbookFailure? _take() {
    final f = failure;
    failure = null;
    return f;
  }

  @override
  Future<List<Cookbook>> list() async {
    if (_take() case final f?) throw f;
    return [...books];
  }

  @override
  Future<Cookbook> upload({
    required String filename,
    required Uint8List bytes,
    void Function(Cookbook book)? onProgress,
  }) async {
    uploads.add((filename: filename, bytes: bytes.length));
    if (_take() case final f?) throw f;
    final book =
        uploadResult?.call(filename) ??
        Cookbook(
          id: 'new-${books.length}',
          title: filename.replaceAll(RegExp(r'\.(pdf|epub)$'), ''),
          filename: filename,
          status: CookbookStatus.ready,
          pages: 12,
          nextPage: 13,
        );
    onProgress?.call(book);
    books.insert(0, book);
    return book;
  }

  @override
  Future<void> delete(String id) async {
    deletes.add(id);
    if (_take() case final f?) throw f;
    books.removeWhere((b) => b.id == id);
  }

  @override
  Future<CookbookAnswer> ask(String question, {String? bookId}) async {
    questions.add((question: question, bookId: bookId));
    if (_take() case final f?) throw f;
    return answer;
  }
}

class FakeBookPicker implements BookPicker {
  /// Šta sledeći izbor vraća (null = korisnik je odustao).
  PickedBook? next;
  int calls = 0;

  @override
  Future<PickedBook?> pick() async {
    calls++;
    return next;
  }
}

const readyBook = Cookbook(
  id: 'b-ready',
  title: 'Velika kuvarica',
  filename: 'velika.pdf',
  status: CookbookStatus.ready,
  pages: 120,
  nextPage: 121,
);
