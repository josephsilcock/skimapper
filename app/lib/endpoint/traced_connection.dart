import 'dart:io';

import 'run_record.dart';

/// An [HttpClient] that logs each connection's start, its address lookup and
/// when it connected or failed.
HttpClient tracedHttpClient() =>
    HttpClient()
      ..connectionFactory = (url, proxyHost, proxyPort) =>
          _tracedConnect(url.host, url.port);

Future<ConnectionTask<Socket>> _tracedConnect(String host, int port) async {
  final target = '$host:$port';
  final elapsed = Stopwatch()..start();
  recordRun('connect start $target');
  final addresses = await InternetAddress.lookup(host);
  recordRun('looked up $host in ${elapsed.elapsedMilliseconds} ms');
  // First address only: the dev endpoint is a literal loopback IP, so there is no fallback to try.
  final task = await Socket.startConnect(addresses.first, port);
  task.socket.then(
    (_) => recordRun('connected $target in ${elapsed.elapsedMilliseconds} ms'),
    onError: (Object failure) => recordRun(
      'connect failed $target in ${elapsed.elapsedMilliseconds} ms: $failure',
    ),
  );
  return task;
}
