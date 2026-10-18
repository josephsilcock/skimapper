import 'package:http/http.dart' as http;

import 'endpoint_client.dart';

/// The endpoint the build was pointed at; values come from tools/dev.env via --dart-define.
EndpointClient devEndpointClient() => EndpointClient(
  baseUrl: Uri.parse(const String.fromEnvironment('ENDPOINT_URL')),
  timeout: const Duration(
    milliseconds: int.fromEnvironment('ENDPOINT_TIMEOUT_MS'),
  ),
  httpClient: http.Client(),
);
