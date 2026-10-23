import 'dart:async';
import 'dart:convert';

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

class EndpointClient {
  EndpointClient({
    required this.baseUrl,
    required this.timeout,
    required this.httpClient,
  });

  final Uri baseUrl;
  final Duration timeout;
  final http_package.Client httpClient;

  Future<EndpointOutcome> fetchDocument(
    String path, {
    required String kind,
  }) async {
    final elapsed = Stopwatch()..start();
    recordRun('fetch start $path');
    final outcome = await _fetch(path, kind: kind);
    recordRun(
      'fetch outcome $path ${_named(outcome)} in ${elapsed.elapsedMilliseconds} ms',
    );
    return outcome;
  }

  Future<EndpointOutcome> _fetch(String path, {required String kind}) async {
    try {
      final response = await httpClient
          .get(baseUrl.resolve(path))
          .timeout(timeout);
      return _understand(response, kind: kind);
    } on http_package.ClientException catch (failure) {
      return Unreachable('connection failed: ${failure.message}');
    } on TimeoutException {
      return Unreachable('timeout after ${timeout.inMilliseconds} ms');
    }
  }

  static String _named(EndpointOutcome outcome) => switch (outcome) {
    Reached() => 'reached',
    Unreachable(:final cause) => 'unreachable ($cause)',
    NotUnderstood() => 'not understood',
  };

  EndpointOutcome _understand(
    http_package.Response response, {
    required String kind,
  }) {
    if (response.statusCode ~/ 100 != 2) return const NotUnderstood();
    try {
      return Reached(openEnvelope(jsonDecode(response.body), kind: kind));
    } on FormatException {
      return const NotUnderstood();
    }
  }
}
