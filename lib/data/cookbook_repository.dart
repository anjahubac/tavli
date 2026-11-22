import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../domain/cookbook.dart';

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

  /// Briše knjigu i njene delove; posle toga se ne pretražuje.
  Future<void> delete(String id);

  Future<CookbookAnswer> ask(String question, {String? bookId});
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
    final path = '$_householdId/$safe';
    await _client.storage
        .from('cookbooks')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: safe.toLowerCase().endsWith('.epub')
                ? 'application/epub+zip'
                : 'application/pdf',
            upsert: true,
          ),
        );
    final title = safe.replaceFirst(
      RegExp(r'\.(pdf|epub)$', caseSensitive: false),
      '',
    );
    Map<String, dynamic> body = {'storagePath': path, 'title': title};
    for (var step = 0; step < maxSteps; step++) {
      final res = await _client.functions.invoke(
        'cookbook-process',
        body: body,
      );
      final data = res.data as Map<String, dynamic>;
      final id = data['id'] as String;
      final status = data['status'] as String;
      final book = Cookbook(
        id: id,
        title: title,
        filename: safe,
        status: switch (status) {
          'ready' => CookbookStatus.ready,
          'failed' => CookbookStatus.failed,
          _ => CookbookStatus.processing,
        },
        pages: data['pages'] as int?,
        nextPage: data['nextPage'] as int? ?? 1,
        errorCode: data['errorCode'] as String?,
      );
      onProgress?.call(book);
      if (book.status == CookbookStatus.ready) return book;
      if (book.status == CookbookStatus.failed) {
        throw CookbookRejected(book.errorCode ?? 'failed');
      }
      if (status == 'busy') await Future<void>.delayed(stepDelay);
      body = {'bookId': id};
    }
    throw const CookbookServerError();
  });

  @override
  Future<void> delete(String id) => _guard(() async {
    final rows = await _client.rest
        .from('cookbooks')
        .select('storage_path')
        .eq('id', id)
        .limit(1);
    await _client.rest.from('cookbooks').delete().eq('id', id);
    if (rows.isNotEmpty) {
      await _client.storage.from('cookbooks').remove([
        rows.first['storage_path'] as String,
      ]);
    }
  });

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
      if (e.status == 400 || e.status == 404 || e.status == 403) {
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
