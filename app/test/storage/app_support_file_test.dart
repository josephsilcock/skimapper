import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/storage/app_support_file.dart';

import '../support/run_record_capture.dart';

void main() {
  late Directory directory;
  late AppSupportFile store;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('app-support-file-');
    store = AppSupportFile('catalogue.json', () async => directory);
  });
  tearDown(() => directory.deleteSync(recursive: true));

  test('reads back the body it saved, byte for byte', () async {
    await store.write('{"kind": "catalogue"}');

    expect(await store.read(), '{"kind": "catalogue"}');
  });

  test('reads nothing when nothing was saved', () async {
    expect(await store.read(), isNull);
  });

  test('clearing leaves nothing saved', () async {
    await store.write('{"kind": "catalogue"}');

    await store.clear();

    expect(await store.read(), isNull);
  });

  test('a save replaces the copy whole: a read already under way still sees the old one', () async {
    await store.write('old copy');
    final readUnderWay = (directory.listSync().single as File).openSync();
    addTearDown(readUnderWay.closeSync);

    await store.write('new copy');

    expect(String.fromCharCodes(readUnderWay.readSync(100)), 'old copy');
    expect(await store.read(), 'new copy');
  });

  test(
    'writes land in the order they were made, even when an earlier one is slow',
    () async {
      var directoryLookups = 0;
      final slowFirst = AppSupportFile('default-resort', () async {
        if (directoryLookups++ == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        return directory;
      });

      final first = slowFirst.write('paradiski');
      final second = slowFirst.write('espace-san-bernardo');
      await Future.wait([first, second]);

      expect(await slowFirst.read(), 'espace-san-bernardo');
    },
  );

  test('a failed write is reported, not thrown, keeps the previous copy, and later writes land', () async {
    var lookups = 0;
    final failingOnce = AppSupportFile('default-resort', () async {
      if (++lookups == 2) throw StateError('no app support directory');
      return directory;
    });
    final reported = <FlutterErrorDetails>[];
    final originalOnError = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = originalOnError);

    await failingOnce.write('paradiski');
    final logged = await runRecordDuring(
      () => failingOnce.write('espace-san-bernardo'),
    );

    expect(
      logged,
      contains(
        contains('default-resort write failed: Bad state: no app support'),
      ),
    );
    expect(reported.single.exception, isA<StateError>());
    expect(await failingOnce.read(), 'paradiski');

    await failingOnce.write('les-3-vallees');
    expect(await failingOnce.read(), 'les-3-vallees');
  });
}
