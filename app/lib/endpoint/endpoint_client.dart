import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:http/http.dart' as http_package;

import 'contract_envelope.dart';
import 'run_record.dart';

sealed class EndpointOutcome {
  const EndpointOutcome();
}

class Reached extends EndpointOutcome {
  const Reached(this.data);

  final Map<String, Object?> data;
}

class Unreachable extends EndpointOutcome {
  const Unreachable(this.cause);

  /// What the transport reported, for the fetch log.
  final String cause;
}

class NotUnderstood extends EndpointOutcome {
  const NotUnderstood();
}

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

  Future<EndpointOutcome> fetchDocument(
    String path, {
    required String kind,
  }) async {
    recordRun('fetch start $path');
    final fetch = _Fetch(baseUrl.resolve(path), kind, timeout, newHttpClient);
    final (outcome, elapsedMs) = await Isolate.run(fetch.run);
    recordRun('fetch outcome $path ${_named(outcome)} in $elapsedMs ms');
    return outcome;
  }

  static String _named(EndpointOutcome outcome) => switch (outcome) {
    Reached() => 'reached',
    Unreachable(:final cause) => 'unreachable ($cause)',
    NotUnderstood() => 'not understood',
  };
}

/// One fetch, as sent to the fetching isolate: what to get, and how to
/// classify the answer (D8).
class _Fetch {
  const _Fetch(this.url, this.kind, this.timeout, this.newHttpClient);

  final Uri url;
  final String kind;
  final Duration timeout;
  final http_package.Client Function() newHttpClient;

  /// The outcome, and how long the fetch took in this isolate.
  Future<(EndpointOutcome, int)> run() async {
    final elapsed = Stopwatch()..start();
    final httpClient = newHttpClient();
    try {
      return (await _outcome(httpClient), elapsed.elapsedMilliseconds);
    } finally {
      httpClient.close();
    }
  }

  Future<EndpointOutcome> _outcome(http_package.Client httpClient) async {
    try {
      final response = await httpClient.get(url).timeout(timeout);
      return _understand(response);
    } on http_package.ClientException catch (failure) {
      return Unreachable('connection failed: ${failure.message}');
    } on TimeoutException {
      return Unreachable('timeout after ${timeout.inMilliseconds} ms');
    }
  }

  EndpointOutcome _understand(http_package.Response response) {
    if (response.statusCode ~/ 100 != 2) return const NotUnderstood();
    try {
      return Reached(openEnvelope(jsonDecode(response.body), kind: kind));
    } on FormatException {
      return const NotUnderstood();
    }
  }
}
