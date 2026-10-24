import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skimapper/endpoint/contract_envelope.dart';
import 'package:skimapper/endpoint/endpoint_client.dart';

import '../support/block_for.dart';
import '../support/run_record_capture.dart';

void main() {
  test('a served envelope is understood, with its data', () async {
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
      newHttpClient: () => server,
    );

    final outcome = await client.fetchDocument(
      '/v1/skeleton/message',
      kind: 'skeleton-message',
      parse: _message,
    );

    expect(
      outcome,
      isA<Understood<String>>().having(
        (understood) => understood.value,
        'value',
        'hello',
      ),
    );
  });

  test('a refused connection has failed', () async {
    final client = _clientFor(
      MockClient(
        (request) async => throw http.ClientException('Connection refused'),
      ),
    );

    final outcome = await client.fetchDocument(
      '/v1/skeleton/message',
      kind: 'skeleton-message',
      parse: _message,
    );

    expect(outcome, isA<Failed<String>>());
  });

  test('no answer within the timeout has failed', () async {
    final client = _clientFor(
      MockClient((request) => Completer<http.Response>().future),
    );

    final outcome = await client.fetchDocument(
      '/v1/skeleton/message',
      kind: 'skeleton-message',
      parse: _message,
    );

    expect(outcome, isA<Failed<String>>());
  });

  test('a non-2xx answer has failed, naming its status', () async {
    final client = _clientFor(
      MockClient(
        (request) async => http.Response(jsonEncode(_messageEnvelope), 404),
      ),
    );

    final outcome = await client.fetchDocument(
      '/v1/skeleton/message',
      kind: 'skeleton-message',
      parse: _message,
    );

    expect(
      outcome,
      isA<Failed<String>>().having(
        (failed) => failed.cause,
        'cause',
        'HTTP 404',
      ),
    );
  });

  test('a body that is not an envelope has failed', () async {
    final client = _clientFor(
      MockClient(
        (request) async => http.Response('this is not an envelope', 200),
      ),
    );

    final outcome = await client.fetchDocument(
      '/v1/skeleton/message',
      kind: 'skeleton-message',
      parse: _message,
    );

    expect(outcome, isA<Failed<String>>());
  });

  test('an answer that comes in time is classified by it, even if the caller is blocked past the timeout', () async {
    final port = await _serveFromAnotherIsolate('not an envelope');
    final client = EndpointClient(
      baseUrl: Uri.parse('http://127.0.0.1:$port'),
      timeout: const Duration(milliseconds: 500),
      newHttpClient: http.Client.new,
    );

    late final Future<DocumentOutcome<String>> outcome;
    final logged = await runRecordDuring(() async {
      outcome = client.fetchDocument(
        '/v1/skeleton/message',
        kind: 'skeleton-message',
        parse: _message,
      );
      blockFor(const Duration(milliseconds: 1500));
      await outcome;
    });

    expect(await outcome, isA<Failed<String>>());
    final loggedMs = int.parse(
      RegExp(r'in (\d+) ms').firstMatch(logged.last)!.group(1)!,
    );
    expect(
      loggedMs,
      lessThan(500),
      reason: 'the figure times the network, not the block',
    );
  });

  group('fetch log', () {
    test(
      'a fetch logs its start, naming the path, stamped in UTC to the ms',
      () async {
        final logged = await _fetchLogAgainst(
          MockClient((request) async => http.Response('not an envelope', 200)),
        );

        expect(
          logged.firstOrNull,
          matches(appRunRecordLine('fetch start /v1/skeleton/message')),
        );
      },
    );

    test(
      'a fetch logs its outcome after its start, with the elapsed ms',
      () async {
        final logged = await _fetchLogAgainst(
          MockClient((request) async => http.Response('not an envelope', 200)),
        );

        expect(logged, [
          anything,
          matches(
            appRunRecordLine(
              r'fetch outcome /v1/skeleton/message failed \(not an envelope\) in \d+ ms',
            ),
          ),
        ]);
      },
    );

    test(
      'a failed connection is logged as failed, naming the failure',
      () async {
        final logged = await _fetchLogAgainst(
          MockClient(
            (request) async => throw http.ClientException('Connection refused'),
          ),
        );

        expect(
          logged.lastOrNull,
          matches(
            appRunRecordLine(
              r'fetch outcome /v1/skeleton/message failed \(connection failed: Connection refused\) in \d+ ms',
            ),
          ),
        );
      },
    );

    test(
      'no answer within the timeout is logged as failed by timeout',
      () async {
        final logged = await _fetchLogAgainst(
          MockClient((request) => Completer<http.Response>().future),
        );

        expect(
          logged.lastOrNull,
          matches(
            appRunRecordLine(
              r'fetch outcome /v1/skeleton/message failed \(timeout after 100 ms\) in \d+ ms',
            ),
          ),
        );
      },
    );
  });
}

/// The run-record lines one fetch of the message document writes.
Future<List<String>> _fetchLogAgainst(http.Client server) => runRecordDuring(
  () => _clientFor(server).fetchDocument(
    '/v1/skeleton/message',
    kind: 'skeleton-message',
    parse: _message,
  ),
);

String _message(Map<String, Object?> data) => '${data['message']}';

EndpointClient _clientFor(http.Client server) => EndpointClient(
  baseUrl: Uri.parse('http://endpoint.test'),
  timeout: const Duration(milliseconds: 100),
  newHttpClient: () => server,
);

const _messageEnvelope = {
  'kind': 'skeleton-message',
  'schemaVersion': 1,
  'dataVersion': '2026-10-18',
  'data': {'message': 'hello'},
};

/// Serves [body] (200) on a loopback port from another isolate, so it answers
/// while this one is blocked.
Future<int> _serveFromAnotherIsolate(String body) async {
  final ports = ReceivePort();
  final server = await Isolate.spawn(_serve, (ports.sendPort, body));
  addTearDown(server.kill);
  return await ports.first as int;
}

Future<void> _serve((SendPort, String) setup) async {
  final (replyTo, body) = setup;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  replyTo.send(server.port);
  await for (final request in server) {
    request.response.write(body);
    await request.response.close();
  }
}
