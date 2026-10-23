import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/endpoint/traced_connection.dart';

import '../support/run_record_capture.dart';

void main() {
  test(
    'a connection logs its start, its address lookup and when it connected',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) => socket.destroy());
      final client = tracedHttpClient();
      addTearDown(client.close);

      final logged = await runRecordDuring(() async {
        final request = await client.get('127.0.0.1', server.port, '/');
        request.abort();
      });

      expect(logged, [
        matches(
          appRunRecordLine('connect start 127\\.0\\.0\\.1:${server.port}'),
        ),
        matches(appRunRecordLine('looked up 127\\.0\\.0\\.1 in \\d+ ms')),
        matches(
          appRunRecordLine(
            'connected 127\\.0\\.0\\.1:${server.port} in \\d+ ms',
          ),
        ),
      ]);
    },
  );

  test('a refused connection logs that it failed, and why', () async {
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    final client = tracedHttpClient();
    addTearDown(client.close);

    final logged = await runRecordDuring(() async {
      await expectLater(
        client.get('127.0.0.1', port, '/'),
        throwsA(isA<SocketException>()),
      );
    });

    expect(
      logged.lastOrNull,
      matches(
        appRunRecordLine(
          'connect failed 127\\.0\\.0\\.1:$port in \\d+ ms: SocketException: .*',
        ),
      ),
    );
  });
}
