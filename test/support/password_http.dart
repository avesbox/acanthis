import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Exercises the default HTTP provider without permitting a network request.
class PasswordHttpClient implements HttpClient {
  PasswordHttpClient({required this.statusCode, required this.body});
  final int statusCode;
  final String body;
  final List<Uri> requests = [];
  final Map<String, Object> headers = {};
  bool closed = false;
  bool forced = false;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests.add(url);
    return _Request(this);
  }

  @override
  void close({bool force = false}) {
    closed = true;
    forced = force;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.client);
  final PasswordHttpClient client;
  @override
  HttpHeaders get headers => _Headers(client.headers);
  @override
  Future<HttpClientResponse> close() async =>
      _Response(client.statusCode, client.body);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  _Headers(this.values);
  final Map<String, Object> values;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, String body)
    : _stream = Stream.value(utf8.encode(body));
  @override
  final int statusCode;
  final Stream<List<int>> _stream;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
