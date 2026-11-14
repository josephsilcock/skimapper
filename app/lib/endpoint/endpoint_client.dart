import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http_package;

import 'contract_envelope.dart';
import 'run_record.dart';

/// Fetches from the endpoint off the calling isolate, so the app's own start-up
/// work on its UI isolate can't push a prompt answer past the timeout.
class EndpointClient {
  EndpointClient({
    required this.baseUrl,
    required this.timeout,
    required this.newHttpClient,
  });

  final Uri baseUrl;
  final Duration timeout;

  /// Makes the HTTP client inside the fetching isolate; a client can't cross
  /// isolates.
  final http_package.Client Function() newHttpClient;

  Future<DocumentOutcome<T>> fetchDocument<T>(
    String path, {
    required String kind,
    required T Function(Map<String, Object?> data) parse,
  }) {
    final fetch = _Fetch(
      baseUrl.resolve(path),
      kind,
      parse,
      timeout,
      newHttpClient,
    );
    return _logged(path, fetch.run, named: _documentNamed);
  }

  /// Fetches the part pinned as [sha256] and [size] into [directory].
  Future<PartOutcome> fetchPart({
    required String sha256,
    required int size,
    required String directory,
  }) {
    final path = '/v1/parts/$sha256';
    final fetch = _PartFetch(
      baseUrl.resolve(path),
      '$directory/$sha256',
      sha256,
      size,
      timeout,
      newHttpClient,
    );
    return _logged(path, fetch.run, named: _partNamed);
  }

  /// Runs [fetch] in its own isolate, logging its start and its outcome with how long it took
  /// there, which times the network rather than a busy calling isolate.
  static Future<O> _logged<O>(
    String path,
    Future<O> Function() fetch, {
    required String Function(O outcome) named,
  }) async {
    recordRun('fetch start $path');
    final (outcome, elapsedMs) = await Isolate.run(() => _timed(fetch));
    recordRun('fetch outcome $path ${named(outcome)} in $elapsedMs ms');
    return outcome;
  }

  static Future<(O, int)> _timed<O>(Future<O> Function() fetch) async {
    final elapsed = Stopwatch()..start();
    return (await fetch(), elapsed.elapsedMilliseconds);
  }

  static String _documentNamed<T>(DocumentOutcome<T> outcome) =>
      switch (outcome) {
        Understood() => 'understood',
        Incompatible() => 'incompatible',
        Failed(:final cause) => 'failed ($cause)',
      };

  static String _partNamed(PartOutcome outcome) => switch (outcome) {
    VerifiedPart() => 'verified',
    Failed(:final cause) => 'failed ($cause)',
  };
}

/// The shared half of every fetch's classification (D8): a failed connection, a timeout or a
/// non-2xx answer has failed, and only an answer that reached us is handed to [answered].
Future<O> _overTransport<R extends http_package.BaseResponse, O>({
  required Future<R> Function() request,
  required Duration timeout,
  required O Function(String cause) failed,
  required FutureOr<O> Function(R response) answered,
}) async {
  try {
    final response = await request().timeout(timeout);
    if (response.statusCode ~/ 100 != 2) {
      return failed('HTTP ${response.statusCode}');
    }
    return await answered(response);
  } on http_package.ClientException catch (failure) {
    return failed('connection failed: ${failure.message}');
  } on TimeoutException {
    return failed('timeout after ${timeout.inMilliseconds} ms');
  }
}

/// One fetch, as sent to the fetching isolate: what to get, and how to
/// classify the answer (D8).
class _Fetch<T> {
  const _Fetch(
    this.url,
    this.kind,
    this.parse,
    this.timeout,
    this.newHttpClient,
  );

  final Uri url;
  final String kind;
  final T Function(Map<String, Object?> data) parse;
  final Duration timeout;
  final http_package.Client Function() newHttpClient;

  Future<DocumentOutcome<T>> run() async {
    final httpClient = newHttpClient();
    try {
      return await _outcome(httpClient);
    } finally {
      httpClient.close();
    }
  }

  Future<DocumentOutcome<T>> _outcome(http_package.Client httpClient) =>
      _overTransport(
        request: () => httpClient.get(url),
        timeout: timeout,
        failed: Failed<T>.new,
        answered: (response) =>
            openDocument(response.body, kind: kind, parse: parse),
      );
}

/// One part fetch, as sent to the fetching isolate: streamed straight to its file, and used only
/// if its size and hash match the manifest's.
class _PartFetch {
  const _PartFetch(
    this.url,
    this.path,
    this.sha256,
    this.size,
    this.timeout,
    this.newHttpClient,
  );

  final Uri url;
  final String path;
  final String sha256;
  final int size;
  final Duration timeout;
  final http_package.Client Function() newHttpClient;

  Future<PartOutcome> run() async {
    final httpClient = newHttpClient();
    try {
      return await _overTransport<http_package.StreamedResponse, PartOutcome>(
        request: () => httpClient.send(http_package.Request('GET', url)),
        timeout: timeout,
        failed: Failed<void>.new,
        answered: (response) async {
          final (:digest, :length) = await _writeHashing(
            // An inactivity timeout: a large part may take any time while bytes keep arriving.
            response.stream.timeout(timeout),
          );
          return _verified(digest, length);
        },
      );
    } finally {
      httpClient.close();
    }
  }

  PartOutcome _verified(crypto.Digest digest, int length) {
    if (length != size) return Failed('incomplete: $length of $size bytes');
    if (digest.toString() != sha256) return const Failed('hash mismatch');
    return VerifiedPart(path);
  }

  /// Writes [bytes] to the part's file, hashing and counting them on the way.
  Future<({crypto.Digest digest, int length})> _writeHashing(
    Stream<List<int>> bytes,
  ) async {
    var length = 0;
    final digest = _DigestCapture();
    final hashing = crypto.sha256.startChunkedConversion(digest);
    final file = File(path).openWrite();
    try {
      await for (final chunk in bytes) {
        length += chunk.length;
        hashing.add(chunk);
        file.add(chunk);
      }
    } finally {
      await file.close();
    }
    hashing.close();
    return (digest: digest.value, length: length);
  }
}

class _DigestCapture implements Sink<crypto.Digest> {
  late crypto.Digest value;

  @override
  void add(crypto.Digest digest) => value = digest;

  @override
  void close() {}
}
