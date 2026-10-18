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
    final response = await httpClient
        .get(baseUrl.resolve(path))
        .timeout(timeout);
    return Reached(openEnvelope(jsonDecode(response.body), kind: kind));
  }
}
