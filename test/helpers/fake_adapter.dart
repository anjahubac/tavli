import 'package:dio/dio.dart';

/// Vraća zadate HTTP odgovore redom i pamti poslate zahteve.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.responses);

  final List<(int, String, Map<String, List<String>>)> responses;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body, headers) = responses.removeAt(0);
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
