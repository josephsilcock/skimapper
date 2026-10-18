import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http_package;

import 'contract_envelope.dart';

sealed class EndpointOutcome {
  const EndpointOutcome();
}

class Reached extends EndpointOutcome {
  const Reached(this.data);

  final Map<String, Object?> data;
}

class Unreachable extends EndpointOutcome {
  const Unreachable();
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
    final response = await _get(path);
    return response == null
        ? const Unreachable()
        : _understand(response, kind: kind);
  }

  /// Null when nothing answered: the connection failed or the timeout passed.
  Future<http_package.Response?> _get(String path) async {
    try {
      return await httpClient.get(baseUrl.resolve(path)).timeout(timeout);
    } on http_package.ClientException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

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
