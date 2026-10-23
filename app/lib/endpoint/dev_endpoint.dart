import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'endpoint_client.dart';
import 'traced_connection.dart';

/// The endpoint the build was pointed at; values come from tools/dev.env via --dart-define.
EndpointClient devEndpointClient() => EndpointClient(
  baseUrl: Uri.parse(const String.fromEnvironment('ENDPOINT_URL')),
  timeout: const Duration(
    milliseconds: int.fromEnvironment('ENDPOINT_TIMEOUT_MS'),
  ),
  httpClient: kDebugMode ? IOClient(tracedHttpClient()) : http.Client(),
);
