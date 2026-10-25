import 'dart:async';
import 'dart:isolate';

import 'package:http/http.dart' as http_package;

import 'contract_envelope.dart';
import 'run_record.dart';

/// Fetches from the endpoint off the calling isolate, so the app's own start-up
/// work on its UI isolate can't push a prompt answer past the timeout.
class EndpointClient {
  EndpointClient({
    required this.baseUrl,
    required this.timeout,
    required this.newHttpClient,
  });

  final Uri baseUrl;
  final Duration timeout;

  /// Makes the HTTP client inside the fetching isolate; a client can't cross
  /// isolates.
  final http_package.Client Function() newHttpClient;

  Future<DocumentOutcome<T>> fetchDocument<T>(
    String path, {
    required String kind,
    required T Function(Map<String, Object?> data) parse,
  }) async {
    recordRun('fetch start $path');
    final fetch = _Fetch(
      baseUrl.resolve(path),
      kind,
      parse,
      timeout,
      newHttpClient,
    );
    final (outcome, elapsedMs) = await Isolate.run(fetch.run);
    recordRun('fetch outcome $path ${_named(outcome)} in $elapsedMs ms');
    return outcome;
  }

  static String _named(DocumentOutcome<Object?> outcome) => switch (outcome) {
    Understood() => 'understood',
    Incompatible() => 'incompatible',
    Failed(:final cause) => 'failed ($cause)',
  };
}

/// One fetch, as sent to the fetching isolate: what to get, and how to
/// classify the answer (D8).
class _Fetch<T> {
  const _Fetch(
    this.url,
    this.kind,
    this.parse,
    this.timeout,
    this.newHttpClient,
  );

  final Uri url;
  final String kind;
  final T Function(Map<String, Object?> data) parse;
  final Duration timeout;
  final http_package.Client Function() newHttpClient;

  /// The outcome, and how long the fetch took in this isolate.
  Future<(DocumentOutcome<T>, int)> run() async {
    final elapsed = Stopwatch()..start();
    final httpClient = newHttpClient();
    try {
      return (await _outcome(httpClient), elapsed.elapsedMilliseconds);
    } finally {
      httpClient.close();
    }
  }

  Future<DocumentOutcome<T>> _outcome(http_package.Client httpClient) async {
    try {
      final response = await httpClient.get(url).timeout(timeout);
      return _classify(response);
    } on http_package.ClientException catch (failure) {
      return Failed('connection failed: ${failure.message}');
    } on TimeoutException {
      return Failed('timeout after ${timeout.inMilliseconds} ms');
    }
  }

  DocumentOutcome<T> _classify(http_package.Response response) {
    if (response.statusCode ~/ 100 != 2) {
      return Failed('HTTP ${response.statusCode}');
    }
    return openDocument(response.body, kind: kind, parse: parse);
  }
}
