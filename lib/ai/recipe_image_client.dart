import 'dart:async';

import 'package:supabase/supabase.dart';

/// Ishod zahteva za AI sliku recepta (zadatak `recipe_image` u ai-gateway).
sealed class RecipeImageResult {
  const RecipeImageResult();
}

/// Slika je u `recipe-photos/{household}/{file}`.
final class RecipeImageReady extends RecipeImageResult {
  const RecipeImageReady(this.file);

  /// Samo ime fajla (`ai_<uuid>.jpg`), proverenog oblika.
  final String file;
}

/// Limit (korisnik, projekat ili Cloudflare): pokušaj ponovo posle [retryAfter].
final class RecipeImageDeferred extends RecipeImageResult {
  const RecipeImageDeferred(this.retryAfter);

  final Duration retryAfter;
}

/// Slike su isključene na serveru (prekidač ili bez podešavanja).
final class RecipeImageDisabled extends RecipeImageResult {
  const RecipeImageDisabled();
}

/// Sesija ne važi ili korisnik nema domaćinstvo: ne pokušava se do
/// sledećeg pokretanja.
final class RecipeImageUnauthorized extends RecipeImageResult {
  const RecipeImageUnauthorized();
}

/// Nema mreže ili odgovora gateway-a: ne računa se kao neuspeo pokušaj.
final class RecipeImageOffline extends RecipeImageResult {
  const RecipeImageOffline();
}

/// Greška provajdera (tipizirana): pokušaj ponovo kasnije.
final class RecipeImageFailed extends RecipeImageResult {
  const RecipeImageFailed();
}

/// Zahtev je odbijen kao neispravan: isti zahtev neće uspeti.
final class RecipeImageRejected extends RecipeImageResult {
  const RecipeImageRejected();
}

typedef RecipeImageInvoke = Future<FunctionResponse> Function(
  Map<String, Object?> body,
);

/// Traži AI sliku od ai-gateway funkcije. Šalje samo id recepta i opis;
/// model, stil i ključevi su na serveru.
class RecipeImageClient {
  RecipeImageClient(
    this._invoke, {
    this._refresh,
    this.timeout = const Duration(seconds: 75),
  });

  factory RecipeImageClient.supabase(
    SupabaseClient client, {
    required Future<bool> Function() refresh,
  }) => RecipeImageClient(refresh: refresh, (body) {
    final token = client.auth.currentSession?.accessToken;
    if (token == null) {
      throw const FunctionException(status: 401);
    }
    return client.functions.invoke(
      'ai-gateway',
      body: body,
      headers: {'Authorization': 'Bearer $token'},
    );
  });

  final RecipeImageInvoke _invoke;
  final Duration timeout;

  /// Obnavlja sesiju posle 401; zahtev se tada ponavlja tačno jednom.
  final Future<bool> Function()? _refresh;

  static final _file = RegExp(r'^ai_[0-9a-f-]{36}\.jpg$');

  Future<RecipeImageResult> generate(
    String recipeId,
    String description,
  ) async {
    final result = await _request(recipeId, description);
    final refresh = _refresh;
    if (result is! RecipeImageUnauthorized || refresh == null) return result;
    if (!await refresh()) return result;
    return _request(recipeId, description);
  }

  Future<RecipeImageResult> _request(
    String recipeId,
    String description,
  ) async {
    try {
      final response = await _invoke({
        'task': 'recipe_image',
        'recipeId': recipeId,
        'description': description,
      }).timeout(timeout);
      return _map(response.status, response.data);
    } on FunctionException catch (e) {
      return _map(e.status, e.details);
    } on Exception {
      return const RecipeImageOffline();
    }
  }

  static RecipeImageResult _map(int status, Object? data) {
    final body = data is Map<String, Object?>
        ? data
        : const <String, Object?>{};
    if (status == 200) {
      final file = body['file'];
      return file is String && _file.hasMatch(file)
          ? RecipeImageReady(file)
          : const RecipeImageFailed();
    }
    final seconds = body['retryAfterSeconds'];
    final retry = seconds is int && seconds >= 0 && seconds <= 86400
        ? Duration(seconds: seconds)
        : const Duration(minutes: 15);
    return switch ((status, body['error'])) {
      (429, 'quota_exceeded' || 'rate_limited') => RecipeImageDeferred(retry),
      (503, 'disabled') => const RecipeImageDisabled(),
      (401 || 403, _) => const RecipeImageUnauthorized(),
      (400 || 413, _) => const RecipeImageRejected(),
      _ => const RecipeImageFailed(),
    };
  }
}
