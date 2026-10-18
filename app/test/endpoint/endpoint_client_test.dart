import 'dart:async';
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
      return http.Response(jsonEncode(_messageEnvelope), 200);
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

  test('a refused connection is unreachable', () async {
    final client = _clientFor(
      MockClient(
        (request) async => throw http.ClientException('Connection refused'),
      ),
    );

    final outcome = await client.fetchDocument(
      '/v1/skeleton/message',
      kind: 'skeleton-message',
    );

    expect(outcome, isA<Unreachable>());
  });

  test('no answer within the timeout is unreachable', () async {
    final client = _clientFor(
      MockClient((request) => Completer<http.Response>().future),
    );

    final outcome = await client.fetchDocument(
      '/v1/skeleton/message',
      kind: 'skeleton-message',
    );

    expect(outcome, isA<Unreachable>());
  });

  test('a non-2xx answer is not understood', () async {
    final client = _clientFor(
      MockClient(
        (request) async => http.Response(jsonEncode(_messageEnvelope), 404),
      ),
    );

    final outcome = await client.fetchDocument(
      '/v1/skeleton/message',
      kind: 'skeleton-message',
    );

    expect(outcome, isA<NotUnderstood>());
  });

  test('a body that is not an envelope is not understood', () async {
    final client = _clientFor(
      MockClient(
        (request) async => http.Response('this is not an envelope', 200),
      ),
    );

    final outcome = await client.fetchDocument(
      '/v1/skeleton/message',
      kind: 'skeleton-message',
    );

    expect(outcome, isA<NotUnderstood>());
  });
}

EndpointClient _clientFor(http.Client server) => EndpointClient(
  baseUrl: Uri.parse('http://endpoint.test'),
  timeout: const Duration(milliseconds: 100),
  httpClient: server,
);

const _messageEnvelope = {
  'kind': 'skeleton-message',
  'schemaVersion': 1,
  'dataVersion': '2026-10-18',
  'data': {'message': 'hello'},
};
