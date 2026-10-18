import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skimapper/endpoint/endpoint_client.dart';

void main() {
  test('a served envelope is reached, with its data', () async {
    final server = MockClient((request) async {
      if (request.url.toString() !=
          'http://endpoint.test/v1/skeleton/message') {
        return http.Response('not found', 404);
      }
      return http.Response(
        jsonEncode({
          'kind': 'skeleton-message',
          'schemaVersion': 1,
          'dataVersion': '2026-10-18',
          'data': {'message': 'hello'},
        }),
        200,
      );
    });
    final client = EndpointClient(
      baseUrl: Uri.parse('http://endpoint.test'),
      timeout: const Duration(seconds: 1),
      httpClient: server,
    );

    final outcome = await client.fetchDocument(
      '/v1/skeleton/message',
      kind: 'skeleton-message',
    );

    expect(
      outcome,
      isA<Reached>().having((reached) => reached.data, 'data', {
        'message': 'hello',
      }),
    );
  });
}
