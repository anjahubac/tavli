import 'package:dio/dio.dart';

import 'ai_errors.dart';
import 'ai_models.dart';

abstract interface class ChatClient {
  /// Vraća sirov tekst odgovora (očekuje se JSON objekat).
  /// Baca [AIError] podklase.
  Future<String> complete(
    ModelSpec model,
    AIRequest request, {
    required String apiKey,
  });
}

/// Jedan klijent za Gemini, Groq i OpenRouter preko
/// OpenAI-kompatibilnog `/chat/completions` endpointa.
class OpenAICompatibleClient implements ChatClient {
  OpenAICompatibleClient({
    Dio? dio,
    this.transientRetryDelay = const Duration(seconds: 1),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 90),
             ),
           );

  final Dio _dio;
  final Duration transientRetryDelay;

  @override
  Future<String> complete(
    ModelSpec model,
    AIRequest request, {
    required String apiKey,
  }) async {
    try {
      return await _send(model, request, apiKey);
    } on TransientError {
      // Jedan brz ponovni pokušaj na istom modelu, pa odluka ide routeru.
      await Future<void>.delayed(transientRetryDelay);
      return _send(model, request, apiKey);
    }
  }

  Future<List<String>> listModels(AIProvider provider, String apiKey) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '${provider.baseUrl}models',
        options: Options(headers: _headers(provider, apiKey)),
      );
      return [
        for (final m in (res.data?['data'] as List? ?? const []))
          (m as Map)['id'].toString(),
      ];
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<String> _send(
    ModelSpec model,
    AIRequest request,
    String apiKey,
  ) async {
    final Response<Map<String, dynamic>> res;
    try {
      res = await _dio.post<Map<String, dynamic>>(
        '${model.provider.baseUrl}chat/completions',
        data: buildBody(model, request),
        options: Options(headers: _headers(model.provider, apiKey)),
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
    final choices = res.data?['choices'];
    final message = choices is List && choices.isNotEmpty
        ? choices.first['message']
        : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const InvalidOutputError('Prazan odgovor modela');
    }
    return content;
  }

  static Map<String, String> _headers(AIProvider provider, String apiKey) => {
    'Authorization': 'Bearer $apiKey',
    if (provider == AIProvider.openRouter) 'X-Title': 'Tavli',
  };

  static Map<String, dynamic> buildBody(ModelSpec model, AIRequest request) => {
    'model': model.model,
    'temperature': request.temperature,
    'response_format': {'type': 'json_object'},
    'messages': [
      {'role': 'system', 'content': request.system},
      {
        'role': 'user',
        'content': request.images.isEmpty
            ? request.prompt
            : [
                {'type': 'text', 'text': request.prompt},
                for (final img in request.images)
                  {
                    'type': 'image_url',
                    'image_url': {'url': img.toDataUrl()},
                  },
              ],
      },
    ],
  };
}

AIError mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return TransientError(e.message ?? e.type.name);
    default:
      break;
  }
  final status = e.response?.statusCode;
  final body = e.response?.data?.toString() ?? '';
  final short = body.length > 300 ? '${body.substring(0, 300)}…' : body;

  if (status == 429) {
    return RateLimitError(
      'HTTP 429: $short',
      retryAfter: parseRetryAfter(
        e.response?.headers.value('retry-after'),
        body,
      ),
      isDaily: looksLikeDailyLimit(body),
    );
  }
  if (status == 401 || status == 403) return AuthError('HTTP $status: $short');
  // Gemini za nevažeći ključ vraća 400 "API key not valid".
  if (status == 400 && body.toLowerCase().contains('api key')) {
    return AuthError('HTTP 400: $short');
  }
  if (status == 404) return ModelNotFoundError('HTTP 404: $short');
  if (status != null && status >= 500) {
    return TransientError('HTTP $status: $short');
  }
  return BadRequestError('HTTP $status: $short');
}

/// Čita `Retry-After` zaglavlje (sekunde) ili Gemini `"retryDelay": "34s"`.
Duration? parseRetryAfter(String? header, String body) {
  final seconds = double.tryParse(header?.trim() ?? '');
  if (seconds != null) return Duration(milliseconds: (seconds * 1000).ceil());
  final m = RegExp(r'retryDelay"?\s*[:=]\s*"?(\d+(?:\.\d+)?)s')
      .firstMatch(body);
  if (m != null) {
    return Duration(milliseconds: (double.parse(m.group(1)!) * 1000).ceil());
  }
  return null;
}

bool looksLikeDailyLimit(String body) {
  final b = body.toLowerCase();
  return b.contains('perday') ||
      b.contains('per day') ||
      b.contains('per_day') ||
      b.contains('daily');
}
