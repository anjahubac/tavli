import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../domain/cookbook.dart';
import '../domain/ids.dart';

/// Zašto rad sa knjigama nije uspeo. Poruke za prikaz su u ekranu.
sealed class CookbookFailure implements Exception {
  const CookbookFailure();

  @override
  String toString() => runtimeType.toString();
}

class CookbookOffline extends CookbookFailure {
  const CookbookOffline();
}

class CookbookServerError extends CookbookFailure {
  const CookbookServerError();
}

/// Dnevni, minutni ili zajednički limit je potrošen; [retryAfter] kad se oslobađa.
class CookbookQuotaExceeded extends CookbookFailure {
  const CookbookQuotaExceeded(this.retryAfter);

  final Duration retryAfter;
}

/// Domaćinstvo već ima najviše knjiga.
class CookbookLimitReached extends CookbookFailure {
  const CookbookLimitReached();
}

/// Fajl nije podržan (npr. skeniran PDF bez teksta) ili ga server ne prihvata.
class CookbookRejected extends CookbookFailure {
  const CookbookRejected(this.code);

  /// `no_text`, `corrupt`, `too_many_pages`, `too_large`, `unsupported_type`...
  final String code;
}

/// Knjige domaćinstva i pitanja nad njima. Radi samo uz mrežu: knjige i
/// njihovi delovi žive na serveru i nisu u lokalnoj bazi.
abstract interface class CookbookRepository {
  Future<List<Cookbook>> list();

  /// Otprema fajl i čeka da ga server obradi (u koracima). Baca
  /// [CookbookFailure]. [onProgress] dobija stanje posle svakog koraka.
  Future<Cookbook> upload({
    required String filename,
    required Uint8List bytes,
    void Function(Cookbook book)? onProgress,
  });

  /// Nastavlja obradu knjige koja je ostala nedovršena (prekid, greška
  /// servera). Fajl se ne otprema ponovo.
  Future<Cookbook> resume(
    Cookbook book, {
    void Function(Cookbook book)? onProgress,
  });

  /// Briše knjigu i njene delove; posle toga se ne pretražuje.
  Future<void> delete(String id);

  Future<CookbookAnswer> ask(String question, {String? bookId});
}

/// Storage must succeed before deleting the durable row that holds its path.
/// If removal fails, the row stays available for a later retry.
Future<void> deleteCookbookStorageFirst({
  required Future<String?> Function() findStoragePath,
  required Future<void> Function(String path) removeStorage,
  required Future<void> Function() deleteRow,
}) async {
  final path = await findStoragePath();
  if (path != null) await removeStorage(path);
  await deleteRow();
}

/// Jedan poziv obrade na serveru: telo je `{storagePath, title}` za novu knjigu
/// ili `{bookId}` za nastavak; odgovor je `{id, status, nextPage, pages, errorCode}`.
typedef ProcessStep = Future<Map<String, dynamic>> Function(
  Map<String, Object?> body,
);

/// Zove obradu dok knjiga nije spremna. Server radi u delovima (`partial`) i
/// može da bude zauzet (`busy`). Deo koji napreduje se nastavlja odmah. Kad
/// napretka nema (provajder embeddinga ne odgovara), čeka se [pause] i
/// ponavlja najviše [maxStalls] puta, pa je greška: bez toga bi aplikacija
/// u petlji ponavljala skup poziv koji svaki put iznova čita ceo fajl.
Future<Cookbook> driveProcessing({
  required ProcessStep step,
  required Map<String, Object?> first,
  required String title,
  required String filename,
  required Duration pause,
  Future<void> Function(Duration)? wait,
  int maxSteps = 60,
  int maxStalls = 3,
  void Function(Cookbook book)? onProgress,
}) async {
  final sleep = wait ?? Future<void>.delayed;
  var body = first;
  var lastPage = 0;
  var stalls = 0;
  for (var i = 0; i < maxSteps; i++) {
    final data = await step(body);
    final id = data['id'] as String;
    final status = data['status'] as String;
    final next = data['nextPage'] as int? ?? 1;
    final book = Cookbook(
      id: id,
      title: title,
      filename: filename,
      status: switch (status) {
        'ready' => CookbookStatus.ready,
        'failed' => CookbookStatus.failed,
        _ => CookbookStatus.processing,
      },
      pages: data['pages'] as int?,
      nextPage: next,
      errorCode: data['errorCode'] as String?,
    );
    onProgress?.call(book);
    if (book.status == CookbookStatus.ready) return book;
    if (book.status == CookbookStatus.failed) {
      throw CookbookRejected(book.errorCode ?? 'failed');
    }
    if (status == 'partial' && next > lastPage) {
      stalls = 0;
    } else {
      if (++stalls >= maxStalls) throw const CookbookServerError();
      await sleep(pause);
    }
    lastPage = next > lastPage ? next : lastPage;
    body = {'bookId': id};
  }
  throw const CookbookServerError();
}

class SupabaseCookbookRepository implements CookbookRepository {
  SupabaseCookbookRepository(
    this._client,
    this._householdId, {
    this.stepDelay = const Duration(seconds: 2),
    this.maxSteps = 60,
  });

  final SupabaseClient _client;
  final String _householdId;

  /// Pauza kad je obrada zauzeta (drugi poziv je radi).
  final Duration stepDelay;

  /// Gornja granica poziva obrade za jednu knjigu (500 stranica po pozivu je
  /// daleko ispod ovoga).
  final int maxSteps;

  @override
  Future<List<Cookbook>> list() => _guard(() async {
    final rows = await _client.rest
        .from('cookbooks')
        .select('id, title, filename, status, pages, next_page, error_code')
        .order('created_at', ascending: false);
    return [for (final r in rows) _book(r)];
  });

  @override
  Future<Cookbook> upload({
    required String filename,
    required Uint8List bytes,
    void Function(Cookbook book)? onProgress,
  }) => _guard(() async {
    final safe = _safeName(filename);
    final lower = safe.toLowerCase();
    if (!lower.endsWith('.pdf') && !lower.endsWith('.epub')) {
      throw const CookbookRejected('unsupported_type');
    }
    final extension = lower.endsWith('.epub') ? 'epub' : 'pdf';
    final path = '$_householdId/${newId()}.$extension';
    await _client.storage
        .from('cookbooks')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: safe.toLowerCase().endsWith('.epub')
                ? 'application/epub+zip'
                : 'application/pdf',
          ),
        );
    final title = safe.replaceFirst(
      RegExp(r'\.(pdf|epub)$', caseSensitive: false),
      '',
    );
    return driveProcessing(
      step: _process,
      first: {'storagePath': path, 'filename': safe, 'title': title},
      title: title,
      filename: safe,
      pause: stepDelay,
      maxSteps: maxSteps,
      onProgress: onProgress,
    );
  });

  @override
  Future<Cookbook> resume(
    Cookbook book, {
    void Function(Cookbook book)? onProgress,
  }) => _guard(
    () => driveProcessing(
      step: _process,
      first: {'bookId': book.id},
      title: book.title,
      filename: book.filename,
      pause: stepDelay,
      maxSteps: maxSteps,
      onProgress: onProgress,
    ),
  );

  Future<Map<String, dynamic>> _process(Map<String, Object?> body) async {
    final res = await _client.functions.invoke('cookbook-process', body: body);
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<void> delete(String id) => _guard(
    () => deleteCookbookStorageFirst(
      findStoragePath: () async {
        final rows = await _client.rest
            .from('cookbooks')
            .select('storage_path')
            .eq('id', id)
            .limit(1);
        return rows.isEmpty ? null : rows.first['storage_path'] as String;
      },
      removeStorage: (path) async {
        await _client.storage.from('cookbooks').remove([path]);
      },
      deleteRow: () async {
        await _client.rest.from('cookbooks').delete().eq('id', id);
      },
    ),
  );

  @override
  Future<CookbookAnswer> ask(String question, {String? bookId}) => _guard(
    () async {
      final res = await _client.functions.invoke(
        'cookbook-ask',
        body: {'question': question, 'bookId': ?bookId},
      );
      final data = res.data as Map<String, dynamic>;
      final sources = [
        for (final s
            in (data['sources'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          CookbookSource(
            bookId: s['bookId'] as String,
            title: s['title'] as String,
            page: s['page'] as int,
          ),
      ];
      return data['status'] == 'answered' && sources.isNotEmpty
          ? CookbookAnswer(content: data['content'] as String, sources: sources)
          : const CookbookAnswer.unknown();
    },
  );

  static String _safeName(String filename) {
    final base = filename.split(RegExp(r'[\\/]')).last;
    return base.replaceAll(RegExp(r'[^\w.\- ]', unicode: true), '_');
  }

  static Cookbook _book(Map<String, dynamic> r) => Cookbook(
    id: r['id'] as String,
    title: r['title'] as String,
    filename: r['filename'] as String,
    status: CookbookStatus.values.firstWhere(
      (s) => s.name == r['status'],
      orElse: () => CookbookStatus.failed,
    ),
    pages: r['pages'] as int?,
    nextPage: r['next_page'] as int? ?? 1,
    errorCode: r['error_code'] as String?,
  );

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FunctionException catch (e) {
      final details = e.details;
      final error = details is Map ? details['error'] : null;
      if (e.status == 429) {
        final secs = details is Map ? details['retryAfterSeconds'] : null;
        throw CookbookQuotaExceeded(Duration(seconds: secs is int ? secs : 60));
      }
      if (error == 'limit_reached') throw const CookbookLimitReached();
      if (e.status == 400 ||
          e.status == 404 ||
          e.status == 403 ||
          e.status == 409) {
        throw CookbookRejected(error is String ? error : 'rejected');
      }
      throw const CookbookServerError();
    } on StorageException catch (e) {
      if (e.statusCode == '413') throw const CookbookRejected('too_large');
      throw const CookbookServerError();
    } on PostgrestException {
      throw const CookbookServerError();
    } on SocketException {
      throw const CookbookOffline();
    } on TimeoutException {
      throw const CookbookOffline();
    } on http.ClientException {
      throw const CookbookOffline();
    }
  }
}
